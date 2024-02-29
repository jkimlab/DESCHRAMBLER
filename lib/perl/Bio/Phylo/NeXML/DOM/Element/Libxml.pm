
=head1 NAME

Bio::Phylo::NeXML::DOM::Element::Libxml - XML DOM element mappings to the 
C<XML::LibXML> package

=head1 SYNOPSIS

Don't use directly; use Bio::Phylo::NeXML::DOM->new( -format => 'libxml' ) instead.

=head1 DESCRIPTION

This module provides mappings the methods specified in the 
L<Bio::Phylo::NeXML::DOM::Element> abstract class to the 
C<XML::LibXML::Element> package.

=head1 AUTHOR

Mark A. Jensen ( maj -at- fortinbras -dot- us )

=cut

package Bio::Phylo::NeXML::DOM::Element::Libxml;
use strict;
use warnings;
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT '/looks_like/';
use Bio::Phylo::Util::Dependency 'XML::LibXML';
use base qw'Bio::Phylo::NeXML::DOM::Element XML::LibXML::Element';
XML::LibXML->import(':libxml');

=head2 Constructor

=over

=item new()

 Type    : Constructor
 Title   : new
 Usage   : $elt = Bio::Phylo::NeXML::DOM::Element->new($tag, $attr)
 Function: Create a new XML DOM element
 Returns : DOM element object
 Args    : Optional: 
           '-tag' => $tag  - tag name as string
           '-attributes' => $attr - hashref of attributes/values

=cut

