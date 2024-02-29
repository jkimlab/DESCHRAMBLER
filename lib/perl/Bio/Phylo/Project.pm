package Bio::Phylo::Project;
use strict;
use warnings;
use base 'Bio::Phylo::Listable';
use Bio::Phylo::Util::CONSTANT qw':all';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::Logger;
use Bio::Phylo::IO 'parse';
use Bio::Phylo::Factory;
my $fac    = Bio::Phylo::Factory->new;
my $logger = Bio::Phylo::Util::Logger->new;

{

=head1 NAME

Bio::Phylo::Project - Container for related data

=head1 SYNOPSIS

 use Bio::Phylo::Factory;
 my $fac  = Bio::Phylo::Factory->new;
 my $proj = $fac->create_project;
 my $taxa = $fac->create_taxa;
 $proj->insert($taxa);
 $proj->insert($fac->create_matrix->set_taxa($taxa));
 $proj->insert($fac->create_forest->set_taxa($taxa));
 print $proj->to_xml;

=head1 DESCRIPTION

The project module is used to collect taxa blocks, tree blocks and
matrices.

=head1 METHODS

=head2 MUTATORS

=over

=item merge()

Project constructor.

 Type    : Constructor
 Title   : merge
 Usage   : my $project = Bio::Phylo::Project->merge( @projects )
 Function: Populates a Bio::Phylo::Project object from a list of projects
 Returns : A Bio::Phylo::Project object.
 Args    : A list of Bio::Phylo::Project objects to be merged

=cut

    sub merge {
        my $class  = shift;
	my $self   = $class->SUPER::new;
	my @taxa   = map { @{ $_->get_items(_TAXA_) } } @_;
	my $taxa   = $fac->create_taxa->merge_by_name(@taxa);
	my $forest = $fac->create_forest( '-taxa' => $taxa );
	$forest->insert($_) for map { @{ $_->get_items(_TREE_) } } @_;
	$self->insert($taxa);
	$self->insert($forest);
	$self->insert($_) for map { $_->set_taxa($taxa) } map { @{ $_->get_items(_MATRIX_) } } @_;
	return $self;
    }

=item set_datasource()

Project constructor.

 Type    : Constructor
 Title   : set_datasource
 Usage   : $project->set_datasource( -file => $file, -format => 'nexus' )
 Function: Populates a Bio::Phylo::Project object from a data source
 Returns : A Bio::Phylo::Project object.
 Args    : Arguments as must be passed to Bio::Phylo::IO::parse

=cut

    sub set_datasource {
        my $self = shift;
        return parse( '-project' => $self, @_ );
    }

=item reset_xml_ids()

Resets all xml ids to default values

 Type    : Mutator
 Title   : reset_xml_ids
 Usage   : $project->reset_xml_ids
 Function: Resets all xml ids to default values
 Returns : A Bio::Phylo::Project object.
 Args    : None

=cut

    sub reset_xml_ids {
        my $self = shift;        
        if ( UNIVERSAL::can($self,'set_xml_id') ) {
            my $xml_id = $self->get_tag;
            my $obj_id = sprintf("%x",$self->get_id);
            $xml_id =~ s/^(.).+(.)$/$1$2$obj_id/;
            $self->set_xml_id($xml_id);
        }
        if ( UNIVERSAL::can($self,'get_entities') ) {
            reset_xml_ids($_) for @{ $self->get_entities };
        }
        return $self;
    }

=back

=head2 ACCESSORS

=over

=cut

    my $TYPE       = _PROJECT_;
    my $TAXA       = _TAXA_;
    my $FOREST     = _FOREST_;
    my $MATRIX     = _MATRIX_;
    my $get_object = sub {
        my ( $self, $CONSTANT ) = @_;
        my @result;
        for my $ent ( @{ $self->get_entities } ) {
            if ( $ent->_type == $CONSTANT ) {
                push @result, $ent;
            }
        }
        return \@result;
    };

=item get_taxa()

Getter for taxa objects

 Type    : Accessor
 Title   : get_taxa
 Usage   : my $taxa = $proj->get_taxa;
 Function: Getter for taxa objects
 Returns : An array reference of taxa objects
 Args    : NONE.

=cut	

    sub get_taxa {
        my $self = shift;
        return $get_object->( $self, $TAXA );
    }

=item get_forests()

Getter for forest objects

 Type    : Accessor
 Title   : get_forests
 Usage   : my $forest = $proj->get_forests;
 Function: Getter for forest objects
 Returns : An array reference of forest objects
 Args    : NONE.

=cut		

    sub get_forests {
        my $self = shift;
        return $get_object->( $self, $FOREST );
    }

=item get_matrices()

Getter for matrix objects

 Type    : Accessor
 Title   : get_matrices
 Usage   : my $matrix = $proj->get_matrices;
 Function: Getter for matrix objects
 Returns : An array reference of matrix objects
 Args    : NONE.

=cut	

    sub get_matrices {
        my $self = shift;
        return $get_object->( $self, $MATRIX );
    }

=item get_items()

Gets all items of the specified type, recursively. This method can be used
to get things like all the trees in all the forest objects as one flat list
(or, indeed, all nodes, all taxon objects, etc.)

 Type    : Accessor
 Title   : get_items
 Usage   : my @nodes = @{ $proj->get_items(_NODE_) };
 Function: Getter for items of specified type
 Returns : An array reference of objects
 Args    : A type constant as defined in Bio::Phylo::Util::CONSTANT

=cut	

    sub _item_finder {
        my ( $item, $const, $array ) = @_;
        if ( UNIVERSAL::can($item,'_type') ) {
            if ( $item->_type == $const ) {
                push @{ $array }, $item;
            }
            elsif ( UNIVERSAL::can($item,'get_entities') ) {
                _item_finder( $_, $const, $array ) for @{ $item->get_entities };
            }
        }
    }
    
    sub get_items {
        my ( $self, $const ) = @_;
        if ( $const !~ /^\d+/ ) {
            throw 'BadArgs' => 'Constant must be an integer';
        }
        my $result = [];
        _item_finder( $self, $const, $result );
        return $result;
    }

=item get_document()

 Type    : Serializer
 Title   : doc
 Usage   : $proj->get_document()
 Function: Creates a DOM Document object, containing the 
           present state of the project by default
 Returns : a Document object
 Args    : a DOM factory object
           Optional: pass 1 to obtain a document node without 
           content

=cut

    sub get_document {
        my $self = shift;
        my $dom  = $_[0];
        my @args = @_;

        # handle dom factory object...
        if ( looks_like_instance( $dom, 'SCALAR' )
            && $dom->_type == _DOMCREATOR_ )
        {
            splice( @args, 0, 1 );
        }
        else {
            $dom = $Bio::Phylo::NeXML::DOM::DOM;
            unless ($dom) {
                throw 'BadArgs' => 'DOM factory object not provided';
            }
        }
        ###	# make sure argument handling works here...
        my $empty = shift @args;
        my $doc   = $dom->create_document();
        my $root;
        unless ($empty) {
            $root = $self->to_dom($dom);
            $doc->set_root($root);
        }
        return $doc;
    }

=item get_attributes()

Retrieves attributes for the element.

 Type    : Accessor
 Title   : get_attributes
 Usage   : my %attrs = %{ $obj->get_attributes };
 Function: Gets the xml attributes for the object;
 Returns : A hash reference
 Args    : None.
 Comments: throws ObjectMismatch if no linked taxa object 
           can be found

=cut

    sub get_attributes {
        my $self     = shift;
        my $class    = ref($self);
        my $version  = $class->VERSION;
        my %defaults = (
            'version'            => _NEXML_VERSION_,
            'generator'          => "$class v.$version",
            'xmlns'              => _NS_NEXML_,
            'xsi:schemaLocation' => _NS_NEXML_ . ' '
              . _NS_NEXML_
              . '/nexml.xsd',
        );
        my %attrs = ( %defaults, %{ $self->SUPER::get_attributes } );
        return \%attrs;
    }

=item is_identifiable()

By default, all XMLWritable objects are identifiable when serialized,
i.e. they have a unique id attribute. However, in some cases a serialized
object may not have an id attribute (governed by the nexml schema). This
method indicates whether that is the case.

 Type    : Test
 Title   : is_identifiable
 Usage   : if ( $obj->is_identifiable ) { ... }
 Function: Indicates whether IDs are generated
 Returns : BOOLEAN
 Args    : NONE

=cut

    sub is_identifiable { 0 }

=back

=head2 SERIALIZERS

=over

=item to_xml()

Serializes invocant to XML.

 Type    : XML serializer
 Title   : to_xml
 Usage   : my $xml = $obj->to_xml;
 Function: Serializes $obj to xml
 Returns : An xml string
 Args    : Same arguments as can be passed to individual contained objects

=cut

    sub _add_project_metadata {
        my $self = shift;
        $self->set_namespaces( 'dc' => _NS_DC_ );
        if ( my $user = $ENV{'USER'} ) {
            $logger->debug("adding user metadata '${user}'");
            $self->add_meta(
                $fac->create_meta( '-triple' => { 'dc:creator' => $user } ) );
        }
        eval { require DateTime };
        if ( not $@ ) {
            my $now = DateTime->now();
            $logger->debug("adding timestamp metadata '${now}'");
            $self->add_meta(
                $fac->create_meta( '-triple' => { 'dc:date' => $now } ) );
        }
        else {
            undef($@);
        }
        if ( my $desc = $self->get_desc ) {
            $logger->debug("adding description metadata '${desc}'");
            $self->add_meta(
                $fac->create_meta( '-triple' => { 'dc:description' => $desc } )
            );
        }
    }

    sub to_xml {
        my $self = shift;
        my %args;
        if ( @_ ) {
            %args = @_;
            $self->reset_xml_ids if $args{'-reset'};
        }

        # creating opening tags
        $self->_add_project_metadata;
        my $xml = $self->get_xml_tag;
        $logger->debug("created opening structure ${xml}");

        # processing contents
        my @linked = ( @{ $self->get_forests }, @{ $self->get_matrices } );
        $logger->debug("fetched linked objects @linked");

        # writing out taxa blocks and linked objects
        my %taxa = map { $_->get_id => $_ } @{ $self->get_taxa },
          map { $_->make_taxa } @linked;
        for ( values %taxa, @linked ) {
            $logger->debug("writing $_ to xml");
            $xml .= $_->to_xml(%args);
        }
        $xml .= '</' . $self->get_tag . '>';

        # done creating xml strings
        $logger->debug($xml);
        #eval { require XML::Twig };
        #if ( not $@ ) {
        #    my $twig = XML::Twig->new( 'pretty_print' => 'indented' );
        #    eval { $twig->parse($xml) };
        #    if ($@) {
        #        throw 'API' => "Couldn't build xml: " . $@ . "\n\n$xml";
        #    }
        #    else {
        #        return $twig->sprint;
        #    }
        #}
        #else {
        #    undef $@;
        #    return $xml;
        #}
        return $xml;
    }

=item to_nexus()

Serializes invocant to NEXUS.

 Type    : NEXUS serializer
 Title   : to_nexus
 Usage   : my $nexus = $obj->to_nexus;
 Function: Serializes $obj to nexus
 Returns : An nexus string
 Args    : Same arguments as can be passed to individual contained objects

=cut

    my $write_notes = sub {
        my ( $self, @taxa ) = @_;
        my $nexus = 'BEGIN NOTES;' . "\n";
        my $version = $self->VERSION;
        my $class   = ref $self;
        my $time    = localtime();
        $nexus .= "[! Notes block written by $class $version on $time ]\n";
        for my $taxa ( @taxa ) {
            my $name = $taxa->get_nexus_name;
            my ( $i, $j ) = ( 1, 0 );
            for my $taxon ( @{ $taxa->get_entities } ) {
                if ( my $link = $taxon->get_link ) {
                    if ( $link =~ m|/phylows/| ) {
                        
                        # link has no query string, append one
                        if ( $link !~ /\?/ ) {
                            $link .= '?';
                        }
                        
                        # link has a format statement, replace format
                        if ( $link =~ /\?.*format=/ ) {
                            $link =~ s/(\?.*format=)\s+/$1nexus/;
                        }
                        
                        # append format statement
                        else {
                            $link .= '&' if $link !~ /\?$/ && $link !~ /&$/;
                            $link .= 'format=nexus';
                        }
                    }
                    $nexus .= "\tSUT TAXA = $name TAXON = $i NAME = hyperlink STRING = '$link';\n";
                    $nexus .= "\tHYPERLINK TAXA = $name TAXON = $j URL = '$link';\n";
                }
                $i++;
                $j++;
            }
        }
        $nexus .= 'END;' . "\n";        
    };

    sub to_nexus {
        my $self   = shift;
        my $nexus  = "#NEXUS\n";
        my @linked = ( @{ $self->get_forests }, @{ $self->get_matrices } );
        my %taxa   = map { $_->get_id => $_ } @{ $self->get_taxa },
          map { $_->make_taxa } @linked;
        for ( values %taxa, @linked ) {
            $nexus .= $_->to_nexus(@_);
        }
        $nexus .= $write_notes->($self,values %taxa);
        return $nexus;
    }

=item to_dom()

 Type    : Serializer
 Title   : to_dom
 Usage   : $node->to_dom
 Function: Generates a DOM subtree from the invocant
           and its contained objects
 Returns : an XML::LibXML::Element object
 Args    : a DOM factory object

=cut

    sub to_dom {
        my ( $self, $dom ) = @_;
        $dom ||= Bio::Phylo::NeXML::DOM->get_dom;
        unless ( looks_like_object $dom, _DOMCREATOR_ ) {
            throw 'BadArgs' => 'DOM factory object not provided';
        }
        my $elt    = $self->get_dom_elt($dom);
        my @linked = ( @{ $self->get_forests }, @{ $self->get_matrices } );
        my %taxa   = map { $_->get_id => $_ } @{ $self->get_taxa },
          map { $_->make_taxa } @linked;
        for ( values %taxa, @linked ) {
            $elt->set_child( $_->to_dom( $dom, @_ ) );
        }
        return $elt;
    }
    sub _type { $TYPE }
    sub _tag  { 'nex:nexml' }

=back

=cut

    # podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::Listable>

The L<Bio::Phylo::Project> object inherits from the L<Bio::Phylo::Listable>
object. Look there for more methods applicable to the project object.

=item L<Bio::Phylo::Manual>

Also see the manual: L<Bio::Phylo::Manual> and L<http://rutgervos.blogspot.com>.

=back

=head1 CITATION

If you use Bio::Phylo in published research, please cite it:

B<Rutger A Vos>, B<Jason Caravas>, B<Klaas Hartmann>, B<Mark A Jensen>
and B<Chase Miller>, 2011. Bio::Phylo - phyloinformatic analysis using Perl.
I<BMC Bioinformatics> B<12>:63.
L<http://dx.doi.org/10.1186/1471-2105-12-63>

=cut

}

1
