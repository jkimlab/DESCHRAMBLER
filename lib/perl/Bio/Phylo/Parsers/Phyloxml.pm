package Bio::Phylo::Parsers::Phyloxml;
use strict;
use warnings;
use base 'Bio::Phylo::Parsers::Abstract';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::Dependency 'XML::Twig';
use Bio::Phylo::Util::CONSTANT qw'looks_like_instance';
use Bio::Phylo::NeXML::Writable;
use Bio::Phylo::Factory;

=head1 NAME

Bio::Phylo::Parsers::Phyloxml - Parser used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module parses phyloxml data. It is called by the L<Bio::Phylo::IO> facade,
don't call it directly. In addition to parsing from files, handles or strings (which
are specified by the -file, -handle and -string arguments) this parser can also parse
xml directly from a url (-url => $phylows_output), provided you have L<LWP> installed.

=cut

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The phyloxml parser is called by the L<Bio::Phylo::IO> object.
Look there to learn how to parse phyloxml (or any other data Bio::Phylo supports).

=item L<Bio::Phylo::Manual>

Also see the manual: L<Bio::Phylo::Manual> and L<http://rutgervos.blogspot.com>.

=item L<http://www.phyloxml.org>

For more information about the phyloxml data standard, visit L<http://www.phyloxml.org>

=back

=head1 CITATION

If you use Bio::Phylo in published research, please cite it:

B<Rutger A Vos>, B<Jason Caravas>, B<Klaas Hartmann>, B<Mark A Jensen>
and B<Chase Miller>, 2011. Bio::Phylo - phyloinformatic analysis using Perl.
I<BMC Bioinformatics> B<12>:63.
L<http://dx.doi.org/10.1186/1471-2105-12-63>

=cut

# The factory object, to instantiate Bio::Phylo objects
#my $factory = Bio::Phylo::Factory->new;
# For semantic annotations
Bio::Phylo::NeXML::Writable->set_namespaces(
    'px' => 'http://www.phyloxml.org/1.10/terms#' );

# I factored the logging methods in Bio::Phylo (debug, info,
# warning, error, fatal) out of the inheritance tree and put
# them in a separate logging object.
# my $logger = Bio::Phylo::Util::Logger->new;
# helper method to add parser reading position to log messages
sub _pos {
    my $self = shift;
    my $t    = $self->{'_twig'};
    join ':', ( $t->current_line, $t->current_column, $t->current_byte );
}

# nice 'n' generic: we provide an element and a class,
# from the class we instantiate a new object, we set
# the element id in the generic slot of the object.
# If the element has a label, use that as name,
# otherwise use id. Additional constructor args can
# be specified using named arguments, e.g. -type => 'dna'
sub _obj_from_elt {
    my ( $self, $elt, $class, %args ) = @_;

    # factory object handles instantiation (and class loading)
    # see Bio::Phylo::Factory
    my $method = "create_$class";
    my $obj    = $self->_factory->$method(%args);

    # description
    if ( my ($desc_elt) = $elt->children('description') ) {
        $obj->set_desc( $desc_elt->text );
    }

    # id_source
    if ( my $id_source = $elt->att('id_source') ) {
        $obj->add_meta(
            $self->_factory->create_meta(
                '-triple' => { 'px:id_source' => $id_source }
            )
        );
    }

    # name
    my $tag = $elt->tag;
    my ($name_elt) = ( $elt->children('name') );
    if ( defined $name_elt ) {
        my $id = $name_elt->text;
        $obj->set_name($id);
        $self->_logger->debug( $self->_pos . " processed <$tag id=\"$id\"/>" );
    }
    else {
        $self->_logger->debug( $self->_pos . " processed <$tag/>" );
    }
    return $obj;
}

# here we create the object instance that will process the file/string
sub _init {
    my $self = shift;

# this is the actual parser object, which needs to hold a reference
# to the XML::Twig object, to a hash of processed blocks (for fast lookup by id)
# and an array of ids (to preserve processing order)
    $self->{'_taxon_in_taxa'} = {};
    $self->{'_proj'}          = $self->_factory->create_project;
    $self->{'_blocks'}        = [ $self->{'_proj'} ];

    # here we put the two together, i.e. create the actual XML::Twig object
    # with its handlers, and create a reference to it in the parser object
    $self->{'_twig'} = XML::Twig->new(

        # These handlers are called when the subtree is fully loaded, which
        # means we can traverse it
        'TwigHandlers' =>
          { 'phylogeny' => sub { &_handle_phylogeny( @_, $self ) }, },

        # These handlers are called when the element opens, that is the
        # subtree hasn't been loaded yet - but the attributes have been,
        # so we can read in the namespaces here.
        'StartTagHandlers' => {
            '_all_' => sub {
                my ( $twig, $elt ) = @_;
                for my $att_name ( $elt->att_names ) {
                    if ( $att_name =~ /^xmlns:(.+)$/ ) {
                        my $prefix = $1;
                        my $ns     = $elt->att($att_name);
                        Bio::Phylo::NeXML::Writable->set_namespaces(
                            $prefix => $ns );
                    }
                }
              }
        },
    );
    return $self;
}

