package Bio::Phylo::Treedrawer;
use strict;
use warnings;
use Bio::Phylo::Util::Logger;
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw'_TREE_ /looks_like/ _PI_';

my @fields = qw(
  WIDTH
  BRANCH_WIDTH
  HEIGHT
  MODE
  SHAPE
  PADDING
  NODE_RADIUS
  TIP_RADIUS
  TEXT_HORIZ_OFFSET
  TEXT_VERT_OFFSET
  TEXT_WIDTH
  TREE
  _SCALEX
  _SCALEY
  SCALE
  FORMAT
  COLLAPSED_CLADE_WIDTH
  CLADE_LABEL_WIDTH
  PIE_COLORS;
);

my $PI     = _PI_;
my $tips   = 0.000_000_000_000_01;
my $logger = Bio::Phylo::Util::Logger->new;

=head1 NAME

Bio::Phylo::Treedrawer - Visualizer of tree shapes

=head1 SYNOPSIS

 use Bio::Phylo::IO 'parse';
 use Bio::Phylo::Treedrawer;

 my $string = '((A:1,B:2)n1:3,C:4)n2:0;';
 my $tree = parse( -format => 'newick', -string => $string )->first;

 my $treedrawer = Bio::Phylo::Treedrawer->new(
    -width  => 800,
    -height => 600,
    -shape  => 'CURVY', # curvogram
    -mode   => 'PHYLO', # phylogram
    -format => 'SVG'
 );

 $treedrawer->set_scale_options(
    -width => '100%',
    -major => '10%', # major cross hatch interval
    -minor => '2%',  # minor cross hatch interval
    -label => 'MYA',
 );

 $treedrawer->set_tree($tree);
 print $treedrawer->draw;

=head1 DESCRIPTION

This module prepares a tree object for drawing (calculating coordinates for
nodes) and calls the appropriate format-specific drawer.

=head1 METHODS

=head2 CONSTRUCTOR

=over

=item new()

Treedrawer constructor.

 Type    : Constructor
 Title   : new
 Usage   : my $treedrawer = Bio::Phylo::Treedrawer->new(
               %args 
           );
 Function: Initializes a Bio::Phylo::Treedrawer object.
 Alias   :
 Returns : A Bio::Phylo::Treedrawer object.
 Args    : none.

=cut

sub new {
    my $class = shift;
    my $self  = {
        'WIDTH'                 => 500,
        'HEIGHT'                => 500,
        'MODE'                  => 'PHYLO',
        'SHAPE'                 => 'CURVY',
        'PADDING'               => 50,
        'NODE_RADIUS'           => 0,
        'TIP_RADIUS'            => 0,
        'TEXT_HORIZ_OFFSET'     => 6,
        'TEXT_VERT_OFFSET'      => 4,
        'TEXT_WIDTH'            => 150,
        'TREE'                  => undef,
        '_SCALEX'               => 1,
        '_SCALEY'               => 1,
        'FORMAT'                => 'Svg',
        'SCALE'                 => undef,
        'BRANCH_WIDTH'          => 1,
        'COLLAPSED_CLADE_WIDTH' => 6,
        'CLADE_LABEL_WIDTH'     => 36,
        'PIE_COLORS'            => {},
    };
    bless $self, $class;
    if (@_) {
        my %opts = looks_like_hash @_;
        for my $key ( keys %opts ) {
            my $mutator = lc $key;
            $mutator =~ s/^-/set_/;
            $self->$mutator( $opts{$key} );
        }
    }
    return $self;
}

sub _cascading_setter {
    my ( $self, $value ) = @_;
    my ( $package, $filename, $line, $subroutine ) = caller(1);
    $subroutine =~ s/.*://;
    $logger->debug($subroutine);
    if ( my $tree = $self->get_tree ) {
        if ( $tree->can($subroutine) ) {
            $tree->$subroutine($value);
        }
    }
    $subroutine =~ s/^set_//;
    $self->{ uc $subroutine } = $value;
    return $self;
}

