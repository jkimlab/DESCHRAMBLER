
=head1 NAME

Bio::Phylo::NeXML::DOM::Document::Twig - XML DOM document mappings to the
C<XML::Twig> package

=head1 SYNOPSIS

Don't use directly; use Bio::Phylo::NeXML::DOM->new( -format => 'twig' ) instead.

=head1 DESCRIPTION

This module provides mappings the methods specified in the 
L<Bio::Phylo::NeXML::DOM::Document> abstract class to the 
C<XML::Twig> package.

=head1 AUTHOR

Mark A. Jensen ( maj -at- fortinbras -dot- us )

=cut

package Bio::Phylo::NeXML::DOM::Document::Twig;
use strict;
use warnings;
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::Dependency 'XML::Twig';
use Bio::Phylo::NeXML::DOM::Document;
use Bio::Phylo::Util::CONSTANT 'looks_like_instance';
use base qw'Bio::Phylo::NeXML::DOM::Document XML::Twig';

=head2 Constructor

=over

=item new()

 Type    : Constructor
 Title   : new
 Usage   : $doc = Bio::Phylo::NeXML::DOM::Document->new(@args)
 Function: Create a Document object using the underlying package
 Returns : Document object or undef on fail
 Args    : Package-specific arguments

=cut

sub new {
    my ( $class, @args ) = @_;
    my $self = XML::Twig->new();
    $self->set_encoding();
    bless $self, $class;
    return $self;
}

=item parse_document()

 Type    : Factory method
 Title   : parse_document
 Usage   : $doc = $dom->parse_document($text)
 Function: Create a new XML DOM document from XML text
 Returns : DOM document
 Args    : An XML String

=cut

sub parse_document {
    my ( $class, $text ) = @_;
    my $self = XML::Twig->new();
    $self->parse($text);
    bless $self, $class;
    return $self;
}

=back

=cut 

=head2 Document property accessors/mutators

=over

=item set_encoding()

 Type    : Mutator
 Title   : set_encoding
 Usage   : $doc->set_encoding($enc)
 Function: Set encoding for document
 Returns : True on success
 Args    : Encoding descriptor as string

=cut

sub set_encoding {
    my ( $self, $encoding, @args ) = @_;
    $self->set_encoding($encoding);
    return 1;
}

=item get_encoding()

 Type    : Accessor
 Title   : get_encoding
 Usage   : $doc->get_encoding()
 Function: Get encoding for document
 Returns : Encoding descriptor as string
 Args    : none

=cut

sub get_encoding {
    return shift->encoding;
}

=item set_root()

 Type    : Mutator
 Title   : set_root
 Usage   : $doc->set_root($elt)
 Function: Set the document's root element
 Returns : True on success
 Args    : Element object

=cut

sub set_root {
    my ( $self, $root ) = @_;
    if ( looks_like_instance $root, 'XML::Twig::Elt' ) {
        XML::Twig::set_root( $self, $root );

        # manage ids
        for ( $root->descendants_or_self ) {
            ${ $self->{twig_id_list} }{ $_->att('id') } = $_ if $_->att('id');
        }
        return 1;
    }
    else {
        throw 'ObjectMisMatch' => 'Argument is not an XML::Twig::Elt';
    }
}

=item get_root()

 Type    : Accessor
 Title   : get_root
 Usage   : $doc->get_root()
 Function: Get the document's root element
 Returns : Element object or undef if DNE
 Args    : none

=cut

sub get_root {
    return shift->root;
}

=back

=cut 

=head2 Document element accessors

=over 

=item get_element_by_id()

 Type    : Accessor
 Title   : get_element_by_id
 Usage   : $doc->get_element_by_id($id)
 Function: Get element having id $id
 Returns : Element object or undef if DNE
 Args    : id designator as string

=cut

sub get_element_by_id {
    return shift->elt_id(shift);
}

=item get_elements_by_tagname()

 Type    : Accessor
 Title   : get_elements_by_tagname
 Usage   : $elt->get_elements_by_tagname($tagname)
 Function: Get array of elements having given tag name 
 Returns : Array of elements or undef if no match
 Args    : tag name as string

=cut

sub get_elements_by_tagname {
    my ( $self, $tagname, @args ) = @_;
    return $self->get_root->get_elements_by_tagname($tagname);
}

=back

=head2 Output methods

=over

=item to_xml()

 Type    : Serializer
 Title   : to_xml
 Usage   : $doc->to_xml
 Function: Create XML string from document
 Returns : XML string
 Args    : Formatting arguments as allowed by underlying package

=cut

sub to_xml {
    my ( $self, @args ) = @_;
    return $self->sprint(@args);
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
