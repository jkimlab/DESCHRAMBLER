package Bio::Phylo::NeXML::DOM::Element;
use strict;
use warnings;
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw'_ELEMENT_ /looks_like/';

=head1 NAME

Bio::Phylo::NeXML::DOM::Element - XML DOM Abstract class for
flexible document object model implementation

=head1 SYNOPSIS

Not used directly.

=head1 DESCRIPTION

This module describes an abstract implementation of a DOM object as
expected by Bio::Phylo. The methods here must be overridden in any
concrete implementation. The idea is that different implementations
use a particular XML DOM package, binding the methods here to
analogous package methods.

This set of methods is intentionally minimal. The concrete instances
of this class should inherit both from ElementI and the underlying XML DOM
object class, so that package-specific methods can be directly
accessed from the instantiated object.

=head1 AUTHOR

Mark A. Jensen - maj -at- fortinbras -dot- us

=cut

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
           '-attr'    => $attr - hashref of attributes/values

=cut

sub new {
    my $class = shift;
    if ( my %args = looks_like_hash @_ ) {
        $class = __PACKAGE__ . '::' . ucfirst( lc( $args{'-format'} ) );
        delete $args{'-format'};
        return looks_like_class($class)->new(%args);
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
    throw 'NotImplemented' => "Can't call 'get_tag' on interface";
}

sub _recurse_bless {
    my $node  = shift;
    my $class = ref $node;
    for my $child ( @{ $node->get_children } ) {
        bless $child, $class;
        _recurse_bless($child);
    }
}

=back

=head2 Namespace accessors/mutators

=over

=item

 Type    : 
 Title   :
 Usage   :
 Function:
 Returns :
 Args    :

=cut

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
    throw 'NotImplemented' => "Can't call 'get_tag' on interface";
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
    throw 'NotImplemented' => "Can't call 'set_tag' on interface";
}

=back 

=head2 Attribute mutators/accessors

=over

=item get_attributes()

 Type    : Accessor
 Title   : get_attributes
 Usage   : $elt->get_attributes( @attribute_names )
 Function: Get attribute values
 Returns : A hash ref of key/value pairs
 Args    : Optional, [a list of] attribute name[s] as string[s]

=cut

sub get_attributes {
    throw 'NotImplemented' => "Can't call 'get_attributes' on interface";
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
    throw 'NotImplemented' => "Can't call 'set_attributes' on interface";
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
    throw 'NotImplemented' => "Can't call 'clear_attributes' on interface";
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
    throw 'NotImplemented' => "Can't call 'set_text' on interface";
}

=item get_text()

 Type    : Accessor
 Title   : get_text
 Usage   : $elt->get_text()
 Function: Retrieve direct #TEXT descendants as (concatenated) string
 Returns : scalar string (the text content)
 Args    : none

=cut

sub get_text {
    throw 'NotImplemented' => "Can't call 'get_text' on interface";
}

=item clear_text()

 Type    : Mutator
 Title   : clear_text
 Usage   : $elt->clear_text()
 Function: Remove direct #TEXT descendant nodes from element
 Returns : True on success; false if no #TEXT nodes removed
 Args    : none

=cut

sub clear_text {
    throw 'NotImplemented' => "Can't call 'clear_text' on interface";
}

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
    throw 'NotImplemented' => "Can't call 'get_parent' on interface";
}

=item get_children()

 Type    : Accessor
 Title   : get_children
 Usage   : $elt->get_children()
 Function: Get child nodes of invocant
 Returns : Array ref of Elements
 Args    : none

=cut

sub get_children {
    throw 'NotImplemented' => "Can't call 'get_children' on interface";
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
    throw 'NotImplemented' => "Can't call 'get_first_daughter' on interface";
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
    throw 'NotImplemented' => "Can't call 'get_last_daughter' on interface";
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
    throw 'NotImplemented' => "Can't call 'get_next_sister' on interface";
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
    throw 'NotImplemented' => "Can't call 'get_previous_sister' on interface";
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
    throw 'NotImplemented' =>
      "Can't call 'get_elements_by_tagname' on interface";
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

=cut

sub set_child {
    throw 'NotImplemented' => "Can't call 'set_child' on interface";
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
    throw 'NotImplemented' => "Can't call 'prune_child' on interface";
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
    throw 'NotImplemented' => "Can't call 'to_xml' on interface";
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