sub _cascading_getter {
    my ( $self, $invocant ) = @_;
    my ( $package, $filename, $line, $subroutine ) = caller(1);
    $subroutine =~ s/.*://;
    $logger->debug($subroutine);
    if ( $invocant ) {
        
        # The general idea is that there are certain properties that can potentially be
        # set globally (i.e. in this package) or at the level of the object it applies
        # to. For example, maybe we want to set the node radius globally here, or maybe
        # we want to set it on the node. The idea, here, is then that we might first
        # check to see if the values are set on $invocant, and if not, return the global
        # value. The way this used to be done was by calling ->can(), however, because of
        # the way in which method calls are handled by the Draw*Role classes, we can't
        # do that.
        #if ( $invocant->can($subroutine) ) {
            my $value = $invocant->$subroutine();
            if ( defined $value ) {
                return $value;
            }
        #}
    }
    $subroutine =~ s/^get_//;
    return $self->{ uc $subroutine };
}

=back

=head2 MUTATORS

=over

=item set_format()

Sets image format.

 Type    : Mutator
 Title   : set_format
 Usage   : $treedrawer->set_format('Svg');
 Function: Sets the drawer submodule.
 Returns :
 Args    : Name of an image format

=cut

sub set_format {
    my ( $self, $format ) = @_;
    $format = ucfirst( lc($format) );
    if ( looks_like_class __PACKAGE__ . '::' . $format ) {
        $self->{'FORMAT'} = $format;
        return $self;
    }
    else {
        throw 'BadFormat' => "'$format' is not a valid image format";
    }
}

=item set_width()

Sets image width.

 Type    : Mutator
 Title   : set_width
 Usage   : $treedrawer->set_width(1000);
 Function: sets the width of the drawer canvas.
 Returns :
 Args    : Integer width in pixels.

=cut

sub set_width {
    my ( $self, $width ) = @_;
    if ( looks_like_number $width && $width > 0 ) {
        $self->{'WIDTH'} = $width;
    }
    else {
        throw 'BadNumber' => "'$width' is not a valid image width";
    }
    return $self;
}

=item set_height()

Sets image height.

 Type    : Mutator
 Title   : set_height
 Usage   : $treedrawer->set_height(1000);
 Function: sets the height of the canvas.
 Returns :
 Args    : Integer height in pixels.

=cut

sub set_height {
    my ( $self, $height ) = @_;
    if ( looks_like_number $height && $height > 0 ) {
        $self->{'HEIGHT'} = $height;
    }
    else {
        throw 'BadNumber' => "'$height' is not a valid image height";
    }
    return $self;
}

=item set_mode()

Sets tree drawing mode.

 Type    : Mutator
 Title   : set_mode
 Usage   : $treedrawer->set_mode('clado');
 Function: Sets the tree mode, i.e. cladogram 
           or phylogram.
 Returns : Invocant.
 Args    : String, [clado|phylo]

=cut

sub set_mode {
    my ( $self, $mode ) = @_;
    if ( $mode =~ m/^(?:clado|phylo)$/i ) {
        $self->{'MODE'} = uc $mode;
    }
    else {
        throw 'BadFormat' => "'$mode' is not a valid drawing mode";
    }
    return $self;
}

=item set_shape()

Sets tree drawing shape.

 Type    : Mutator
 Title   : set_shape
 Usage   : $treedrawer->set_shape('rect');
 Function: Sets the tree shape, i.e. 
           rectangular, diagonal, curvy or radial.
 Returns : Invocant.
 Args    : String, [rect|diag|curvy|radial]

=cut

sub set_shape {
    my ( $self, $shape ) = @_;
    if ( $shape =~ m/^(?:rect|diag|curvy|radial|unrooted)/i ) {
        $self->{'SHAPE'} = uc $shape;
    }
    else {
        throw 'BadFormat' => "'$shape' is not a valid drawing shape";
    }
    return $self;
}

=item set_padding()

Sets image padding.

 Type    : Mutator
 Title   : set_padding
 Usage   : $treedrawer->set_padding(100);
 Function: Sets the canvas padding.
 Returns :
 Args    : Integer value in pixels.

=cut

sub set_padding {
    my ( $self, $padding ) = @_;
    if ( looks_like_number $padding && $padding > 0 ) {
        $self->{'PADDING'} = $padding;
    }
    else {
        throw 'BadNumber' => "'$padding' is not a valid padding value";
    }
    return $self;
}

=item set_text_horiz_offset()

