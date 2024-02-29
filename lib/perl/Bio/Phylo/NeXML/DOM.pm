package Bio::Phylo::NeXML::DOM;
use strict;
use warnings;
use base 'Bio::Phylo';
use Bio::Phylo::Util::CONSTANT qw'_DOMCREATOR_ looks_like_class';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Factory;
use File::Spec::Unix;

# store DOM factory object as a global here, to avoid proliferation of
# function arguments
our $DOM;
{
    my $CONSTANT_TYPE = _DOMCREATOR_;
    my (%format);
    my $fac = Bio::Phylo::Factory->new;

=head1 NAME

Bio::Phylo::NeXML::DOM - XML DOM support for Bio::Phylo

=head1 SYNOPSIS

 use Bio::Phylo::NeXML::DOM;
 use Bio::Phylo::IO qw( parse );
 Bio::Phylo::NeXML::DOM->new(-format => 'twig');
 my $project = parse( -file=>'my.nex', -format=>'nexus' );
 my $nex_twig = $project->doc();

=head1 DESCRIPTION

This module adds C<to_dom> methods to L<Bio::Phylo::NeXML::Writable>
classes, which provide NeXML-valid objects for document object model
manipulation. DOM formats currently available are C<XML::Twig> and
C<XML::LibXML>.  For any C<XMLWritable> object, use C<to_dom> in place
of C<to_xml> to create DOM nodes.

The C<doc()> method is also added to the C<Bio::Phylo::Project> class. It
returns a NeXML document as a DOM object populated by the current contents
of the C<Bio::Phylo::Project> object.

=head1 MOTIVATION

The NeXML parsing/writing capability of C<Bio::Phylo> goes a long way
towards wider adoption of this useful standard.

However, while C<Bio::Phylo> can write NeXML-valid XML, the way in
which it does this natively is somewhat hard-coded and therefore
restricted, and is essentially oriented toward text file output. As
such, there is a mismatch between the sophisticated C<Bio::Phylo> data
structure and its own ability to manipulate and serialize that
structure in sophisticated but interoperable ways. Finer manipulations
of XML-represented data are possible via through a variety of Perl
packages that can store and control XML according to a document
object model (DOM). Many of these packages allow extremely flexible
computation over large datasets stored in XML format, and admit the
use of XML-related facilities such as XPath and XSLT programmatically.

The purpose of C<Bio::Phylo::NeXML::DOM> is to introduce integrated DOM
object creation and manipulation to C<Bio::Phylo>, both to make DOM
computation in C<Bio::Phylo> more convenient, and also to provide a
platform for potentially more sophisticated C<Bio::Phylo> modules to
come.

=head1 DESIGN

Besides the notion that DOM capability should be optional for the user,
there are two main design ideas. First, for each C<Bio::Phylo> object
that can be parsed/written as NeXML (i.e., for each
C<Bio::Phylo::NeXML::Writable> object), we provide analogous method
for creating a representative DOM object, or element. These elements
are aggregatable in a DOM document object, whose native stringifying
method can be used to generate valid NeXML. 

Second, we allow flexibility and extensibility in the choice of the
underlying DOM package, while maintaining a consistent DOM interface
that is similar in semantic and syntactic style to the accessors and
mutators that act on the C<Bio::Phylo> objects themselves. This is
achieved through the DOM::DocumentI and DOM::ElementI interfaces,
which define a minimal subset of DOM accessors and mutators, their
inputs and outputs. Concrete instances of these interface classes
provide the bindings between the abstract methods and their
counterparts in the desired DOM implementation. Currently, there are
bindings for two popular packages, C<XML::Twig> and C<XML::LibXML>.

Another priority was simplicity of use; most of the details remain
under the hood in practice. The C<Bio/Phylo/Util/DOM.pm> file defines the
C<to_dom()> method for each C<XMLWritable> package, as well as the
C<Bio::Phylo::NeXML::DOM> package proper. The C<DOM> object is a
factory that is used to create Element and Document objects; it is an
inside-out object that subclasses C<Bio::Phylo>. To curb the
proliferation of method arguments, a DOM factory instance (set by the
latest invocation of C<Bio::Phylo::NeXML::DOM-E<gt>new()>) is maintained in
a package global. This is used by default for object creation with DOM
methods if a DOM factory object is not explicitly provided in the
argument list.

The underlying DOM implementation is set with the C<DOM> factory
constructor's single argument, C<-format>. Even this can be left out;
the default implementation is C<XML::Twig>, which is already required
by C<Bio::Phylo>. Thus, for example, one can use the DOM to convert
a Nexus file to a DOM representation as follows:

 use Bio::Phylo::NeXML::DOM;
 use Bio::Phylo::IO qw( parse );
 Bio::Phylo::NeXML::DOM->new();
 my $project = parse( -file=>'my.nex', -format=>'nexus' );
 my $nex_twig =  $project->doc();
 # The end.

Underlying DOM packages are loaded at runtime as specified by the
C<-format> argument. Packages for unused formats do not need to be
installed.

=head1 INTERFACE METHODS

The minimal DOM interface specifies the following methods. Details can be
obtained from the C<Element> and C<Document> POD.

=head2 Bio::Phylo::NeXML::DOM::Element - DOM Element abstract class

 get_tagname()
 set_tagname()
 get_attributes()
 set_attributes()
 clear_attributes()
 get_text()
 set_text()
 clear_text()

 get_parent()
 get_children()
 get_first_child()
 get_last_child()
 get_next_sibling()
 get_prev_sibling()
 get_elements_by_tagname()

 set_child()
 prune_child()

 to_xml_string()

=head2 Bio::Phylo::NeXML::DOM::Document - DOM Document

 get_encoding()
 set_encoding()

 get_root()
 set_root()

 get_element_by_id()
 get_elements_by_tagname()

 to_xml_string()
 to_xml_file()

=head1 METHODS

=head2 CONSTRUCTOR

=over

=item new()

 Type    : Constructor
 Title   : new
 Usage   : $dom = Bio::Phylo::NeXML::DOM->new(-format=>$format)
 Function: Create a new DOM factory
 Returns : DOM object
 Args    : optional: -format => DOM format (defaults to 'twig')

=cut

    sub new {
        my $self = shift->SUPER::new( '-format' => 'twig', @_ );
        return $DOM = $self;
    }

=back

=head2 FACTORY METHODS

=over

=item create_element()

 Type    : Factory method
 Title   : create_element
 Usage   : $elt = $dom->create_element()
 Function: Create a new XML DOM element
 Returns : DOM element
 Args    : Optional:
           -tag => $tag_name
           -attr => \%attr_hash

=cut

    sub create_element {
        if ( my $format = shift->get_format ) {
            return $fac->create_element( '-format' => $format, @_ );
        }
        else {
            throw 'BadArgs' => 'DOM creator format not set';
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
        if ( my $f = shift->get_format ) {
            return looks_like_class( __PACKAGE__ . '::Element::' . $f )
              ->parse_element(shift);
        }
        else {
            throw 'BadArgs' => 'DOM creator format not set';
        }
    }

=item create_document()

 Type    : Creator
 Title   : create_document
 Usage   : $doc = $dom->create_document()
 Function: Create a new XML DOM document
 Returns : DOM document
 Args    : Package-specific args

=cut

    sub create_document {
        if ( my $format = shift->get_format ) {
            return $fac->create_document( '-format' => $format, @_ );
        }
        else {
            throw 'BadArgs' => 'DOM creator format not set';
        }
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
        if ( my $format = shift->get_format ) {
            my $implementation = __PACKAGE__ . '::' . $format;
            return $implementation->parse_document(shift);
        }
        else {
            throw 'BadArgs' => 'DOM creator format not set';
        }
    }

=back

=head2 MUTATORS

=over

=item set_format()

 Type    : Mutator
 Title   : set_format
 Usage   : $dom->set_format($format)
 Function: Set the format (underlying DOM package bindings) for this object
 Returns : format designator as string
 Args    : format designator as string

=cut

    sub set_format {
        my $self = shift;
        $format{ $self->get_id } = shift;
        return $self;
    }

=back

=head2 ACCESSORS

=over

=item get_format()

 Type    : Accessor
 Title   : get_format
 Usage   : $dom->get_format()
 Function: Get the format designator for this object
 Returns : format designator as string
 Args    : none

=cut

    sub get_format {
        my $self = shift;
        return ucfirst( lc( $format{ $self->get_id } ) );
    }

=item get_dom()

 Type    : Static accessor
 Title   : get_dom
 Usage   : __PACKAGE__->get_dom()
 Function: Get the singleton DOM object
 Returns : instance of this __PACKAGE__
 Args    : none

=cut

    sub get_dom { $DOM ||= __PACKAGE__->new }

=begin comment

 Type    : Internal method
 Title   : _type
 Usage   : $node->_type;
 Function:
 Returns : CONSTANT
 Args    :

=end comment

=cut

    sub _type { $CONSTANT_TYPE }

=begin comment

 Type    : Internal method
 Title   : _cleanup
 Usage   : $node->_cleanup;
 Function:
 Returns : CONSTANT
 Args    :

=end comment

=cut

    sub _cleanup {
        my $self = shift;
        delete $format{ $self->get_id };
    }

=back

=cut

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

The DOM creator abstract classes: L<Bio::Phylo::NeXML::DOM::Element>,
L<Bio::Phylo::NeXML::DOM::Document>

=head1 CITATION

If you use Bio::Phylo in published research, please cite it:

B<Rutger A Vos>, B<Jason Caravas>, B<Klaas Hartmann>, B<Mark A Jensen>
and B<Chase Miller>, 2011. Bio::Phylo - phyloinformatic analysis using Perl.
I<BMC Bioinformatics> B<12>:63.
L<http://dx.doi.org/10.1186/1471-2105-12-63>

=head1 AUTHOR

Mark A. Jensen  (maj -at- fortinbras -dot- us), refactored by Rutger Vos

=head1 TODO

The C<Bio::Phylo::Annotation> class is not yet DOMized.

=cut

}
1;