sub _handle_phylogeny {
    my ( $twig, $phylogeny_elt, $self ) = @_;
    my $forest;
    my $tree = _obj_from_elt( $self, $phylogeny_elt, 'tree' );
    unless ( $forest = $self->_project->get_forests->[0] ) {
        $forest = $self->_factory->create_forest;
        $self->_project->insert($forest);
    }
    $forest->insert($tree);
    $tree->set_as_unrooted( $phylogeny_elt->att('rooted') ne 'true' );
    for ( $phylogeny_elt->children('clade') ) {
        $self->_process_clade( $twig, $_, $tree );
    }
}

sub _process_clade {
    my ( $self, $twig, $clade_elt, $tree, $parent ) = @_;
    my $node = _obj_from_elt( $self, $clade_elt, 'node' );
    $node->set_parent($parent) if $parent;
    $tree->insert($node);

    # branch length
    $self->_process_branch_length( $clade_elt, $node );

    # support values, e.g. bootstrap, posterior
    $self->_handle_confidence( $_, $node )
      for $clade_elt->children('confidence');

    # taxonomy, e.g. identifiers, GUIDs, ranks, names
    $self->_process_taxonomy( $_, $node ) for $clade_elt->children('taxonomy');

    # events, e.g. duplications, speciations
    $self->_process_events( $_, $node ) for $clade_elt->children('events');
    for ( $clade_elt->children('clade') ) {
        $self->_process_clade( $twig, $_, $tree, $node );
    }
}

sub _process_sequence {
    my ( $self, $seq_elt, $node ) = @_;
    my ( $taxon, $taxa ) = $self->_fetch_taxon_and_taxa($node);
    my $matrix;
    unless ( $matrix = $self->get_matrices->[0] ) {
        $matrix = $self->_factory->create_matrix( '-taxa' => $taxa );
        $self->_project->insert($matrix);
    }
    my $datum = $self->_obj_from_elt( $seq_elt, 'datum', '-taxon' => $taxon );
    $matrix->insert($datum);
}

sub _process_branch_length {
    my ( $self, $clade_elt, $node ) = @_;
    if ( my ($bl_elt) = ( $clade_elt->children('branch_length') ) ) {
        $node->set_branch_length( $bl_elt->text );
    }
    if ( my $length = $clade_elt->att('branch_length') ) {
        $node->set_branch_length($length);
    }
}

sub _fetch_taxon_and_taxa {
    my ( $self, $node ) = @_;

    # fetch or instantiate taxon object
    my ( $taxon, $taxa );
    unless ( $taxon = $node->get_taxon ) {
        unless ( $taxa = $self->_project->get_taxa->[0] ) {
            $self->_project->insert( $taxa = $self->_factory->create_taxa );
            $self->_project->get_forests->[0]->set_taxa($taxa);
        }
        $taxon = $self->_factory->create_taxon;
        $taxa->insert($taxon);
        $node->set_taxon($taxon);
    }
    return $taxon, $taxa;
}

sub _process_taxonomy {
    my ( $self, $taxonomy_elt, $node ) = @_;

    # fetch or instantiate taxon object
    my ($taxon) = $self->_fetch_taxon_and_taxa($node);

    # handle taxonomy annotations
    $self->_process_taxonomy_annotations( $_, $taxon )
      for $taxonomy_elt->children;
}

sub _process_taxonomy_annotations {
    my ( $self, $elt, $taxon ) = @_;
    my ( $text, $tag ) = ( $elt->text, $elt->tag );
    if ( my $provider = $elt->att('provider') ) {
        $taxon->add_meta(
            $self->_factory->create_meta(
                '-triple' => {
                    "px:${tag}" => $self->_factory->create_meta(
                        '-triple' => { "px:${provider}" => $elt->text }
                    )
                }
            )
        );
    }
    else {
        $taxon->add_meta(
            $self->_factory->create_meta(
                '-triple' => { "px:${tag}" => $text }
            )
        );
    }
}

sub _handle_confidence {
    my ( $self, $confidence_elt, $node ) = @_;
    $node->add_meta(
        $self->_factory->create_meta(
            '-triple' => {
                'px:confidence' => $self->_factory->create_meta(
                    '-triple' => {
                        'px:'
                          . $confidence_elt->att('type') =>
                          $confidence_elt->text
                    }
                )
            }
        )
    );
}

sub _process_events {
    my ( $self, $events_elt, $node ) = @_;
    my @events;
    for ( $events_elt->children ) {
        push @events,
          $self->_factory->create_meta(
            '-triple' => { 'px:' . $_->tag => $_->text } );
    }
    $node->add_meta(
        $self->_factory->create_meta(
            '-triple' => { 'px:events' => \@events }
        )
    );
}

# this method will be called by Bio::Phylo::IO, indirectly, through
# _from_handle if the parse function is called with the -file => $filename
# argument, or through _from_string if called with the -string => $string
# argument
sub _parse {
    my $self = shift;
    $self->_logger->debug("going to parse xml");
    $self->_init;
    my %opt = @_;

    # XML::Twig doesn't care if we parse from a handle or a string
    $self->{'_twig'}->parse( $self->_string );

    # we're done, now order the blocks
    my $ordered_blocks = $self->{'_blocks'};

    # prepare the requested return...
    my $temp_project = shift( @{$ordered_blocks} );
    return @{ $temp_project->get_taxa },
      @{ $temp_project->get_forests },
      @{ $temp_project->get_matrices };
}
sub DESTROY { 1 }
1;