Sets text horizontal offset.

 Type    : Mutator
 Title   : set_text_horiz_offset
 Usage   : $treedrawer->set_text_horiz_offset(5);
 Function: Sets the distance between 
           tips and text, in pixels.
 Returns :
 Args    : Integer value in pixels.

=cut

sub set_text_horiz_offset {
    my ( $self, $offset ) = @_;
    if ( looks_like_number $offset ) {
        $self->{'TEXT_HORIZ_OFFSET'} = $offset;
    }
    else {
        throw 'BadNumber' =>
          "'$offset' is not a valid text horizontal offset value";
    }
    return $self;
}

=item set_text_vert_offset()

Sets text vertical offset.

 Type    : Mutator
 Title   : set_text_vert_offset
 Usage   : $treedrawer->set_text_vert_offset(3);
 Function: Sets the text baseline 
           relative to the tips, in pixels.
 Returns :
 Args    : Integer value in pixels.

=cut

sub set_text_vert_offset {
    my ( $self, $offset ) = @_;
    if ( looks_like_number $offset ) {
        $self->{'TEXT_VERT_OFFSET'} = $offset;
    }
    else {
        throw 'BadNumber' =>
          "'$offset' is not a valid text vertical offset value";
    }
    return $self;
}

=item set_text_width()

Sets text width.

 Type    : Mutator
 Title   : set_text_width
 Usage   : $treedrawer->set_text_width(150);
 Function: Sets the canvas width for 
           terminal taxon names.
 Returns :
 Args    : Integer value in pixels.

=cut

sub set_text_width {
    my ( $self, $width ) = @_;
    if ( looks_like_number $width && $width > 0 ) {
        $self->{'TEXT_WIDTH'} = $width;
    }
    else {
        throw 'BadNumber' => "'$width' is not a valid text width value";
    }
    return $self;
}

=item set_tree()

Sets tree to draw.

 Type    : Mutator
 Title   : set_tree
 Usage   : $treedrawer->set_tree($tree);
 Function: Sets the Bio::Phylo::Forest::Tree 
           object to unparse.
 Returns :
 Args    : A Bio::Phylo::Forest::Tree object.

=cut

sub set_tree {
    my ( $self, $tree ) = @_;
    if ( looks_like_object $tree, _TREE_ ) {
        $self->{'TREE'} = $tree->negative_to_zero;
        my $root = $tree->get_root;
        if ( my $length = $root->get_branch_length ) {
            $logger->warn("Collapsing root branch length of $length");
            $root->set_branch_length(0);
        }
    }
    return $self;
}

=item set_scale_options()

Sets time scale options.

 Type    : Mutator
 Title   : set_scale_options
 Usage   : $treedrawer->set_scale_options(
                -width   => 400,
                -major   => '10%', # major cross hatch interval
                -minor   => '2%',  # minor cross hatch interval
                -blocks  => '10%', # alternating blocks in light-gray
                -label   => 'MYA',
                -reverse => 1, # tips are 0
                -tmpl    => '%d', # sprintf template for major cross hatch numbers
                -font    => {
                   -face => 'Verdana',
                   -size => 11,
                }
            );
 Function: Sets the options for time (distance) scale
 Returns :
 Args    :
	-width   => 400,
	-major   => '10%', # major cross hatch interval
	-minor   => '2%',  # minor cross hatch interval
	-blocks  => '10%', # alternating blocks in light-gray
	-label   => 'MYA',
	-reverse => 1, # tips are 0
	-tmpl    => '%d', # sprintf template for major cross hatch numbers
	-font    => {
	   -face => 'Verdana',
	   -size => 11,
	}           

=cut

