package Bio::Phylo::Parsers::Tolweb;
use strict;
use warnings;
use base 'Bio::Phylo::Parsers::Abstract';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw'looks_like_instance :namespaces';
use Bio::Phylo::Util::Dependency 'XML::Twig';

=head1 NAME

Bio::Phylo::Parsers::Tolweb - Parser used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module parses Tree of Life data. It is called by the L<Bio::Phylo::IO> facade,
don't call it directly. In addition to parsing from files, handles or strings (which
are specified by the -file, -handle and -string arguments) this parser can also parse
xml directly from a url (-url => $tolweb_output), provided you have L<LWP> installed.

=cut

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The ToL web parser is called by the L<Bio::Phylo::IO> object.
Look there to learn how to parse Tree of Life data (or any other data Bio::Phylo supports).

=item L<Bio::Phylo::Manual>

Also see the manual: L<Bio::Phylo::Manual> and L<http://rutgervos.blogspot.com>.

=item L<http://tolweb.org>

For more information about the Tree of Life xml format, visit 
L<http://tolweb.org/tree/home.pages/downloadtree.html>

=back

=head1 CITATION

If you use Bio::Phylo in published research, please cite it:

B<Rutger A Vos>, B<Jason Caravas>, B<Klaas Hartmann>, B<Mark A Jensen>
and B<Chase Miller>, 2011. Bio::Phylo - phyloinformatic analysis using Perl.
I<BMC Bioinformatics> B<12>:63.
L<http://dx.doi.org/10.1186/1471-2105-12-63>



=cut

# this is the constructor that gets called by Bio::Phylo::IO,
# here we create the object instance that will process the file/string
sub _init {
    my $self = shift;
    $self->_logger->debug("initializing $self");

    # this is the actual parser object, which needs to hold a reference
    # to the XML::Twig object and to the tree
    $self->{'_tree'}      = undef;
    $self->{'_node_of'}   = {};
    $self->{'_parent_of'} = {};

    # here we put the two together, i.e. create the actual XML::Twig object
    # with its handlers, and create a reference to it in the parser object
    $self->{'_twig'} = XML::Twig->new(
        'TwigHandlers' => { 'NODE' => sub { &_handle_node( $self, @_ ) }, } );
    return $self;
}

sub _parse {
    my $self = shift;
    $self->_init;
    $self->_logger->debug("going to parse xml");
    $self->{'_tree'} = $self->_factory->create_tree(
        '-namespaces' => {
            'tol' => _NS_TOL_,
            'dc'  => _NS_DC_,
        }    
    );
    $self->{'_twig'}->parse( $self->_string );
    $self->_logger->debug("done parsing xml");

    # now we build the tree structure
    for my $node_id ( keys %{ $self->{'_node_of'} } ) {
        if ( defined( my $parent_id = $self->{'_parent_of'}->{$node_id} ) ) {
            my $child  = $self->{'_node_of'}->{$node_id};
            my $parent = $self->{'_node_of'}->{$parent_id};
            $child->set_parent($parent);
        }
    }

    # we're done, now insert the tree in a forest
    return $self->_factory->create_forest->insert($self->{'_tree'});
}

sub _handle_node {
    my ( $self, $twig, $node_elt ) = @_;
    my $fac = $self->_factory;    
    my $node_obj = $fac->create_node;    
    $self->{'_tree'}->insert($node_obj);

    # these hashes are populated so that we can build the topology
    # once we've processed all NODE elements
    my $id = $node_elt->att('ID');
    $node_obj->set_guid($id);
    $node_obj->add_meta(
        $fac->create_meta( '-triple' => { 'dc:identifier' => $id } )
    );
    $self->{'_node_of'}->{$id} = $node_obj;    
    if ( my $parent = $node_elt->parent->parent ) {
        $self->{'_parent_of'}->{$id} = $parent->att('ID');
    }
    
    # process node level metadata
    $self->_process_metadata( $node_elt, $node_obj );
    
    # process other names
    my ($othernames_elt) = $node_elt->children('OTHERNAMES');
    if ( $othernames_elt ) {
        for my $othername_elt ( $othernames_elt->children ) {
            my ($name_elt) = $othername_elt->children('NAME');
            my $text = $name_elt->text;
            my $meta_obj = $fac->create_meta( '-triple' => { 'tol:othername' => $text } );
            $node_obj->add_meta( $meta_obj );
            $self->_process_metadata( $othername_elt, $meta_obj );        
        }
    }
    
    $node_elt->delete;
}

sub _process_metadata {
    my ( $self, $elt, $obj ) = @_;
    my $elt_tag = $elt->tag;
    my $fac = $self->_factory;

    # we don't process child NODE elements here, we construct the topology
    # afterwards. This so that we can process the element structure in chunks.
    for my $child ( $elt->children ) {
        my ( $child_tag, $text ) = ( $child->tag, $child->text );
        if ( $text && $child_tag eq 'NAME' ) {
            $obj->set_name($text) if $elt_tag eq 'NODE';
        }
        elsif ( $text && $child_tag eq 'DESCRIPTION' ) {
            $obj->add_meta( $fac->create_meta( '-triple' => { 'dc:description' => $text } ) );
            $obj->set_desc( $text );
        }
        elsif ( $text && $child_tag ne 'NODES' && $child_tag ne 'OTHERNAMES' ) {
            $obj->add_meta( $fac->create_meta( '-triple' => { 'tol:' . lc( $child_tag ) => $text } ) );
        }
    }
    
    for my $att_name ( $elt->att_names ) {
        if ( defined $elt->att($att_name) ) {
            $obj->add_meta( $fac->create_meta( '-triple' => { 'tol:' . lc($att_name) => $elt->att($att_name) } ) );
        }
    }
    
}

1;
