package Bio::Phylo::Forest::DrawNodeRole;
use strict;
use warnings;
use Carp;
use Bio::Phylo::Forest::NodeRole;
use base 'Bio::Phylo::Forest::NodeRole';
{

	our $AUTOLOAD;
	my @properties = qw(x y radius tip_radius node_color node_outline_color
	node_shape node_image branch_color branch_shape branch_width branch_style
	collapsed collapsed_clade_width font_face font_size font_style font_color
	font_weight text_horiz_offset text_vert_offset rotation clade_label
	clade_label_font);

=head1 NAME

Bio::Phylo::Forest::DrawNodeRole - Tree node with extra methods for tree drawing

=head1 SYNOPSIS

 # see Bio::Phylo::Forest::Node

=head1 DESCRIPTION

This module defines a node object and its methods. The node is fairly
syntactically rich in terms of navigation, and additional getters are provided to
further ease navigation from node to node. Typical first daughter -> next sister
traversal and recursion is possible, but there are also shrinkwrapped methods
that return for example all terminal descendants of the focal node, or all
internals, etc.

Node objects are inserted into tree objects, although technically the tree
object is only a container holding all the nodes together. Unless there are
orphans all nodes can be reached without recourse to the tree object.

In addition, this subclass of the default node object L<Bio::Phylo::Forest::Node>
has getters and setters for drawing trees and nodes, e.g. X/Y coordinates, font
and text attributes, etc.

=head1 METHODS

=head2 MUTATORS

=over

=item set_collapsed()

 Type    : Mutator
 Title   : set_collapsed
 Usage   : $node->set_collapsed(1);
 Function: Sets whether the node's descendants are shown as collapsed into a triangle
 Returns : $self
 Args    : true or false value

=item set_collapsed_clade_width()

Sets collapsed clade width.

 Type    : Mutator
 Title   : set_collapsed_clade_width
 Usage   : $node->set_collapsed_clade_width(6);
 Function: sets the width of collapsed clade triangles relative to uncollapsed tips
 Returns :
 Args    : Positive number

=item set_x()

 Type    : Mutator
 Title   : set_x
 Usage   : $node->set_x($x);
 Function: Sets x
 Returns : $self
 Args    : x

=item set_y()

 Type    : Mutator
 Title   : set_y
 Usage   : $node->set_y($y);
 Function: Sets y
 Returns : $self
 Args    : y

=item set_radius()

 Type    : Mutator
 Title   : set_radius
 Usage   : $node->set_radius($radius);
 Function: Sets radius
 Returns : $self
 Args    : radius

=cut

    *set_node_radius = \&set_radius;
	*get_node_radius = \&get_radius;

=item set_tip_radius()

 Type    : Mutator
 Title   : set_tip_node_radius
 Usage   : $tree->set_tip_radius($node_radius);
 Function: Sets tip radius
 Returns : $self
 Args    : tip radius

=item set_node_color()

 Type    : Mutator
 Title   : set_node_color
 Usage   : $node->set_node_color($node_color);
 Function: Sets node_color
 Returns : $self
 Args    : node_color

=item set_node_outline_color()

 Type    : Mutator
 Title   : set_node_outline_color
 Usage   : $node->set_node_outline_color($node_outline_color);
 Function: Sets node outline color
 Returns : $self
 Args    : node_color

=item set_node_shape()

 Type    : Mutator
 Title   : set_node_shape
 Usage   : $node->set_node_shape($node_shape);
 Function: Sets node_shape
 Returns : $self
 Args    : node_shape

=item set_node_image()

 Type    : Mutator
 Title   : set_node_image
 Usage   : $node->set_node_image($node_image);
 Function: Sets node_image
 Returns : $self
 Args    : node_image

=item set_branch_color()

 Type    : Mutator
 Title   : set_branch_color
 Usage   : $node->set_branch_color($branch_color);
 Function: Sets branch_color
 Returns : $self
 Args    : branch_color

=item set_branch_shape()

 Type    : Mutator
 Title   : set_branch_shape
 Usage   : $node->set_branch_shape($branch_shape);
 Function: Sets branch_shape
 Returns : $self
 Args    : branch_shape

=item set_branch_width()

 Type    : Mutator
 Title   : set_branch_width
 Usage   : $node->set_branch_width($branch_width);
 Function: Sets branch width
 Returns : $self
 Args    : branch_width

=item set_branch_style()

 Type    : Mutator
 Title   : set_branch_style
 Usage   : $node->set_branch_style($branch_style);
 Function: Sets branch style
 Returns : $self
 Args    : branch_style

=item set_font_face()

 Type    : Mutator
 Title   : set_font_face
 Usage   : $node->set_font_face($font_face);
 Function: Sets font_face
 Returns : $self
 Args    : font_face

=item set_font_size()

 Type    : Mutator
 Title   : set_font_size
 Usage   : $node->set_font_size($font_size);
 Function: Sets font_size
 Returns : $self
 Args    : font_size

=item set_font_style()

 Type    : Mutator
 Title   : set_font_style
 Usage   : $node->set_font_style($font_style);
 Function: Sets font_style
 Returns : $self
 Args    : font_style

=item set_font_weight()

 Type    : Mutator
 Title   : set_font_weight
 Usage   : $node->set_font_weight($font_weight);
 Function: Sets font_weight
 Returns : $self
 Args    : font_weight

=item set_font_color()

 Type    : Mutator
 Title   : set_font_color
 Usage   : $node->set_font_color($color);
 Function: Sets font_color
 Returns : font_color
 Args    : A color, which, depending on the underlying tree drawer, can either
           be expressed as a word ('red'), a hex code ('#00CC00') or an rgb
           statement ('rgb(0,255,0)')

=item set_text_horiz_offset()

 Type    : Mutator
 Title   : set_text_horiz_offset
 Usage   : $node->set_text_horiz_offset($text_horiz_offset);
 Function: Sets text_horiz_offset
 Returns : $self
 Args    : text_horiz_offset

=item set_text_vert_offset()

 Type    : Mutator
 Title   : set_text_vert_offset
 Usage   : $node->set_text_vert_offset($text_vert_offset);
 Function: Sets text_vert_offset
 Returns : $self
 Args    : text_vert_offset

=item set_rotation()

 Type    : Mutator
 Title   : set_rotation
 Usage   : $node->set_rotation($rotation);
 Function: Sets rotation
 Returns : $self
 Args    : rotation

=item set_clade_label()

 Type    : Mutator
 Title   : set_clade_label
 Usage   : $node->set_clade_label('Mammalia');
 Function: Sets a label for an entire clade to be visualized outside the tree
 Returns : $self
 Args    : string 

=item set_clade_label_font()

 Type    : Mutator
 Title   : set_clade_label_font
 Usage   : $node->set_clade_label_font({ '-face' => 'Verdana' });
 Function: Sets font properties for the clade label
 Returns : $self
 Args    : {
	'-face'   => 'Verdana', # Arial, Times, etc.
	'-weight' => 'bold',
	'-style'  => 'italic',
	'-colour' => 'red',
 }
 
=back

=head2 ACCESSORS

=over

=item get_collapsed()

 Type    : Mutator
 Title   : get_collapsed
 Usage   : something() if $node->get_collapsed();
 Function: Gets whether the node's descendants are shown as collapsed into a triangle
 Returns : true or false value
 Args    : NONE

=item get_first_daughter()

Gets invocant's first daughter.

 Type    : Accessor
 Title   : get_first_daughter
 Usage   : my $f_daughter = $node->get_first_daughter;
 Function: Retrieves a node's leftmost daughter.
 Returns : Bio::Phylo::Forest::Node
 Args    : NONE

=cut

    sub get_first_daughter {
        my $self = shift;
        if ( $self->get_collapsed ) {
            return;
        }
        else {
            return $self->SUPER::get_first_daughter;
        }
    }

=item get_last_daughter()

Gets invocant's last daughter.

 Type    : Accessor
 Title   : get_last_daughter
 Usage   : my $l_daughter = $node->get_last_daughter;
 Function: Retrieves a node's rightmost daughter.
 Returns : Bio::Phylo::Forest::Node
 Args    : NONE

=cut

    sub get_last_daughter {
        my $self = shift;
        if ( $self->get_collapsed ) {
            return;
        }
        else {
            return $self->SUPER::get_last_daughter;
        }
    }

=item get_children()

Gets invocant's immediate children.

 Type    : Query
 Title   : get_children
 Usage   : my @children = @{ $node->get_children };
 Function: Returns an array reference of immediate
           descendants, ordered from left to right.
 Returns : Array reference of
           Bio::Phylo::Forest::Node objects.
 Args    : NONE

=cut

    sub get_children {
        my $self = shift;
        if ( $self->get_collapsed ) {
            return [];
        }
        else {
            return $self->SUPER::get_children;
        }
    }

=item get_x()

 Type    : Accessor
 Title   : get_x
 Usage   : my $x = $node->get_x();
 Function: Gets x
 Returns : x
 Args    : NONE

=item get_y()

 Type    : Accessor
 Title   : get_y
 Usage   : my $y = $node->get_y();
 Function: Gets y
 Returns : y
 Args    : NONE

=item get_radius()

 Type    : Accessor
 Title   : get_radius
 Usage   : my $radius = $node->get_radius();
 Function: Gets radius
 Returns : radius
 Args    : NONE

=item get_node_color()

 Type    : Accessor
 Title   : get_node_color
 Usage   : my $node_color = $node->get_node_color();
 Function: Gets node_color
 Returns : node_color
 Args    : NONE

=item get_node_outline_color()

 Type    : Accessor
 Title   : get_node_outline_color
 Usage   : my $node_outline_color = $node->get_node_outline_color();
 Function: Gets node outline color
 Returns : node_color
 Args    : NONE

=item get_node_shape()

 Type    : Accessor
 Title   : get_node_shape
 Usage   : my $node_shape = $node->get_node_shape();
 Function: Gets node_shape
 Returns : node_shape
 Args    : NONE

=item get_node_image()

 Type    : Accessor
 Title   : get_node_image
 Usage   : my $node_image = $node->get_node_image();
 Function: Gets node_image
 Returns : node_image
 Args    : NONE

=item get_collapsed_clade_width()

Gets collapsed clade width.

 Type    : Mutator
 Title   : get_collapsed_clade_width
 Usage   : $w = $node->get_collapsed_clade_width();
 Function: gets the width of collapsed clade triangles relative to uncollapsed tips
 Returns : Positive number
 Args    : None

=item get_branch_color()

 Type    : Accessor
 Title   : get_branch_color
 Usage   : my $branch_color = $node->get_branch_color();
 Function: Gets branch_color
 Returns : branch_color
 Args    : NONE

=item get_branch_shape()

 Type    : Accessor
 Title   : get_branch_shape
 Usage   : my $branch_shape = $node->get_branch_shape();
 Function: Gets branch_shape
 Returns : branch_shape
 Args    : NONE

=item get_branch_width()

 Type    : Accessor
 Title   : get_branch_width
 Usage   : my $branch_width = $node->get_branch_width();
 Function: Gets branch_width
 Returns : branch_width
 Args    : NONE

=item get_branch_style()

 Type    : Accessor
 Title   : get_branch_style
 Usage   : my $branch_style = $node->get_branch_style();
 Function: Gets branch_style
 Returns : branch_style
 Args    : NONE

=item get_font_face()

 Type    : Accessor
 Title   : get_font_face
 Usage   : my $font_face = $node->get_font_face();
 Function: Gets font_face
 Returns : font_face
 Args    : NONE

=item get_font_size()

 Type    : Accessor
 Title   : get_font_size
 Usage   : my $font_size = $node->get_font_size();
 Function: Gets font_size
 Returns : font_size
 Args    : NONE

=item get_font_style()

 Type    : Accessor
 Title   : get_font_style
 Usage   : my $font_style = $node->get_font_style();
 Function: Gets font_style
 Returns : font_style
 Args    : NONE
 
 =item get_font_weight()

 Type    : Mutator
 Title   : get_font_weight
 Usage   : my $font_weight = $node->get_font_weight();
 Function: Gets font_weight
 Returns : font_weight
 Args    : NONE

=item get_font_color()

 Type    : Accessor
 Title   : get_font_color
 Usage   : my $color = $node->get_font_color();
 Function: Gets font_color
 Returns : font_color
 Args    : NONE

=item get_text_horiz_offset()

 Type    : Accessor
 Title   : get_text_horiz_offset
 Usage   : my $text_horiz_offset = $node->get_text_horiz_offset();
 Function: Gets text_horiz_offset
 Returns : text_horiz_offset
 Args    : NONE

=item get_text_vert_offset()

 Type    : Accessor
 Title   : get_text_vert_offset
 Usage   : my $text_vert_offset = $node->get_text_vert_offset();
 Function: Gets text_vert_offset
 Returns : text_vert_offset
 Args    : NONE

=item get_rotation()

 Type    : Accessor
 Title   : get_rotation
 Usage   : my $rotation = $node->get_rotation();
 Function: Gets rotation
 Returns : rotation
 Args    : NONE

=item get_clade_label()

 Type    : Accessor
 Title   : get_clade_label
 Usage   : my $l = $node->get_clade_label();
 Function: Gets a label for an entire clade to be visualized outside the tree
 Returns : string
 Args    : NONE

=item get_clade_label_font()

 Type    : Accessor
 Title   : get_clade_label_font
 Usage   : my %h = %{ $node->get_clade_label_font() };
 Function: gets font properties for the clade label
 Returns : undef or hashref
 Args    : NONE
 
=back

=cut

	sub AUTOLOAD {
		my $self = shift;
		my $method = $AUTOLOAD;
		$method =~ s/.+://; # strip package name
		$method =~ s/colour/color/; # map British/Canadian to American :)
		
		# if the user calls some non-existant method, try to do the
		# usual way, with this message, from perspective of caller
		my $template = 'Can\'t locate object method "%s" via package "%s"';		
		
		if ( $method =~ /^set_(.+)$/ ) {
			my $prop = $1;
			if ( grep { /^\Q$prop\E$/ } @properties ) {
				my $value = shift;
				return $self->set_meta_object( "map:$prop" => $value );
			}
			else {
				croak sprintf $template, $method, __PACKAGE__;
			}
		}
		elsif ( $method =~ /^get_(.+)$/ ) {
			my $prop = $1;
			if ( grep { /^\Q$prop\E$/ } @properties ) {
				my $value = shift;
				return $self->get_meta_object( "map:$prop" );
			}
			else {
				croak sprintf $template, $method, __PACKAGE__;
			}			
		}
		else {
			croak sprintf $template, $method, __PACKAGE__;
		}
	}


    # podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::Forest::Node>

This object inherits from L<Bio::Phylo::Forest::Node>, so methods
defined there are also applicable here.

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
1;
