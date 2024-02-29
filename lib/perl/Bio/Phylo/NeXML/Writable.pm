package Bio::Phylo::NeXML::Writable;
use strict;
use warnings;
use base 'Bio::Phylo';
use Bio::Phylo::IO 'unparse';
use Bio::Phylo::Factory;
use Bio::Phylo::NeXML::DOM;
use Bio::Phylo::NeXML::Entities '/entities/';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw'/looks_like/ :namespaces :objecttypes';
{
    my $logger              = __PACKAGE__->get_logger;
    my $fac                 = Bio::Phylo::Factory->new;
    my $DICTIONARY_CONSTANT = _DICTIONARY_;
    my $META_CONSTANT       = _META_;
    my %namespaces          = (
        'nex' => _NS_NEXML_,
        'xml' => _NS_XML_,
        'xsi' => _NS_XSI_,
        'rdf' => _NS_RDF_,
        'xsd' => _NS_XSD_,
        'map' => _NS_PHYLOMAP_,
    );
    my @fields =
      \( my ( %tag, %id, %attributes, %identifiable, %suppress_ns, %meta, %url ) );

=head1 NAME

Bio::Phylo::NeXML::Writable - Superclass for objects that serialize to NeXML

=head1 SYNOPSIS

 # no direct usage

=head1 DESCRIPTION

This is the superclass for all objects that can be serialized to NeXML 
(L<http://www.nexml.org>).

=head1 METHODS

=head2 MUTATORS

=over

=item set_namespaces()

 Type    : Mutator
 Title   : set_namespaces
 Usage   : $obj->set_namespaces( 'dwc' => 'http://www.namespaceTBD.org/darwin2' );
 Function: Adds one or more prefix/namespace pairs
 Returns : $self
 Args    : One or more prefix/namespace pairs, as even-sized list, 
           or as a hash reference, i.e.:
           $obj->set_namespaces( 'dwc' => 'http://www.namespaceTBD.org/darwin2' );
           or
           $obj->set_namespaces( { 'dwc' => 'http://www.namespaceTBD.org/darwin2' } );
 Notes   : This is a global for the XMLWritable class, so that in a recursive
 		   to_xml call the outermost element contains the namespace definitions.
 		   This method can also be called as a static class method, i.e.
 		   Bio::Phylo::NeXML::Writable->set_namespaces(
 		   'dwc' => 'http://www.namespaceTBD.org/darwin2');

=cut

    sub set_namespaces {
        my $self = shift;
        if ( scalar(@_) == 1 and ref( $_[0] ) eq 'HASH' ) {
            my $hash = shift;
            for my $key ( keys %{$hash} ) {
                $namespaces{$key} = $hash->{$key};
            }
        }
        elsif ( my %hash = looks_like_hash @_ ) {
            for my $key ( keys %hash ) {
                $namespaces{$key} = $hash{$key};
            }
        }
    }

=item set_suppress_ns()

 Type    : Mutator
 Title   : set_suppress_ns
 Usage   : $obj->set_suppress_ns();
 Function: Tell this object not to write namespace attributes
 Returns : 
 Args    : none

=cut

    sub set_suppress_ns : Clonable {
        my $self = shift;
        my $id   = $self->get_id;
        $suppress_ns{$id} = 1;
    }

=item clear_suppress_ns()

 Type    : Mutator
 Title   : clear_suppress_ns
 Usage   : $obj->clear_suppress_ns();
 Function: Tell this object to write namespace attributes
 Returns : 
 Args    : none

=cut

    sub clear_suppress_ns {
        my $self = shift;
        my $id   = $self->get_id;
        $suppress_ns{$id} = 0;
    }

=item add_meta()

 Type    : Mutator
 Title   : add_meta
 Usage   : $obj->add_meta($meta);
 Function: Adds a metadata attachment to the object
 Returns : $self
 Args    : A Bio::Phylo::NeXML::Meta object

=cut

    sub add_meta {
        my ( $self, $meta_obj ) = @_;
        if ( looks_like_object $meta_obj, $META_CONSTANT ) {
            my $id = $self->get_id;
            if ( not $meta{$id} ) {
                $meta{$id} = [];
            }
            push @{ $meta{$id} }, $meta_obj;
            if ( $self->is_identifiable ) {
            	$self->set_attributes( 'about' => '#' . $self->get_xml_id );
            }
        }
        return $self;
    }

=item remove_all_meta()

 Type    : Mutator
 Title   : remove_all_meta
 Usage   : $obj->remove_all_meta();
 Function: Removes all metadata attachments from the object
 Returns : $self
 Args    : None

=cut

	sub remove_all_meta {
		my $self = shift;
		$meta{$self->get_id} = [];
		return $self;
	}

=item remove_meta()

 Type    : Mutator
 Title   : remove_meta
 Usage   : $obj->remove_meta($meta);
 Function: Removes a metadata attachment from the object
 Returns : $self
 Args    : Bio::Phylo::NeXML::Meta

=cut

    sub remove_meta {
        my ( $self, $meta ) = @_;
        my $id      = $self->get_id;
        my $meta_id = $meta->get_id;
        if ( $meta{$id} ) {
          DICT: for my $i ( 0 .. $#{ $meta{$id} } ) {
                if ( $meta{$id}->[$i]->get_id == $meta_id ) {
                    splice @{ $meta{$id} }, $i, 1;
                    last DICT;
                }
            }
        }
        if ( not $meta{$id} or not @{ $meta{$id} } ) {
            $self->unset_attribute('about');
        }
        return $self;
    }

=item set_meta_object()

 Type    : Mutator
 Title   : set_meta_object
 Usage   : $obj->set_meta_object($predicate => $object);
 Function: Attaches a $predicate => $object pair to the invocant
 Returns : $self
 Args    : $predicate => (a valid curie of a known namespace)
	       $object => (an object value)

=cut    

    sub set_meta_object {
		my ( $self, $predicate, $object ) = @_;
		if ( my ($meta) = @{ $self->get_meta($predicate) } ) {
			$meta->set_triple( $predicate => $object );
		}
		else {
			$self->add_meta( $fac->create_meta( '-triple' => { $predicate => $object } ) );
		}
		return $self;
    }

=item set_meta()

 Type    : Mutator
 Title   : set_meta
 Usage   : $obj->set_meta([ $m1, $m2, $m3 ]);
 Function: Assigns all metadata objects
 Returns : $self
 Args    : An array ref of metadata objects

=cut  
	
	sub set_meta : Clonable {
		my ( $self, $meta ) = @_;
		if ( $meta && @{ $meta } ) {
			$meta{$self->get_id} = $meta;
            $self->set_attributes( 'about' => '#' . $self->get_xml_id );			
		}
		else {
			$meta{$self->get_id} = [];
			$self->unset_attribute( 'about' );
		}
		return $self;
	}
    
=item set_identifiable()

By default, all XMLWritable objects are identifiable when serialized,
i.e. they have a unique id attribute. However, in some cases a serialized
object may not have an id attribute (governed by the nexml schema). For
such objects, id generation can be explicitly disabled using this method.
Typically, this is done internally - you will probably never use this method.

 Type    : Mutator
 Title   : set_identifiable
 Usage   : $obj->set_identifiable(0);
 Function: Enables/disables id generation
 Returns : $self
 Args    : BOOLEAN

=cut

    sub set_identifiable : Clonable {
        my $self = shift;
        $identifiable{ $self->get_id } = shift;
        return $self;
    }

=item set_tag()

This method is usually only used internally, to define or alter the
name of the tag into which the object is serialized. For example,
for a Bio::Phylo::Forest::Node object, this method would be called 
with the 'node' argument, so that the object is serialized into an
xml element structure called <node/>

 Type    : Mutator
 Title   : set_tag
 Usage   : $obj->set_tag('node');
 Function: Sets the tag name
 Returns : $self
 Args    : A tag name (must be a valid xml element name)

=cut

    sub set_tag : Clonable {
        my ( $self, $tag ) = @_;

        # _ is ok; see http://www.w3.org/TR/2004/REC-xml-20040204/#NT-NameChar
        if ( $tag =~ qr/^[a-zA-Z]+\:?[a-zA-Z_]*$/ ) {
            $tag{ $self->get_id } = $tag;
            return $self;
        }
        else {
            throw 'BadString' => "'$tag' is not valid for xml";
        }
    }

=item set_name()

Sets invocant name.

 Type    : Mutator
 Title   : set_name
 Usage   : $obj->set_name($name);
 Function: Assigns an object's name.
 Returns : Modified object.
 Args    : Argument must be a string. Ensure that this string is safe to use for
           whatever output format you want to use (this differs between xml and
           nexus, for example).

=cut

    sub set_name : Clonable {
        my ( $self, $name ) = @_;
        if ( defined $name ) {
            return $self->set_attributes( 'label' => $name );
        }
        else {
            return $self;
        }
    }

=item set_attributes()

Assigns attributes for the element.

 Type    : Mutator
 Title   : set_attributes
 Usage   : $obj->set_attributes( 'foo' => 'bar' )
 Function: Sets the xml attributes for the object;
 Returns : $self
 Args    : key/value pairs or a hash ref

=cut

    sub set_attributes {
        my $self = shift;
        my $id   = $self->get_id;
        my %attrs;
        if ( scalar @_ == 1 and ref $_[0] eq 'HASH' ) {
            %attrs = %{ $_[0] };
        }
        elsif ( scalar @_ % 2 == 0 ) {
            %attrs = @_;
        }
        else {
            throw 'OddHash' => 'Arguments are not even key/value pairs';
        }
        my $hash = $attributes{$id} || {};
        my $fully_qualified_attribute_regex = qr/^(.+?):(.+)/;
        for my $key ( keys %attrs ) {
            if ( $key =~ $fully_qualified_attribute_regex ) {
                my ( $prefix, $attribute ) = ( $1, $2 );
                if ( $prefix ne 'xmlns' and not exists $namespaces{$prefix} ) {
                    $logger->warn("Unbound attribute prefix '${prefix}'");
                }
            }
            $hash->{$key} = $attrs{$key};
        }
        $attributes{$id} = $hash;
        return $self;
    }

=item set_xml_id()

This method is usually only used internally, to store the xml id
of an object as it is parsed out of a nexml file - this is for
the purpose of round-tripping nexml info sets.

 Type    : Mutator
 Title   : set_xml_id
 Usage   : $obj->set_xml_id('node345');
 Function: Sets the xml id
 Returns : $self
 Args    : An xml id (must be a valid xml NCName)

=cut

    sub set_xml_id {
        my ( $self, $id ) = @_;
        if ( $id =~ qr/^[a-zA-Z][a-zA-Z0-9\-_\.]*$/ ) {
            $id{ $self->get_id } = $id;
            $self->set_attributes( 'id' => $id, 'about' => "#$id" );
            return $self;
        }
        else {
            throw 'BadString' => "'$id' is not a valid xml NCName for $self";
        }
    }

=item set_base_uri()

This utility method can be used to set the xml:base attribute, i.e. to specify
a location for the object's XML serialization that potentially differs from
the physical location of the containing document.

 Type    : Mutator
 Title   : set_base_uri
 Usage   : $obj->set_base_uri('http://example.org');
 Function: Sets the xml:base attribute
 Returns : $self
 Args    : A URI string

=cut

    sub set_base_uri : Clonable {
        my ( $self, $uri ) = @_;
        if ( $uri ) {
        	$self->set_attributes( 'xml:base' => $uri );
        }
        return $self;
    }

=item set_link()

This sets a clickable link, i.e. a url, for the object. This has no relation to
the xml:base attribute, it is solely intended for serializations that
allow clickable links, such as SVG or RSS.

 Type    : Mutator
 Title   : set_link
 Usage   : $node->set_link($url);
 Function: Sets clickable link
 Returns : $self
 Args    : url

=cut

    sub set_link : Clonable {
        my ( $self, $url ) = @_;
        if ( $url ) {
    	    my $id = $self->get_id;
	        $url{$id} = $url;
        }
        return $self;
    }

=item unset_attribute()

Removes specified attribute

 Type    : Mutator
 Title   : unset_attribute
 Usage   : $obj->unset_attribute( 'foo' )
 Function: Removes the specified xml attribute for the object
 Returns : $self
 Args    : an attribute name

=cut

    sub unset_attribute {
        my $self  = shift;
        my $attrs = $attributes{ $self->get_id };
        if ( $attrs and looks_like_instance( $attrs, 'HASH' ) ) {
            delete $attrs->{$_} for @_;
        }
        return $self;
    }

=back

=head2 ACCESSORS

=over

=item get_namespaces()

 Type    : Accessor
 Title   : get_namespaces
 Usage   : my %ns = %{ $obj->get_namespaces };
 Function: Retrieves the known namespaces
 Returns : A hash of prefix/namespace key/value pairs, or
           a single namespace if a single, optional
           prefix was provided as argument
 Args    : Optional - a namespace prefix

=cut

    sub get_namespaces {
        my ( $self, $prefix ) = @_;
        if ($prefix) {
            return $namespaces{$prefix};
        }
        else {
            my %tmp_namespaces = %namespaces;
            return \%tmp_namespaces;
        }
    }

=item get_prefix_for_namespace()

 Type    : Accessor
 Title   : get_prefix_for_namespace
 Usage   : my $prefix = $obj->get_prefix_for_namespace('http://example.org/')
 Function: Retrieves the prefix for the argument namespace
 Returns : A prefix string
 Args    : A namespace URI

=cut
	
	sub get_prefix_for_namespace {
		my ( $self, $ns_uri ) = @_;
		
		# check argument
		if ( not $ns_uri ) {
			throw 'BadArgs' => "Need namespaces URI argument";
		}
		
		# iterate over namespace/prefix pairs
		my $namespaces = $self->get_namespaces;
		for my $prefix ( keys %{ $namespaces } ) {
			if ( $namespaces->{$prefix} eq $ns_uri ) {
				return $prefix;
			}
		}
		
		# warn user
		$logger->warn("No prefix for namespace $ns_uri");
		return undef;
	}

=item get_meta()

Retrieves the metadata for the element.

 Type    : Accessor
 Title   : get_meta
 Usage   : my @meta = @{ $obj->get_meta };
 Function: Retrieves the metadata for the element.
 Returns : An array ref of Bio::Phylo::NeXML::Meta objects
 Args    : Optional: a list of CURIE predicates, in which case
           the returned objects will be those matching these
	   predicates

=cut

    sub get_meta {
		my $self = shift;
		my $metas = $meta{ $self->get_id } || [];
		if ( @_ ) {
			my %predicates = map { $_ => 1 } @_;
			my @matches = grep { $predicates{$_->get_predicate} } @{ $metas };
			return \@matches;
		}
		return $metas;        
    }

=item get_meta_object()

Retrieves the metadata annotation object for the provided predicate

 Type    : Accessor
 Title   : get_meta_object
 Usage   : my $title = $obj->get_meta_object('dc:title');
 Function: Retrieves the metadata annotation value for the object.
 Returns : An annotation value, i.e. the object of a triple
 Args    : Required: a CURIE predicate for which the annotation
           value is returned
 Note    : This method returns the object for the first annotation
           with the provided predicate. Keep this in mind when dealing
	   with an object that has multiple annotations with the same
	   predicate.

=cut
    
    sub get_meta_object {
		my ( $self, $predicate ) = @_;
		throw 'BadArgs' => "No CURIE provided" unless $predicate;
		my ( $meta ) = @{ $self->get_meta($predicate) };
		if ( $meta ) {
			return $meta->get_object;
		}
		else {
			return undef;
		}
    }

=item get_tag()

Retrieves tag name for the element.

 Type    : Accessor
 Title   : get_tag
 Usage   : my $tag = $obj->get_tag;
 Function: Gets the xml tag name for the object;
 Returns : A tag name
 Args    : None.

=cut

    sub get_tag {
        my $self = shift;
        if ( my $tagstring = $tag{ $self->get_id } ) {
            return $tagstring;
        }
        elsif ( looks_like_implementor $self, '_tag' ) {
            return $self->_tag;
        }
        else {
            return '';
        }
    }

=item get_name()

Gets invocant's name.

 Type    : Accessor
 Title   : get_name
 Usage   : my $name = $obj->get_name;
 Function: Returns the object's name.
 Returns : A string
 Args    : None

=cut

    sub get_name {
        my $self = shift;
        my $id   = $self->get_id;
        if ( !$attributes{$id} ) {
            $attributes{$id} = {};
        }
        if ( defined $attributes{$id}->{'label'} ) {
            return $attributes{$id}->{'label'};
        }
        else {
            return '';
        }
    }

=item get_xml_tag()

Retrieves tag string

 Type    : Accessor
 Title   : get_xml_tag
 Usage   : my $str = $obj->get_xml_tag;
 Function: Gets the xml tag for the object;
 Returns : A tag, i.e. pointy brackets
 Args    : Optional: a true value, to close an empty tag

=cut

    sub get_xml_tag {
        my ( $self, $closeme ) = @_;
        my %attrs = %{ $self->get_attributes };
        my $tag   = $self->get_tag;
        my $xml   = '<' . $tag;
        for my $key ( keys %attrs ) {
            $xml .= ' ' . $key . '="' . encode_entities($attrs{$key}) . '"';
        }
        my $has_contents = 0;
        my $meta         = $self->get_meta;
        if ( @{$meta} ) {
            $xml .= '>';                       # if not @{ $dictionaries };
            $xml .= $_->to_xml for @{$meta};
            $has_contents++;
        }
        if ($has_contents) {
            $xml .= "</$tag>" if $closeme;
        }
        else {
            $xml .= $closeme ? '/>' : '>';
        }
        return $xml;
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

    my $add_namespaces_to_attributes = sub {
        my ( $self, $attrs ) = @_;
        my $i                       = 0;
        my $inside_to_xml_recursion = 0;
      CHECK_RECURSE: while ( my @frame = caller($i) ) {
            if ( $frame[3] =~ m/::to_xml$/ ) {
                $inside_to_xml_recursion++;
                last CHECK_RECURSE if $inside_to_xml_recursion > 1;
            }
            $i++;
        }
        if ( $inside_to_xml_recursion <= 1 ) {
            my $tmp_namespaces = get_namespaces();
            for my $ns ( keys %{$tmp_namespaces} ) {
                $attrs->{ 'xmlns:' . $ns } = $tmp_namespaces->{$ns};
            }
        }
        return $attrs;
    };
    my $flatten_attributes = sub {
        my $self      = shift;
        my $tempattrs = $attributes{ $self->get_id };
        my $attrs;
        if ($tempattrs) {
            my %deref = %{$tempattrs};
            $attrs = \%deref;
        }
        else {
            $attrs = {};
        }
        return $attrs;
    };

    sub get_attributes {
        my ( $self, $arg ) = @_;
        my $attrs = $flatten_attributes->($self);
	
		# process the 'label' attribute: encode if there's anything there,
		# otherwise delete the attribute
		if ( $attrs->{'label'} ) {
			$attrs->{'label'} = encode_entities($attrs->{'label'});
		}
		else {
			delete $attrs->{'label'};
		}
	
		# process the id attribute: if it's not there, autogenerate it, unless
		# the object is explicitly not identifiable, in which case delete the
		# attribute
        if ( not $attrs->{'id'} ) {
            $attrs->{'id'} = $self->get_xml_id;
        }
        if ( defined $self->is_identifiable and not $self->is_identifiable ) {
            delete $attrs->{'id'};
        }
        
        # process the about attribute
        if ( not @{ $self->get_meta } and $attrs->{'about'} ) {
        	delete $attrs->{'about'};
        }
	
		# set the otus attribute
        if ( $self->can('get_taxa') ) {
            if ( my $taxa = $self->get_taxa ) {
                $attrs->{'otus'} = $taxa->get_xml_id
                  if looks_like_instance( $taxa, 'Bio::Phylo' );
            }
            else {
                $logger->error("$self can link to a taxa element, but doesn't");
            }
        }
	
		# set the otu attribute
        if ( $self->can('get_taxon') ) {
            if ( my $taxon = $self->get_taxon ) {
                $attrs->{'otu'} = $taxon->get_xml_id;
            }
            else {
                $logger->info("No linked taxon found");
				delete $attrs->{'otu'};
            }
        }
	
		# add the namespace attributes unless explicitly supressed
		if ( not $self->is_ns_suppressed ) {
			$attrs = $add_namespaces_to_attributes->( $self, $attrs )
		}
		
		# now either return the whole hash or just one value if a
		# key/attribute name was provided
		return $arg ? $attrs->{$arg} : $attrs;
    }

=item get_xml_id()

Retrieves xml id for the element.

 Type    : Accessor
 Title   : get_xml_id
 Usage   : my $id = $obj->get_xml_id;
 Function: Gets the xml id for the object;
 Returns : An xml id
 Args    : None.

=cut

    sub get_xml_id {
        my $self = shift;
        if ( my $id = $id{ $self->get_id } ) {
            return $id;
        }
        else {
            my $xml_id = $self->get_tag;
			my $obj_id = $self->get_id;
            $xml_id =~ s/^(.).+(.)$/$1$2$obj_id/;
            return $id{$obj_id} = $xml_id;
        }
    }

=item get_base_uri()

This utility method can be used to get the xml:base attribute, which specifies
a location for the object's XML serialization that potentially differs from
the physical location of the containing document.

If no xml:base attribute has been defined on the focal object, this method
moves on, recursively, to containing objects (e.g. from node to tree to forest)
until such time that a base URI has been found. 

 Type    : Mutator
 Title   : get_base_uri
 Usage   : my $base = $obj->get_base_uri;
 Function: Gets the xml:base attribute
 Returns : A URI string
 Args    : None

=cut

    sub get_base_uri {
		my $self = shift;
		while ( $self ) {
			my $attrs = $flatten_attributes->($self);
			if ( my $base = $attrs->{'xml:base'} ) {
				$logger->info("Found xml:base attribute on $self: $base");
				return $base;
			}
			
			$logger->info("Traversing up to $self to locate xml:base");
			# we do this because node objects are contained inside their
			# parents, recursively, but node nexml elements aren't. it
			# would be inefficient to traverse all the parent nodes when,
			# logically, none of them could have an xml:base attribute
			# that could apply to the original invocant. in fact, doing
			# so could yield spurious results.
			if ( $self->_type == _NODE_ ) {
				$self = $self->get_tree;
			}
			else {
				$self = $self->_get_container;
			}	    
		}
		$logger->info("No xml:base attribute was found anywhere");
		return undef;
    }

=item get_link()

This returns a clickable link for the object. This has no relation to
the xml:base attribute, it is solely intended for serializations that
allow clickable links, such as SVG or RSS.

 Type    : Accessor
 Title   : get_link
 Usage   : my $link = $obj->get_link();
 Function: Returns a clickable link
 Returns : url
 Args    : NONE

=cut

    sub get_link { $url{ shift->get_id } }

=item get_dom_elt()

 Type    : Serializer
 Title   : get_dom_elt
 Usage   : $obj->get_dom_elt
 Function: Generates a DOM element from the invocant
 Returns : a DOM element object (default XML::Twig)
 Args    : DOM factory object

=cut

    sub get_dom_elt {
        my ( $self, $dom ) = @_;
        $dom ||= Bio::Phylo::NeXML::DOM->get_dom;
        unless ( looks_like_object $dom, _DOMCREATOR_ ) {
            throw 'BadArgs' => 'DOM factory object not provided';
        }
        my $elt = $dom->create_element( '-tag' => $self->get_tag );
        my %attrs = %{ $self->get_attributes };
        for my $key ( keys %attrs ) {
            $elt->set_attributes( $key => $attrs{$key} );
        }
        for my $meta ( @{ $self->get_meta } ) {
            $elt->set_child( $meta->to_dom($dom) );
        }

        #my $dictionaries = $self->get_dictionaries;
        #if ( @{ $dictionaries } ) {
        #    $elt->set_child( $_->to_dom($dom) ) for @{ $dictionaries };
        #}
        if ( looks_like_implementor $self, 'get_sets' ) {
            my $sets = $self->get_sets;
            $elt->set_child( $_->to_dom($dom) ) for @{$sets};
        }
        return $elt;
    }

=back

=head2 TESTS

=over

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

    sub is_identifiable {
        my $self = shift;
        return $identifiable{ $self->get_id };
    }
    *get_identifiable = \&is_identifiable;

=item is_ns_suppressed()

 Type    : Test
 Title   : is_ns_suppressed
 Usage   : if ( $obj->is_ns_suppressed ) { ... }
 Function: Indicates whether namespace attributes should not
           be written on XML serialization
 Returns : BOOLEAN
 Args    : NONE

=cut

    sub is_ns_suppressed {
        return $suppress_ns{ shift->get_id };
    }
    *get_suppress_ns = \&is_ns_suppressed;
    
=item is_equal()

Tests whether the invocant and the argument are the same. Normally this is done
by comparing object identifiers, but if the argument is not an object but a string
then the string is taken to be a name with which to compare, e.g. 
$taxon->is_equal('Homo sapiens')

 Type    : Test
 Title   : is_equal
 Usage   : if ( $obj->is_equal($other) ) { ... }
 Function: Tests whether the invocant and the argument are the same
 Returns : BOOLEAN
 Args    : Object to compare with, or a string representing a
           name to compare with the invocant's name

=cut
    
    sub is_equal {
    	my ($self,$other) = @_;
    	return ref $other ? $self->SUPER::is_equal($other) : $self->get_name eq $other;
    }

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
 Args    : None

=cut

    sub to_xml {
        my $self = shift;
        my $xml  = '';
        if ( $self->can('get_entities') ) {	    
            for my $ent ( @{ $self->get_entities } ) {
                if ( looks_like_implementor $ent, 'to_xml' ) {
                    $xml .= "\n" . $ent->to_xml;
                }
            }
			$xml .= $self->sets_to_xml;
        }
        if ($xml) {
            $xml = $self->get_xml_tag . $xml . sprintf('</%s>', $self->get_tag);
        }
        else {
            $xml = $self->get_xml_tag(1);
        }
        return $xml;
    }

=item to_dom()

 Type    : Serializer
 Title   : to_dom
 Usage   : $obj->to_dom
 Function: Generates a DOM subtree from the invocant and
           its contained objects
 Returns : a DOM element object (default: XML::Twig flavor)
 Args    : DOM factory object
 Note    : This is the generic function. It is redefined in the 
           classes below.

=cut

    sub to_dom {
        my ( $self, $dom ) = @_;
        $dom ||= Bio::Phylo::NeXML::DOM->get_dom;
        if ( looks_like_object $dom, _DOMCREATOR_ ) {
            my $elt = $self->get_dom_elt($dom);
            if ( $self->can('get_entities') ) {
                for my $ent ( @{ $self->get_entities } ) {
                    if ( looks_like_implementor $ent, 'to_dom' ) {
                        $elt->set_child( $ent->to_dom($dom) );
                    }
                }
            }
            return $elt;
        }
        else {
            throw 'BadArgs' => 'DOM factory object not provided';
        }
    }
    
=item to_json()

 Serializes object to JSON string

 Type    : Serializer
 Title   : to_json()
 Usage   : print $obj->to_json();
 Function: Serializes object to JSON string
 Returns : String 
 Args    : None
 Comments:

=cut

    sub to_json {
		looks_like_class('Bio::Phylo::NeXML::XML2JSON')->new->convert( shift->to_xml );
    }    

	sub _json_data {
		my $self   = shift;
		my %meta   = map { $_->get_predicate => $_->get_object } @{ $self->get_meta };
		my %result = %{ $self->SUPER::_json_data };
		$result{$_} = $meta{$_} for keys %meta;
		$result{'name'} = $self->get_name if $self->get_name;
		$result{'link'} = $self->get_link if $self->get_link;
		return \%result;
	}

=item to_cdao()

Serializes object to CDAO RDF/XML string

 Type    : Serializer
 Title   : to_cdao()
 Usage   : print $obj->to_cdao();
 Function: Serializes object to CDAO RDF/XML string
 Returns : String 
 Args    : None
 Comments:

=cut	
	
	sub to_cdao {
		return unparse(
			'-phylo'  => shift,
			'-format' => 'cdao',
		);
	}

    sub _cleanup : Destructor {
        my $self = shift;
        
        # this deserves an explanation. the issue is as follows: for the package
        # bio-phylo-megatree we have node objects that are persisted in a database
        # and accessed through an object-relational mapping provided by DBIx::Class.
        # these node objects are created and destroyed on the fly as a set of node
        # records (i.e. a tree) is traversed. this is the whole point of the package,
        # because it means large trees don't ever have to be kept in memory. however,
        # as a consequence, every time one of those ORM-backed nodes goes out of scope, 
        # this destructor is called and all the @fields are cleaned up again. this 
        # precludes computation and caching of node coordinates (or any other semantic 
        # annotation) on such ORM-backed objects. the terrible, terrible fix for now is 
        # to just assume that i) these annotations need to stay alive ii) we're not going 
        # to have ID clashes (!!!!!), so iii) we just don't clean up after ourselves. 
        # as a note to my future self: it would be a good idea to have a triple store-like 
        # table to store the annotations, so they are persisted in the same way as the
        # node objects, bypassing this malarkey.        
        if ( not $self->isa('DBIx::Class::Core') ) {
			my $id = $self->get_id;
			for my $field (@fields) {
				delete $field->{$id};
			}
        }
    }

=back

=cut

    # podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

Also see the manual: L<Bio::Phylo::Manual> and L<http://rutgervos.blogspot.com>.

=head1 CITATION

If you use Bio::Phylo in published research, please cite it:

B<Rutger A Vos>, B<Jason Caravas>, B<Klaas Hartmann>, B<Mark A Jensen>
and B<Chase Miller>, 2011. Bio::Phylo - phyloinformatic analysis using Perl.
I<BMC Bioinformatics> B<12>:63.
L<http://dx.doi.org/10.1186/1471-2105-12-63>

=cut

}
1;
