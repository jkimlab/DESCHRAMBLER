package Bio::Phylo::NeXML::DOM::Element::Twig;
use strict;
use warnings;
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::Dependency 'XML::Twig';
use base qw'Bio::Phylo::NeXML::DOM::Element XML::Twig::Elt';
use Bio::Phylo::Util::CONSTANT '/looks_like/';
use Scalar::Util 'blessed';
our %extant_ids;

=head1 NAME

Bio::Phylo::NeXML::DOM::Element::Twig - XML DOM mappings to the 
XML::Twig package

=head1 SYNOPSIS

Don't use directly; use Bio::Phylo::NeXML::DOM->new( -format => 'twig' ) instead.

=head1 DESCRIPTION

This module provides mappings the methods specified in the 
L<Bio::Phylo::NeXML::DOM::Element> abstract class.

=head1 AUTHOR

Mark A. Jensen ( maj -at- fortinbras -dot- us )

=cut

=head2 CONSTRUCTOR

=over

=item new()

 Type    : Constructor
 Title   : new
 Usage   : $elt = Bio::Phylo::NeXML::DOM::Element->new($tag, $attr)
 Function: Create a new XML DOM element
 Returns : DOM element object
 Args    : Optional: 
           '-tag'        => $tag  - tag name as string
           '-attributes' => $attr - hashref of attributes/values

=cut

sub new {
    my $class = shift;
    my $self  = XML::Twig::Elt->new;
    bless $self, $class;
    if (@_) {
        if ( my %arguments = looks_like_hash @_ ) {
            for my $key ( keys %arguments ) {
                my $method = $key;
                $method =~ s/^-//;
                $method = 'set_' . $method;
                eval { $self->$method( $arguments{$key} ); };
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
            if ( $arguments{'-attributes'} ) {
                my %attributes = %{ $arguments{'-attributes'} };
                $self->_manage_ids( 'ADD', %attributes );
            }
        }
    }
    return $self;
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
    my $twig = XML::Twig->new;
    $twig->parse($text);
    my $root = $twig->root;
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
    return shift->gi;
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
    my ( $self, $tagname ) = @_;
    $self->set_gi($tagname);
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
    my ( $self, @att_names ) = @_;
    @att_names = $self->att_names if not @att_names;
    my %ret = map { $_ => $self->att($_) } @att_names;
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
        $self->set_att(%attr);
        $self->_manage_ids( 'ADD', %attr );
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
    my %ret;
    $ret{$_} = $self->att($_) for @attr_names;
    $self->_manage_ids( 'DEL', @attr_names );  # must come before actual removal
    $self->del_att(@attr_names);
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
        my $t = XML::Twig::Elt->new( '#PCDATA', $text );
        $t->paste( last_child => $self );
        return 1;
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
 Returns : scalar string (the text content)
 Args    : none

=cut

sub get_text {
    my ( $self, @args ) = @_;
    return $self->text;
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
    my ( $self, @args ) = @_;
    my @res;
    @res = map {
        $_->is_text ? do { $_->delete; 1 } : ()
    } $self->children;
    return 1 if @res;
    return 0;
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
    return shift->parent();
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
    return [ shift->children() ];
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
    return shift->first_child();
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
    return shift->last_child();
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
    return shift->next_sibling();
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
    return shift->prev_sibling();
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
    return $self->descendants_or_self($tagname);
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
    my ( $self, $child, @args ) = @_;
    if ( looks_like_instance $child, 'XML::Twig::Elt' ) {
        $child->paste( last_child => $self );
        $self->_manage_ids('ADD');
        return $child;
    }
    else {
        throw 'ObjectMismatch' => 'Argument is not an XML::Twig::Elt';
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
    if ( looks_like_instance $child, 'XML::Twig::Elt' ) {
        my $par = $child->parent;
        return unless ( $par && ( $par == $self ) );

        # or delete?
        $child->_manage_ids('DEL');
        $child->cut;
        return $child;
    }
    else {
        throw 'ObjectMismatch' => 'Argument is not an XML::Twig::Elt';
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
    return shift->sprint(@_);
}

=back

=head1 CITATION

If you use Bio::Phylo in published research, please cite it:

B<Rutger A Vos>, B<Jason Caravas>, B<Klaas Hartmann>, B<Mark A Jensen>
and B<Chase Miller>, 2011. Bio::Phylo - phyloinformatic analysis using Perl.
I<BMC Bioinformatics> B<12>:63.
L<http://dx.doi.org/10.1186/1471-2105-12-63>

=cut

# note: we do our own updates of the Twig id list (the property
# $twig->{twig_id_list}, since according to the XML::Twig source
# "WARNING: at the moment the id list is not updated reliably" which
# evidently means that it isn't updated at all, unless the special
# add_id method is used. Since we want to create elements independent
# of the twig, I felt more in control doing it by by hand. The kludge
# allows the use of the Twig method elt_id() to "get_element_by_id"
# off a document object.
sub _manage_ids {
    my ( $self, $action, @attrs ) = @_;
    for ($action) {
        $_ eq 'ADD' && do {
            my %attrs = @attrs;
            if (%attrs) {    # changing/adding id attribute
                my $id = $attrs{id};
                if ($id) {
                    $extant_ids{$id} = $self;    # log this id
                    ${ $self->twig->{twig_id_list} }{$id} = $self
                      if $self->twig;
                }
                else {
                    return 0;
                }
            }
            else {    # add this element and its descendants
                      # if all elements were created with new(), they all should
                      # logged in %extant_ids
                if ( $self->twig ) {
                    for ( $self->descendants_or_self ) {
                        ${ $self->twig->{twig_id_list} }{ $_->att('id') } = $_
                          if $_->att('id');
                    }
                }
            }
            last;
        };
        $_ eq 'DEL' && do {
            if (@attrs) {
                if ( grep /^id$/, @attrs ) {
                    my $id = $self->att('id');
                    delete $extant_ids{$id};    # clear this id
                    delete ${ $self->twig->{twig_id_list} }{$id} if $self->twig;
                }
                else {
                    return 0;
                }
            }
            else {
                if ( $self->twig ) {
                    delete $extant_ids{ $_->att('id') }
                      for $self->descendants_or_self;
                    delete ${ $self->twig->{twig_id_list} }{ $_->att('id') }
                      for $self->descendants_or_self;
                }
            }
            last;
        };
        do {
            throw 'BadArgs' => 'Unknown action for _manage_ids()';
        };
    }
    return 1;
}
1;