sub set_scale_options {
    my $self = shift;
    if ( ( @_ && !scalar @_ % 2 ) || ( scalar @_ == 1 && ref $_[0] eq 'HASH' ) ) {
        my %o; # %options
        if ( scalar @_ == 1 && ref $_[0] eq 'HASH' ) {
            %o = %{ $_[0] };
        }
        else {
            %o = looks_like_hash @_;
        }
    
        # copy verbatim
        $self->{'SCALE'}->{'-label'}   = $o{'-label'};
        $self->{'SCALE'}->{'-units'}   = $o{'-units'};
        $self->{'SCALE'}->{'-reverse'} = $o{'-reverse'};
        $self->{'SCALE'}->{'-font'}    = $o{'-font'};
        $self->{'SCALE'}->{'-tmpl'}    = $o{'-tmpl'};
        $self->{'SCALE'}->{'-blocks'}  = $o{'-blocks'};
    
        # set scale width, either pixels or relative to tree
        if ( looks_like_number $o{'-width'} or $o{'-width'} =~ m/^\d+%$/ ) {
            $self->{'SCALE'}->{'-width'} = $o{'-width'};
        }
        else {
            throw 'BadArgs' => "\"$o{'-width'}\" is invalid for '-width'";
        }
    
        # set major tick mark distances
        if ( looks_like_number $o{'-major'} or $o{'-major'} =~ m/^\d+%$/ ) {
            $self->{'SCALE'}->{'-major'} = $o{'-major'};
        }
        else {
            throw 'BadArgs' => "\"$o{'-major'}\" is invalid for '-major'";
        }
    
        # set minor tick mark distances
        if ( looks_like_number $o{'-minor'} or $o{'-minor'} =~ m/^\d+%$/ ) {
            $self->{'SCALE'}->{'-minor'} = $o{'-minor'};
        }
        else {
            throw 'BadArgs' => "\"$o{'-minor'}\" is invalid for '-minor'";
        }
    }
    else {
        throw 'OddHash' => 'Odd number of elements in hash assignment';
    }
    return $self;
}

=item set_pie_colors

Sets a hash reference whose keys are (unique) names for the different segments in a
likelihood pie chart, and whose values are color codes.

 Type    : Mutator
 Title   : set_pie_colors
 Usage   : $treedrawer->set_pie_colors({ 'p1' => 'red', 'p2' => 'blue' });
 Function: sets likelihood pie colors
 Returns :
 Args    : HASH

=cut

sub set_pie_colors {
	my ( $self, $hash ) = @_;
	if ( ref($hash) eq 'HASH' ) {
		$self->{'PIE_COLORS'} = $hash;
	}
	else {
		throw 'BadArgs' => "Not a hash reference!";
	}
	return $self;
}

=back

=head2 CASCADING MUTATORS

=over

=item set_branch_width()

Sets branch width.

 Type    : Mutator
 Title   : set_branch_width
 Usage   : $treedrawer->set_branch_width(1);
 Function: sets the width of branch lines
 Returns :
 Args    : Integer width in pixels.

=cut

sub set_branch_width {
    my ( $self, $width ) = @_;
    if ( looks_like_number $width && $width > 0 ) {
        $self->_cascading_setter($width);
    }
    else {
        throw 'BadNumber' => "'$width' is not a valid branch width";
    }
    return $self;
}

=item set_node_radius()

Sets node radius.

 Type    : Mutator
 Title   : set_node_radius
 Usage   : $treedrawer->set_node_radius(20);
 Function: Sets the node radius in pixels.
 Returns :
 Args    : Integer value in pixels.

=cut

sub set_node_radius {
    my ( $self, $radius ) = @_;
    if ( looks_like_number $radius && $radius >= 0 ) {
        $self->_cascading_setter($radius);
    }
    else {
        throw 'BadNumber' => "'$radius' is not a valid node radius value";
    }
    return $self;
}

=item set_collapsed_clade_width()

Sets collapsed clade width.

 Type    : Mutator
 Title   : set_collapsed_clade_width
 Usage   : $treedrawer->set_collapsed_clade_width(6);
 Function: sets the width of collapsed clade triangles relative to uncollapsed tips
 Returns :
 Args    : Positive number

=cut

sub set_collapsed_clade_width {
    my ( $self, $width ) = @_;
    if ( looks_like_number $width && $width > 0 ) {
        $self->_cascading_setter($width);
    }
    else {
        throw 'BadNumber' => "'$width' is not a valid image width";
    }
    return $self;
}

=item set_clade_label_width

Sets clade label width, i.e. the spacing between nested clade annotations

 Type    : Mutator
 Title   : set_clade_label_width
 Usage   : $treedrawer->set_clade_label_width(6);
 Function: sets the spacing between nested clade annotations
 Returns :
 Args    : Positive number

=cut

sub set_clade_label_width {
	my ( $self, $width ) = @_;
	if ( looks_like_number $width && $width >= 0 ) {
		$self->{'CLADE_LABEL_WIDTH'} = $width;
	}
	else {
		throw 'BadNumber' => "'$width' is not a valid clade label width value";
	}
	return $self;
}

