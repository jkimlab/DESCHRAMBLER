package Bio::Phylo::Forest::DrawTreeRole;
use strict;
use warnings;
use Carp;
use Bio::Phylo::Forest::TreeRole;
use base 'Bio::Phylo::Forest::TreeRole';
use Bio::Phylo::Forest::DrawNodeRole;
use Bio::Phylo::Util::CONSTANT 'looks_like_hash';
{

	our $AUTOLOAD;
	my @properties = qw(width height node_radius tip_radius node_color node_shape
	node_image branch_color branch_shape branch_width branch_style collapsed_clade_width
	font_face font_size font_style margin margin_top margin_bottom margin_left 
	margin_right padding padding_top padding_bottom padding_left padding_right
	mode shape text_horiz_offset text_vert_offset);

=head1 NAME

Bio::Phylo::Forest::DrawTreeRole - Tree with extra methods for tree drawing

=head1 SYNOPSIS

 # see Bio::Phylo::Forest::Tree

=head1 DESCRIPTION

The object models a phylogenetic tree, a container of Bio::Phylo::For-
est::Node objects. The tree object inherits from Bio::Phylo::Listable,
so look there for more methods.

In addition, this subclass of the default tree object L<Bio::Phylo::Forest::Tree>
has getters and setters for drawing trees, e.g. font and text attributes, etc.

=head1 METHODS

=head2 CONSTRUCTORS

=over

=item new()

Tree constructor.

 Type    : Constructor
 Title   : new
 Usage   : my $tree = Bio::Phylo::Forest::DrawTree->new;
 Function: Instantiates a Bio::Phylo::Forest::DrawTree object.
 Returns : A Bio::Phylo::Forest::DrawTree object.
 Args    : No required arguments.

=cut

    sub new {
        my $class = shift;
        my %args  = looks_like_hash @_;
        if ( not $args{'-tree'} ) {
            return $class->SUPER::new(@_);
        }
        else {
            my $tree = $args{'-tree'};
            my $self = $tree->clone;
            bless $self, $class;
            for my $node ( @{ $self->get_entities } ) {
            	bless $node, 'Bio::Phylo::Forest::DrawNode';
            }              
            
            delete $args{'-tree'};
            for my $key ( keys %args ) {
                my $method = $key;
                $method =~ s/^-/set_/;
                $self->$method( $args{$key} );
            }
            return $self;
        }
    }

=back

=head2 MUTATORS

=over

=item set_width()

 Type    : Mutator
 Title   : set_width
 Usage   : $tree->set_width($width);
 Function: Sets width
 Returns : $self
 Args    : width

=item set_height()

 Type    : Mutator
 Title   : set_height
 Usage   : $tree->set_height($height);
 Function: Sets height
 Returns : $self
 Args    : height

=item set_node_radius()

 Type    : Mutator
 Title   : set_node_radius
 Usage   : $tree->set_node_radius($node_radius);
 Function: Sets node_radius
 Returns : $self
 Args    : node_radius

=item set_tip_radius()

 Type    : Mutator
 Title   : set_tip_node_radius
 Usage   : $tree->set_tip_radius($node_radius);
 Function: Sets tip radius
 Returns : $self
 Args    : tip radius

=item set_node_colour()

 Type    : Mutator
 Title   : set_node_colour
 Usage   : $tree->set_node_colour($node_colour);
 Function: Sets node_colour
 Returns : $self
 Args    : node_colour

=item set_node_shape()

 Type    : Mutator
 Title   : set_node_shape
 Usage   : $tree->set_node_shape($node_shape);
 Function: Sets node_shape
 Returns : $self
 Args    : node_shape

=item set_node_image()

 Type    : Mutator
 Title   : set_node_image
 Usage   : $tree->set_node_image($node_image);
 Function: Sets node_image
 Returns : $self
 Args    : node_image

=item set_collapsed_clade_width()

Sets collapsed clade width.

 Type    : Mutator
 Title   : set_collapsed_clade_width
 Usage   : $tree->set_collapsed_clade_width(6);
 Function: sets the width of collapsed clade triangles relative to uncollapsed tips
 Returns :
 Args    : Positive number

=item set_branch_color()

 Type    : Mutator
 Title   : set_branch_color
 Usage   : $tree->set_branch_color($branch_color);
 Function: Sets branch_color
 Returns : $self
 Args    : branch_color

=item set_branch_shape()

 Type    : Mutator
 Title   : set_branch_shape
 Usage   : $tree->set_branch_shape($branch_shape);
 Function: Sets branch_shape
 Returns : $self
 Args    : branch_shape

=item set_branch_width()

 Type    : Mutator
 Title   : set_branch_width
 Usage   : $tree->set_branch_width($branch_width);
 Function: Sets branch width
 Returns : $self
 Args    : branch_width

=item set_branch_style()

 Type    : Mutator
 Title   : set_branch_style
 Usage   : $tree->set_branch_style($branch_style);
 Function: Sets branch style
 Returns : $self
 Args    : branch_style

=item set_font_face()

 Type    : Mutator
 Title   : set_font_face
 Usage   : $tree->set_font_face($font_face);
 Function: Sets font_face
 Returns : $self
 Args    : font face, Verdana, Arial, Serif

=item set_font_size()

 Type    : Mutator
 Title   : set_font_size
 Usage   : $tree->set_font_size($font_size);
 Function: Sets font_size
 Returns : $self
 Args    : Font size in pixels

=item set_font_style()

 Type    : Mutator
 Title   : set_font_style
 Usage   : $tree->set_font_style($font_style);
 Function: Sets font_style
 Returns : $self
 Args    : Font style, e.g. Italic

=item set_margin()

 Type    : Mutator
 Title   : set_margin
 Usage   : $tree->set_margin($margin);
 Function: Sets margin
 Returns : $self
 Args    : margin

=item set_margin_top()

 Type    : Mutator
 Title   : set_margin_top
 Usage   : $tree->set_margin_top($margin_top);
 Function: Sets margin_top
 Returns : $self
 Args    : margin_top

=item set_margin_bottom()

 Type    : Mutator
 Title   : set_margin_bottom
 Usage   : $tree->set_margin_bottom($margin_bottom);
 Function: Sets margin_bottom
 Returns : $self
 Args    : margin_bottom

=item set_margin_left()

 Type    : Mutator
 Title   : set_margin_left
 Usage   : $tree->set_margin_left($margin_left);
 Function: Sets margin_left
 Returns : $self
 Args    : margin_left

=item set_margin_right()

 Type    : Mutator
 Title   : set_margin_right
 Usage   : $tree->set_margin_right($margin_right);
 Function: Sets margin_right
 Returns : $self
 Args    : margin_right

=item set_padding()

 Type    : Mutator
 Title   : set_padding
 Usage   : $tree->set_padding($padding);
 Function: Sets padding
 Returns : $self
 Args    : padding

=item set_padding_top()

 Type    : Mutator
 Title   : set_padding_top
 Usage   : $tree->set_padding_top($padding_top);
 Function: Sets padding_top
 Returns : $self
 Args    : padding_top

=item set_padding_bottom()

 Type    : Mutator
 Title   : set_padding_bottom
 Usage   : $tree->set_padding_bottom($padding_bottom);
 Function: Sets padding_bottom
 Returns : $self
 Args    : padding_bottom

=item set_padding_left()

 Type    : Mutator
 Title   : set_padding_left
 Usage   : $tree->set_padding_left($padding_left);
 Function: Sets padding_left
 Returns : $self
 Args    : padding_left

=item set_padding_right()

 Type    : Mutator
 Title   : set_padding_right
 Usage   : $tree->set_padding_right($padding_right);
 Function: Sets padding_right
 Returns : $self
 Args    : padding_right

=item set_mode()

 Type    : Mutator
 Title   : set_mode
 Usage   : $tree->set_mode($mode);
 Function: Sets mode
 Returns : $self
 Args    : mode, e.g. 'CLADO' or 'PHYLO'

=item set_shape()

 Type    : Mutator
 Title   : set_shape
 Usage   : $tree->set_shape($shape);
 Function: Sets shape
 Returns : $self
 Args    : shape, e.g. 'RECT', 'CURVY', 'DIAG'

=item set_text_horiz_offset()

 Type    : Mutator
 Title   : set_text_horiz_offset
 Usage   : $tree->set_text_horiz_offset($text_horiz_offset);
 Function: Sets text_horiz_offset
 Returns : $self
 Args    : text_horiz_offset

=item set_text_vert_offset()

 Type    : Mutator
 Title   : set_text_vert_offset
 Usage   : $tree->set_text_vert_offset($text_vert_offset);
 Function: Sets text_vert_offset
 Returns : $self
 Args    : text_vert_offset

=back

=head2 ACCESSORS

=over

=item get_width()

 Type    : Accessor
 Title   : get_width
 Usage   : my $width = $tree->get_width();
 Function: Gets width
 Returns : width
 Args    : NONE

=item get_height()

 Type    : Accessor
 Title   : get_height
 Usage   : my $height = $tree->get_height();
 Function: Gets height
 Returns : height
 Args    : NONE

=item get_node_radius()

 Type    : Accessor
 Title   : get_node_radius
 Usage   : my $node_radius = $tree->get_node_radius();
 Function: Gets node_radius
 Returns : node_radius
 Args    : NONE

=item get_node_colour()

 Type    : Accessor
 Title   : get_node_colour
 Usage   : my $node_colour = $tree->get_node_colour();
 Function: Gets node_colour
 Returns : node_colour
 Args    : NONE

=item get_node_shape()

 Type    : Accessor
 Title   : get_node_shape
 Usage   : my $node_shape = $tree->get_node_shape();
 Function: Gets node_shape
 Returns : node_shape
 Args    : NONE

=item get_node_image()

 Type    : Accessor
 Title   : get_node_image
 Usage   : my $node_image = $tree->get_node_image();
 Function: Gets node_image
 Returns : node_image
 Args    : NONE

=item get_collapsed_clade_width()

Gets collapsed clade width.

 Type    : Mutator
 Title   : get_collapsed_clade_width
 Usage   : $w = $tree->get_collapsed_clade_width();
 Function: gets the width of collapsed clade triangles relative to uncollapsed tips
 Returns : Positive number
 Args    : None

=item get_branch_color()

 Type    : Accessor
 Title   : get_branch_color
 Usage   : my $branch_color = $tree->get_branch_color();
 Function: Gets branch_color
 Returns : branch_color
 Args    : NONE

=item get_branch_shape()

 Type    : Accessor
 Title   : get_branch_shape
 Usage   : my $branch_shape = $tree->get_branch_shape();
 Function: Gets branch_shape
 Returns : branch_shape
 Args    : NONE

=item get_branch_width()

 Type    : Accessor
 Title   : get_branch_width
 Usage   : my $branch_width = $tree->get_branch_width();
 Function: Gets branch_width
 Returns : branch_width
 Args    : NONE

=item get_branch_style()

 Type    : Accessor
 Title   : get_branch_style
 Usage   : my $branch_style = $tree->get_branch_style();
 Function: Gets branch_style
 Returns : branch_style
 Args    : NONE

=item get_font_face()

 Type    : Accessor
 Title   : get_font_face
 Usage   : my $font_face = $tree->get_font_face();
 Function: Gets font_face
 Returns : font_face
 Args    : NONE

=item get_font_size()

 Type    : Accessor
 Title   : get_font_size
 Usage   : my $font_size = $tree->get_font_size();
 Function: Gets font_size
 Returns : font_size
 Args    : NONE

=item get_font_style()

 Type    : Accessor
 Title   : get_font_style
 Usage   : my $font_style = $tree->get_font_style();
 Function: Gets font_style
 Returns : font_style
 Args    : NONE

=item get_margin()

 Type    : Accessor
 Title   : get_margin
 Usage   : my $margin = $tree->get_margin();
 Function: Gets margin
 Returns : margin
 Args    : NONE

=item get_margin_top()

 Type    : Accessor
 Title   : get_margin_top
 Usage   : my $margin_top = $tree->get_margin_top();
 Function: Gets margin_top
 Returns : margin_top
 Args    : NONE

=item get_margin_bottom()

 Type    : Accessor
 Title   : get_margin_bottom
 Usage   : my $margin_bottom = $tree->get_margin_bottom();
 Function: Gets margin_bottom
 Returns : margin_bottom
 Args    : NONE

=item get_margin_left()

 Type    : Accessor
 Title   : get_margin_left
 Usage   : my $margin_left = $tree->get_margin_left();
 Function: Gets margin_left
 Returns : margin_left
 Args    : NONE

=item get_margin_right()

 Type    : Accessor
 Title   : get_margin_right
 Usage   : my $margin_right = $tree->get_margin_right();
 Function: Gets margin_right
 Returns : margin_right
 Args    : NONE

=item get_padding()

 Type    : Accessor
 Title   : get_padding
 Usage   : my $padding = $tree->get_padding();
 Function: Gets padding
 Returns : padding
 Args    : NONE

=item get_padding_top()

 Type    : Accessor
 Title   : get_padding_top
 Usage   : my $padding_top = $tree->get_padding_top();
 Function: Gets padding_top
 Returns : padding_top
 Args    : NONE

=item get_padding_bottom()

 Type    : Accessor
 Title   : get_padding_bottom
 Usage   : my $padding_bottom = $tree->get_padding_bottom();
 Function: Gets padding_bottom
 Returns : padding_bottom
 Args    : NONE

=item get_padding_left()

 Type    : Accessor
 Title   : get_padding_left
 Usage   : my $padding_left = $tree->get_padding_left();
 Function: Gets padding_left
 Returns : padding_left
 Args    : NONE

=item get_padding_right()

 Type    : Accessor
 Title   : get_padding_right
 Usage   : my $padding_right = $tree->get_padding_right();
 Function: Gets padding_right
 Returns : padding_right
 Args    : NONE

=item get_mode()

 Type    : Accessor
 Title   : get_mode
 Usage   : my $mode = $tree->get_mode();
 Function: Gets mode
 Returns : mode
 Args    : NONE

=cut

    sub get_mode {
        my $self = shift;
        if ( $self->is_cladogram ) {
            return 'CLADO';
        }
        return $self->get_meta_object( 'map:mode' );
    }

=item get_shape()

 Type    : Accessor
 Title   : get_shape
 Usage   : my $shape = $tree->get_shape();
 Function: Gets shape
 Returns : shape
 Args    : NONE

=item get_text_horiz_offset()

 Type    : Accessor
 Title   : get_text_horiz_offset
 Usage   : my $text_horiz_offset = $tree->get_text_horiz_offset();
 Function: Gets text_horiz_offset
 Returns : text_horiz_offset
 Args    : NONE

=item get_text_vert_offset()

 Type    : Accessor
 Title   : get_text_vert_offset
 Usage   : my $text_vert_offset = $tree->get_text_vert_offset();
 Function: Gets text_vert_offset
 Returns : text_vert_offset
 Args    : NONE

=begin comment

This method re-computes the node coordinates

=end comment

=cut

    sub _redraw {
        my $self = shift;
        my ( $width, $height ) = ( $self->get_width, $self->get_height );
        my $tips_seen  = 0;
        my $total_tips = $self->calc_number_of_terminals();
        if ( my $root = $self->get_root ) {
			my $tallest    = $root->calc_max_path_to_tips;
			my $maxnodes   = $root->calc_max_nodes_to_tips;
			my $is_clado   = $self->get_mode =~ m/^c/i;
			$self->visit_depth_first(
				'-post' => sub {
					my $node = shift;
					my ( $x, $y );
					if ( $node->is_terminal ) {
						$tips_seen++;
						$y = ( $height / $total_tips ) * $tips_seen;
						$x =
							$is_clado
						  ? $width
						  : ( $width / $tallest ) * $node->calc_path_to_root;
					}
					else {
						my @children = @{ $node->get_children };
						$y += $_->get_y for @children;
						$y /= scalar @children;
						$x =
							$is_clado
						  ? $width -
						  ( ( $width / $maxnodes ) * $node->calc_max_nodes_to_tips )
						  : ( $width / $tallest ) * $node->calc_path_to_root;
					}
					$node->set_y($y);
					$node->set_x($x);
				}
			);
        }
    }


=back

=cut

	sub AUTOLOAD {
		my $self = shift;
		my $method = $AUTOLOAD;
		$method =~ s/.+://; # strip package names
		$method =~ s/colour/color/; # map Canadian/British to American :)
		
		# if the user calls some non-existant method, try to do the
		# usual way, with this message, from perspective of caller
		my $template = 'Can\'t locate object method "%s" via package "%s"';
		
		# handler set_* method calls
		if ( $method =~ /^set_(.+)$/ ) {
			my $prop = $1;

			# test if this is actually settable			
			if ( grep { /^\Q$prop\E$/ } @properties ) {
				my $value = shift;
			
				# these are properties that must be applied to all nodes
				if ( $prop =~ /_(?:node|tip|branch|clade|font|text)_/ ) {
					$self->visit(sub{
						my $node = shift;
						$node->$method($value);
					});
				}
			
				# these are properties that must be expanded to left/right/top/bottom
				if ( $prop =~ /_(?:margin|padding)$/ ) {
					for my $pos ( qw(left right top bottom) ) {
						my $expanded = $method . '_' . $pos;
						$self->$expanded($value);
					}
				}
			
				# also apply the property to the tree itself
				$self->set_meta_object( "map:$prop" => $value );
				$self->_redraw;
				return $self;
			}
			else {				
				croak sprintf $template, $method, __PACKAGE__;
			}
		}
		elsif ( $method =~ /^get_(.+)$/ ) {
			my $prop = $1;
			
			# test if this is actually gettable			
			if ( grep { /^\Q$prop\E$/ } @properties ) {
			
				# return the annotation
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

=item L<Bio::Phylo::Forest::Tree>

This object inherits from L<Bio::Phylo::Forest::Tree>, so methods
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