sub new {
    my $class = shift;
    if ( my %args = looks_like_hash @_ ) {
        if ( $args{'-tag'} ) {
            my $self = XML::LibXML::Element->new( $args{'-tag'} );
            bless $self, $class;
            delete $args{'-tag'};
            for my $key ( keys %args ) {
                my $method = $key;
                $method =~ s/^-//;
                $method = 'set_' . $method;
                eval { $self->$method( $args{$key} ); };
                if ($@) {
                    if ( blessed $@ and $@->can('rethrow') ) {
                        $@->rethrow;
                    }
                    elsif ( not ref($@)
                        and $@ =~ /^Can't locate object method / )
                    {
                        throw 'BadArgs' =>
"The named argument '${key}' cannot be passed to the constructor";
                    }
                    else {
                        throw 'Generic' => $@;
                    }
                }
            }
            return $self;
        }
        else {
            throw 'BadArgs' => "Tag name required for XML::LibXML::Element";
        }
    }
    else {
        throw 'BadArgs' => "Tag name required for XML::LibXML::Element";
    }
}

=item parse_element()

 Type    : Factory method
 Title   : parse_element
 Usage   : $elt = $dom->parse_element($text)
 Function: Create a new XML DOM element from XML text
 Returns : DOM element
 Args    : An XML String

=cut

sub parse_element {
    my ( $class, $text ) = @_;
    my $dom  = XML::LibXML->load_xml($text);
    my $root = $dom->documentElement();
    bless $root, __PACKAGE__;
    Bio::Phylo::NeXML::DOM::Element::_recurse_bless($root);
    return $root;
}

=back

=head2 Tagname mutators/accessors

=over

=item get_tag()

 Type    : Accessor
 Title   : get_tag
 Usage   : $elt->get_tag()
 Function: Get tag name
 Returns : Tag name as scalar string
 Args    : none

=cut

sub get_tag {
    return shift->tagName;
}

=item set_tag()

 Type    : Mutator
 Title   : set_tag
 Usage   : $elt->set_tag( $tagname )
 Function: Set tagname
 Returns : True on success
 Args    : Tag name as scalar string

=cut

sub set_tag {
    my ( $self, $tagname, @args ) = @_;
    $self->setNodeName($tagname);
    return $self;
}

=back 

=head2 Attribute mutators/accessors

=over

=item get_attributes()

 Type    : Accessor
 Title   : get_attributes
 Usage   : $elt->get_attributes( @attribute_names )
 Function: Get attribute values
 Returns : Array of attribute values
 Args    : [an array of] attribute name[s] as string[s]

=cut

sub get_attributes {
    my ( $self, @attr_names ) = @_;
    my %ret = map { $_ => $self->getAttribute($_) } @attr_names;
    return \%ret;
}

=item set_attributes()

 Type    : Mutator
 Title   : set_attributes
 Usage   : $elt->set_attributes( @attribute_assoc_array )
 Function: Set attribute values
 Returns : True on success
 Args    : An associative array of form ( $name => $value, ... )

=cut

sub set_attributes {
    my $self = shift;
    if (@_) {
        my %attr;
        if ( @_ == 1 && looks_like_instance $_[0], 'HASH' ) {
            %attr = %{ $_[0] };
        }
        else {
            %attr = looks_like_hash @_;
        }
        $self->setAttribute( $_, $attr{$_} ) for keys %attr;
    }
    return $self;
}

=item clear_attributes()

 Type    : Mutator
 Title   : clear_attributes
 Usage   : $elt->clear_attributes( @attribute_names )
 Function: Remove attributes from element
 Returns : Hash of removed attributes/values
 Args    : Array of attribute names

=cut

sub clear_attributes {
    my ( $self, @attr_names ) = @_;
    return 0 if not @attr_names;
    my %ret;
    $ret{$_} = $self->getAttribute($_) for @attr_names;
    $self->removeAttribute($_) for @attr_names;
    return %ret;
}

=back

=head2 Content mutators/accessors

=over

=item set_text()

 Type    : Mutator
 Title   : set_text
 Usage   : $elt->set_text($text_content)
 Function: Add a #TEXT node to the element 
 Returns : True on success
 Args    : scalar string

=cut

sub set_text {
    my ( $self, $text, @args ) = @_;
    if ($text) {
        $self->appendTextNode($text);
        return $self;
    }
    else {
        throw 'BadArgs' => "No text specified";
    }
}

=item get_text()

 Type    : Accessor
 Title   : get_text
 Usage   : $elt->get_text()
 Function: Retrieve direct #TEXT descendants as (concatenated) string
 Returns : scalar string (the text content) or undef if no text nodes
 Args    : none

=cut

#no strict;
sub get_text {
    my ( $self, @args ) = @_;
    my $text;
    for ( $self->childNodes ) {
        $text .= $_->nodeValue if $_->nodeType == XML::LibXML::XML_TEXT_NODE;
    }
    return $text;
}

#use strict;

=item clear_text()

 Type    : Mutator
 Title   : clear_text
 Usage   : $elt->clear_text()
 Function: Remove direct #TEXT descendant nodes from element
 Returns : True on success; false if no #TEXT nodes removed
 Args    : none

=cut

#no strict;
sub clear_text {
    my ( $self, @args ) = @_;
    my @res = map {
            $_->nodeType == XML::LibXML::XML_TEXT_NODE
          ? $self->removeChild($_)
          : ()
    } $self->childNodes;
    return !!scalar(@res);
}

#use strict;

=back

=head2 Traversal methods

=over

=item get_parent()

 Type    : Accessor
 Title   : get_parent
 Usage   : $elt->get_parent()
 Function: Get parent DOM node of invocant 
 Returns : Element object or undef if invocant is root
 Args    : none

=cut

sub get_parent {
    my $e = shift->parentNode;
    return bless $e, __PACKAGE__;
}

=item get_children()

 Type    : Accessor
 Title   : get_children
 Usage   : $elt->get_children()
 Function: Get child nodes of invocant
 Returns : Array of Elements
 Args    : none

=cut

sub get_children {
    my @ret = shift->childNodes;
    bless( $_, __PACKAGE__ ) for (@ret);
    return \@ret;
}

=item get_first_daughter()

 Type    : Accessor
 Title   : get_first_daughter
 Usage   : $elt->get_first_daughter()
 Function: Get first child (as defined by underlying package) of invocant
 Returns : Element object or undef if invocant is childless
 Args    : none

=cut

sub get_first_daughter {
    my $e = shift->firstChild;
    return bless $e, __PACKAGE__;
}

=item get_last_daughter()

 Type    : Accessor
 Title   : get_last_daughter
 Usage   : $elt->get_last_daughter()
 Function: Get last child (as defined by underlying package) of invocant
 Returns : Element object or undef if invocant is childless
 Args    : none

=cut

sub get_last_daughter {
    my $e = shift->lastChild;
    return bless $e, __PACKAGE__;
}

=item get_next_sister()

 Type    : Accessor
 Title   : get_next_sister
 Usage   : $elt->get_next_sister()
 Function: Gets next sibling (as defined by underlying package) of invocant
 Returns : Element object or undef if invocant is the rightmost element
 Args    : none

=cut

sub get_next_sister {
    my $e = shift->nextSibling;
    return bless $e, __PACKAGE__;
}

=item get_previous_sister()

 Type    : Accessor
 Title   : get_previous_sister
 Usage   : $elt->get_previous_sister()
 Function: Get previous sibling (as defined by underlying package) of invocant
 Returns : Element object or undef if invocant is leftmost element
 Args    : none

=cut

sub get_previous_sister {
    my $e = shift->previousSibling;
    return bless $e, __PACKAGE__;
}

=item get_elements_by_tagname()

 Type    : Accessor
 Title   : get_elements_by_tagname
 Usage   : $elt->get_elements_by_tagname($tagname)
 Function: Get array of elements having given tag name from invocant's 
           descendants
 Returns : Array of elements or undef if no match
 Args    : tag name as string

=cut

sub get_elements_by_tagname {
    my ( $self, $tagname, @args ) = @_;
    my @a = $self->getElementsByTagName($tagname);
    bless( $_, __PACKAGE__ ) for (@a);
    return @a;
}

=back

=head2 Prune and graft methods

=over

=item set_child()

 Type    : Mutator
 Title   : set_child
 Usage   : $elt->set_child($child)
 Function: Add child element object to invocant's descendants
 Returns : the element object added
 Args    : Element object
 Note    : See caution at 
           L<http://search.cpan.org/~pajas/XML-LibXML-1.69/lib/XML/LibXML/Node.pod#addChild>

=cut

sub set_child {
    my ( $self, $child, @args ) = @_;
    if ( looks_like_instance $child, 'XML::LibXML::Node' ) {
        return $self->addChild($child);
    }
    else {
        throw 'ObjectMismatch' => "Argument is not an XML::LibXML::Node";
    }
}

=item prune_child()

 Type    : Mutator
 Title   : prune_child
 Usage   : $elt->prune_child($child)
 Function: Remove the subtree rooted by $child from among the invocant's
           descendants
 Returns : $child or undef if $child is not among the children of invocant
 Args    : Element object

=cut

sub prune_child {
    my ( $self, $child, @args ) = @_;
    if ( looks_like_instance $child, 'XML::LibXML::Node' ) {
        return $self->removeChild($child);
    }
    else {
        throw 'ObjectMismatch' => "Argument is not an XML::LibXML::Node";
    }
}

=back

=head2 Output methods

=over

=item to_xml()

 Type    : Serializer
 Title   : to_xml
 Usage   : $elt->to_xml
 Function: Create XML string from subtree rooted by invocant
 Returns : XML string
 Args    : Formatting arguments as allowed by underlying package

=cut

sub to_xml {
    my ( $self, @args ) = @_;
    return $self->toString(@args);
}

=back

=head1 CITATION

If you use Bio::Phylo in published research, please cite it:

B<Rutger A Vos>, B<Jason Caravas>, B<Klaas Hartmann>, B<Mark A Jensen>
and B<Chase Miller>, 2011. Bio::Phylo - phyloinformatic analysis using Perl.
I<BMC Bioinformatics> B<12>:63.
L<http://dx.doi.org/10.1186/1471-2105-12-63>

=cut

1;