=item set_tip_radius()

Sets tip radius.

 Type    : Mutator
 Title   : set_tip_radius
 Usage   : $treedrawer->set_tip_radius(20);
 Function: Sets the tip radius in pixels.
 Returns :
 Args    : Integer value in pixels.

=cut

sub set_tip_radius {
    my ( $self, $radius ) = @_;
    if ( looks_like_number $radius && $radius >= 0 ) {
        $self->_cascading_setter($radius);
    }
    else {
        throw 'BadNumber' => "'$radius' is not a valid tip radius value";
    }
    return $self;
}

=back

=head2 ACCESSORS

=over

=item get_format()

Gets image format.

 Type    : Accessor
 Title   : get_format
 Usage   : my $format = $treedrawer->get_format;
 Function: Gets the image format.
 Returns :
 Args    : None.

=cut

sub get_format { shift->{'FORMAT'} }

=item get_format_mime()

Gets image format as MIME type.

 Type    : Accessor
 Title   : get_format_mime
 Usage   : print "Content-type: ", $treedrawer->get_format_mime, "\n\n";
 Function: Gets the image format as MIME type.
 Returns :
 Args    : None.

=cut

sub get_format_mime {
	my $self = shift;
	my %mapping = (
		'canvas'     => 'text/html',
		'gif'        => 'image/gif',
		'jpeg'       => 'image/jpeg',
		'pdf'        => 'application/pdf',
		'png'        => 'image/png',
		'processing' => 'text/plain',
		'svg'        => 'image/svg+xml',
		'swf'        => 'application/x-shockwave-flash',
	);
	return $mapping{ lc $self->get_format };
}

=item get_width()

Gets image width.

 Type    : Accessor
 Title   : get_width
 Usage   : my $width = $treedrawer->get_width;
 Function: Gets the width of the drawer canvas.
 Returns :
 Args    : None.

=cut

sub get_width { shift->{'WIDTH'} }

=item get_height()

Gets image height.

 Type    : Accessor
 Title   : get_height
 Usage   : my $height = $treedrawer->get_height;
 Function: Gets the height of the canvas.
 Returns :
 Args    : None.

=cut

sub get_height { shift->{'HEIGHT'} }

=item get_mode()

Gets tree drawing mode.

 Type    : Accessor
 Title   : get_mode
 Usage   : my $mode = $treedrawer->get_mode('clado');
 Function: Gets the tree mode, i.e. cladogram or phylogram.
 Returns :
 Args    : None.

=cut

sub get_mode { shift->{'MODE'} }

=item get_shape()

Gets tree drawing shape.

 Type    : Accessor
 Title   : get_shape
 Usage   : my $shape = $treedrawer->get_shape;
 Function: Gets the tree shape, i.e. rectangular, 
           diagonal, curvy or radial.
 Returns :
 Args    : None.

=cut

sub get_shape { shift->{'SHAPE'} }

=item get_padding()

Gets image padding.

 Type    : Accessor
 Title   : get_padding
 Usage   : my $padding = $treedrawer->get_padding;
 Function: Gets the canvas padding.
 Returns :
 Args    : None.

=cut

sub get_padding { shift->{'PADDING'} }

=item get_text_horiz_offset()

Gets text horizontal offset.

 Type    : Accessor
 Title   : get_text_horiz_offset
 Usage   : my $text_horiz_offset = 
           $treedrawer->get_text_horiz_offset;
 Function: Gets the distance between 
           tips and text, in pixels.
 Returns : SCALAR
 Args    : None.

=cut

sub get_text_horiz_offset { shift->{'TEXT_HORIZ_OFFSET'} }

=item get_text_vert_offset()

Gets text vertical offset.

 Type    : Accessor
 Title   : get_text_vert_offset
 Usage   : my $text_vert_offset = 
           $treedrawer->get_text_vert_offset;
 Function: Gets the text baseline relative 
           to the tips, in pixels.
 Returns :
 Args    : None.

=cut

sub get_text_vert_offset { shift->{'TEXT_VERT_OFFSET'} }

=item get_text_width()

Gets text width.

 Type    : Accessor
 Title   : get_text_width
 Usage   : my $textwidth = 
           $treedrawer->get_text_width;
 Function: Returns the canvas width 
           for terminal taxon names.
 Returns :
 Args    : None.

=cut

sub get_text_width { shift->{'TEXT_WIDTH'} }

=item get_tree()

Gets tree to draw.

 Type    : Accessor
 Title   : get_tree
 Usage   : my $tree = $treedrawer->get_tree;
 Function: Returns the Bio::Phylo::Forest::Tree 
           object to unparse.
 Returns : A Bio::Phylo::Forest::Tree object.
 Args    : None.

=cut

sub get_tree { shift->{'TREE'} }

=item get_scale_options()

Gets time scale option.

 Type    : Accessor
 Title   : get_scale_options
 Usage   : my %options = %{ 
               $treedrawer->get_scale_options  
           };
 Function: Returns the time/distance 
           scale options.
 Returns : A hash ref.
 Args    : None.

=cut

sub get_scale_options { shift->{'SCALE'} }

=item get_pie_colors

Gets a hash reference whose keys are (unique) names for the different segments in a
likelihood pie chart, and whose values are color codes.

 Type    : Accessor
 Title   : get_pie_colors
 Usage   : my %h = %{ $treedrawer->get_pie_colors() };
 Function: gets likelihood pie colors
 Returns :
 Args    : None

=cut

sub get_pie_colors { shift->{'PIE_COLORS'} }

=item get_clade_label_width

Gets clade label width, i.e. the spacing between nested clade annotations

 Type    : Mutator
 Title   : get_clade_label_width
 Usage   : my $width = $treedrawer->get_clade_label_width();
 Function: gets the spacing between nested clade annotations
 Returns :
 Args    : None

=cut

sub get_clade_label_width { shift->{'CLADE_LABEL_WIDTH'} }

=back

=head2 CASCADING ACCESSORS

=over

=item get_branch_width()

Gets branch width.

 Type    : Accessor
 Title   : get_branch_width
 Usage   : my $w = $treedrawer->get_branch_width();
 Function: gets the width of branch lines
 Returns :
 Args    : Integer width in pixels.

=cut

sub get_branch_width {
    my $self = shift;
    return $self->_cascading_getter(@_);
}

=item get_collapsed_clade_width()

Gets collapsed clade width.

 Type    : Mutator
 Title   : get_collapsed_clade_width
 Usage   : $w = $treedrawer->get_collapsed_clade_width();
 Function: gets the width of collapsed clade triangles relative to uncollapsed tips
 Returns : Positive number
 Args    : None

=cut

sub get_collapsed_clade_width {
    my $self = shift;
    return $self->_cascading_getter(@_);
}

=item get_node_radius()

Gets node radius.

 Type    : Accessor
 Title   : get_node_radius
 Usage   : my $node_radius = $treedrawer->get_node_radius;
 Function: Gets the node radius in pixels.
 Returns : SCALAR
 Args    : None.

=cut

sub get_node_radius {
    my $self = shift;
    return $self->_cascading_getter(@_);
}

=item get_tip_radius()

Gets tip radius.

 Type    : Accessor
 Title   : get_tip_radius
 Usage   : my $tip_radius = $treedrawer->get_tip_radius;
 Function: Gets the tip radius in pixels.
 Returns : SCALAR
 Args    : None.

=cut

sub get_tip_radius {
    my $self = shift;
    return $self->_cascading_getter(@_);
}

=begin comment

 Type    : Internal method.
 Title   : _set_scalex
 Usage   : $treedrawer->_set_scalex($scalex);
 Function:
 Returns :
 Args    :

=end comment

=cut

sub _set_scalex {
    my $self = shift;
    if ( looks_like_number $_[0] ) {
        $self->{'_SCALEX'} = $_[0];
    }
    else {
        throw 'BadNumber' => "\"$_[0]\" is not a valid number value";
    }
    return $self;
}
sub _get_scalex { shift->{'_SCALEX'} }

=begin comment

 Type    : Internal method.
 Title   : _set_scaley
 Usage   : $treedrawer->_set_scaley($scaley);
 Function:
 Returns :
 Args    :

=end comment

=cut

sub _set_scaley {
    my $self = shift;
    if ( looks_like_number $_[0] ) {
        $self->{'_SCALEY'} = $_[0];
    }
    else {
        throw 'BadNumber' => "\"$_[0]\" is not a valid integer value";
    }
    return $self;
}
sub _get_scaley { shift->{'_SCALEY'} }

=back

=head2 TREE DRAWING

=over

=item draw()

Creates tree drawing.

 Type    : Unparsers
 Title   : draw
 Usage   : my $drawing = $treedrawer->draw;
 Function: Unparses a Bio::Phylo::Forest::Tree 
           object into a drawing.
 Returns : SCALAR
 Args    :

=cut

sub draw {
    my $self = shift;
    if ( !$self->get_tree ) {
        throw 'BadArgs' => "Can't draw an undefined tree";
    }
    my $root = $self->get_tree->get_root;

    # Reset the stored data in the tree
    $self->_reset_internal($root);
    $logger->debug("going to compute coordinates");
    $self->compute_coordinates;
	$logger->debug("going to render figure");
    return $self->render;
}

sub compute_coordinates {
    my $self = shift;
    if ( $self->get_shape =~ m/(?:radial|unrooted)/i ) {
        $self->_compute_unrooted_coordinates;
    }
    else {
        $self->_compute_rooted_coordinates;
    }
    return $self;
}

sub polar_to_cartesian {
    my ( $self, $radius, $angleInDegrees ) = @_;
    my $angleInRadians = $angleInDegrees * $PI / 180.0;
    my $x = $radius * cos($angleInRadians);
    my $y = $radius * sin($angleInRadians);
    return $x, $y;
}

sub cartesian_to_polar {
    my ( $self, $x, $y ) = @_;
    my $angleInDegrees = atan2( $y, $x ) / $PI * 180;
    my $radius = sqrt( $y ** 2 + $x ** 2 );
    return $radius, $angleInDegrees;
}

sub _compute_unrooted_coordinates {
    my $self = shift;
    my $tre  = $self->get_tree;
    my $phy  = $self->get_mode =~ /^p/i ? $tre->is_cladogram ? 0 : 1 : 0; # phylogram?
    
    # compute unscaled rotation, depth and tip count
    my ( %unscaled_rotation, %depth );
    my ( $total_tips, $total_depth ) = ( 0, 0 );
    
    $tre->visit_depth_first(
        # process tips first
        '-no_daughter' => sub {
            my $node = shift;
            my $id = $node->get_id;
            ( $unscaled_rotation{$id}, $depth{$id} ) = ( $total_tips, 0 );
            $total_tips++;
        },
        
        # then process internals
        '-post_daughter' => sub {
            my $node = shift;
            my $id   = $node->get_id;
            
            # get deepest child and average rotation
            my @child = @{ $node->get_children };
            my ( $unscaled_rotation, $depth ) = ( 0, 0 );
            for my $c ( @child ) {
                my $cid = $c->get_id;
                my $c_depth = $depth{$cid};
                $unscaled_rotation += $unscaled_rotation{$cid};
                $depth = $c_depth if $c_depth > $depth;
            }
            
            # increment depth
            if ( $phy ) {
                my @mapped    = map { $_->get_branch_length } @child;
                my ($tallest) = sort { $b <=> $a } @mapped;
                $depth += $tallest;
            }
            else {
                $depth++;
            }
            
            # update rotation
            $unscaled_rotation /= scalar(@child);
            
            # check to see if current depth is overal deepest
            $total_depth = $depth if $depth > $total_depth;
            
            # store results
            ( $unscaled_rotation{$id}, $depth{$id} ) =
            ( $unscaled_rotation,      $depth );
        },        
    );

    # root, exactly centered on the canvas
    my $center_x = $self->get_width / 2;
    my $center_y = $self->get_height / 2;
    
    my $horiz_offset = $self->get_text_horiz_offset;
    my $text_width   = $self->get_text_width;
    my $padding      = $self->get_padding;
    my $range = $center_x - ( $horiz_offset + $text_width + $padding );
    
    # cladogram branch length
    $self->_set_scalex( $range / $total_depth );
    $self->_set_scaley( $range / $total_depth );
    
    for my $n ( @{ $tre->get_entities } ) {
        if ( $n->is_root ) {
            $n->set_x( $center_x );
            $n->set_y( $center_y );
        }
        else {
            my $id = $n->get_id;
            my ( $unscaled_rotation, $depth ) = ( $unscaled_rotation{$id}, $depth{$id} );
            my $radius    = $self->_get_scalex * ( $depth - $total_depth ) * -1;
            my $rotation  = $unscaled_rotation / $total_tips * 360;
            my ( $x, $y ) = $self->polar_to_cartesian( $radius, $rotation );
            $n->set_x( $x + $center_x );
            $n->set_y( $y + $center_y );
            $n->set_rotation( $rotation );
            $n->set_generic( 'radius' => $radius );
        }
    }    
}

sub _compute_rooted_coordinates {
    my $td      = shift;
    my $tree    = $td->get_tree;
    my $phylo   = $td->get_mode =~ /^p/i ? 1 : 0;    # phylogram or cladogram
    my $padding = $td->get_padding;
    my $width   = $td->get_width - ( $td->get_text_width + ( $padding * 2 ) );
    my $height  = $td->get_height - ( $padding * 2 );
    my $cladew  = $td->get_collapsed_clade_width;
    my ( $tip_counter, $tallest_tip ) = ( 0, 0 );
    $tree->visit_depth_first(
        
        # preprocess each node
        '-pre' => sub {
            my $node = shift;
            if ( my $parent = $node->get_parent ) {
                my $parent_x = $parent->get_x || 0;
                my $x = $phylo ? $node->get_branch_length || 0 : 1;
                $node->set_x( $x + $parent_x );
            }
            else {
                $node->set_x(0);    # root
            }
        },
        
        # process this only on tips
        '-no_daughter' => sub {
            my $node = shift;            
            $node->set_y( $tip_counter++ );
            my $x = $node->get_x;
            $tallest_tip = $x if $x > $tallest_tip;
        },
        
        # process this only on internal nodes
        '-post_daughter' => sub {
            my $node = shift;
            my ( $child_count, $child_y ) = ( 0, 0 );
            for my $child ( @{ $node->get_children } ) {
                $child_count++;
                $child_y += $child->get_y;
            }
            $node->set_y( $child_y / $child_count );
        },
    );
    $tree->visit(
        sub {
            my $node = shift;
            if ( not $tallest_tip ) {
                throw 'BadArgs' => "This tree has no branch lengths, can't draw a phylogram";
            }            
            $node->set_x( $padding + $node->get_x * ( $width / $tallest_tip ) );
            $node->set_y( $padding + $node->get_y * ( $height / $tip_counter ) );
            if ( !$phylo && $node->is_terminal ) {
                $node->set_x( $padding + $tallest_tip * ( $width / $tallest_tip ) );
            }
        }
    );
    $td->_set_scaley( $height / $tip_counter );
    $td->_set_scalex( $width / $tallest_tip );
}

=item render()

Renders tree based on pre-computed node coordinates. You would typically use
this method if you have passed a Bio::Phylo::Forest::DrawTree on which you
have already calculated the node coordinates separately.

 Type    : Unparsers
 Title   : render
 Usage   : my $drawing = $treedrawer->render;
 Function: Unparses a Bio::Phylo::Forest::DrawTree 
           object into a drawing.
 Returns : SCALAR
 Args    :

=cut

sub render {
    my $self = shift;
    my $library =
      looks_like_class __PACKAGE__ . '::' . ucfirst( lc( $self->get_format ) );
    my $drawer = $library->_new(
        '-tree'   => $self->get_tree,
        '-drawer' => $self
    );
    return $drawer->_draw;
}

=begin comment

 Type    : Internal method.
 Title   : _reset_internal
 Usage   : $treedrawer->_reset_internal;
 Function: resets the set_generic values stored by Treedrawer, this must be 
           called at the start of each draw command or weird results are obtained!
 Returns : nothing
 Args    : treedrawer, node being processed

=end comment

=cut

sub _reset_internal {
    my ( $self, $node ) = @_;
    my $tree = $self->get_tree;
    $node->set_x(undef);
    $node->set_y(undef);
    my $children = $node->get_children;
    for my $child (@$children) {
        _reset_internal( $self, $child );
    }
}

=back

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo>

The L<Bio::Phylo::Treedrawer> object inherits from the L<Bio::Phylo> object.
Look there for more methods applicable to the treedrawer object.

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

1;
