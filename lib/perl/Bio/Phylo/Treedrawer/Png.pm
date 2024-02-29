package Bio::Phylo::Treedrawer::Png;
use strict;
use warnings;
use base 'Bio::Phylo::Treedrawer::Abstract';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw'looks_like_hash _PI_';
use Bio::Phylo::Util::Dependency qw'GD::Simple GD::Polyline GD::Polygon GD';
use Bio::Phylo::Util::Logger;

my $logger   = Bio::Phylo::Util::Logger->new;
my $PI       = _PI_;
my $AA       = 3;
my $whiteHex = 'FFFFFF';
my $blackHex = '000000';
my %colors;

=begin comment

This module does all the heavy lifting for PNG, GIF and JPEG bitmap images. It
achieves anti-aliasing by first multiplying all coordinates, radii and line-
widths with a constant (default is $AA), then in the last-before-final step
the entire bitmap is downsampled, during which GD averages adjacent pixels,
which has the effect of anti-aliasing. This approach is taken because GD
doesn't seem to recognize line-widths if anti-aliasing has been turned on.
Because TrueType fonts are already anti-aliased we record where text needs to
end up after downsampling, and then in the last step we add the text into the
downsampled image.

=end comment

=head1 NAME

Bio::Phylo::Treedrawer::Png - Graphics format writer used by treedrawer, no
serviceable parts inside

=head1 DESCRIPTION

This module creates a png file from a Bio::Phylo::Forest::DrawTree
object. It is called by the L<Bio::Phylo::Treedrawer> object, so look there to
learn how to create tree drawings.


=begin comment

Translates a six-letter HEX code to rgb, i.e. three numbers between 0 and 255

=end comment

=cut

sub _hex2rgb ($) {
    my $hex = shift;
    my ( $r, $g, $b ) = ( 0, 0, 0 );
    if ( $hex =~ m/^(..)(..)(..)$/ ) {
        $r = hex($1);
        $g = hex($2);
        $b = hex($3);
    }
    return $r, $g, $b;
}

=begin comment

Allocates colors in the index, uses caching

=end comment

=cut

sub _make_color {
    my ( $self, $hex ) = @_;
    $hex = uc $hex;
    if ( exists $colors{$hex} ) {
        return $colors{$hex};
    }
    if ( not $hex ) {
        if ( not $colors{$blackHex} ) {
            $colors{$blackHex} = $self->_api->colorAllocate( _hex2rgb $blackHex );
        }
        return $colors{$blackHex};
    }
    my $colorObj = $self->_api->colorAllocate( _hex2rgb $hex );
    $colors{$hex} = $colorObj;
    return $colorObj;
}

# returns multiplication factor for anti-aliasing

sub _aa { shift->{'AA'} || $AA }

# multiplies all arguments by the anti-aliasing upsampling factor

sub _upsample {
    my ( $self, @value ) = @_;
    my $aa = $self->_aa;
    my @result;
    push @result, $_ * $aa for @value;
    return @result;
}

=begin comment

 Type    : Constructor
 Title   : _new
 Usage   : my $png = Bio::Phylo::Treedrawer::Png->_new(%args);
 Function: Initializes a Bio::Phylo::Treedrawer::Png object.
 Alias   :
 Returns : A Bio::Phylo::Treedrawer::Png object.
 Args    : none.

=end comment

=cut

sub _new {
    my $class = shift;
    my %opt   = looks_like_hash @_;
    
    # instantiate object
    my $aa = $opt{'-aa'} || $AA;
    my $td = $opt{'-drawer'};
    delete $opt{'-aa'};
    my $self = $class->SUPER::_new( %opt );
    $self->{'AA'}  = $aa;
    $self->{'TXT'} = [];
    $self->{'API'} = GD::Image->new(
        $self->_upsample( $td->get_width, $td->get_height ),
        1,
    );
    
    # set background color
    $self->_api->fill( 0,0, $self->_make_color( $whiteHex ) );
    
    return $self;    
}

=begin comment

Downsamples the bitmap that has been created so far, in order to achieve an
anti-aliasing effect. Then adds the text strings in the correct coordinates
for the downsampled image.

=end comment

=cut

sub _downsample {
    $logger->debug("downsampling");
    my $self = shift;
    my ( $w, $h ) = ( $self->_drawer->get_width, $self->_drawer->get_height );
    my $aa = $self->_aa;
    my $result = GD::Image->new( $w, $h, 1 );
    $result->copyResampled( $self->_api, 0, 0, 0, 0, $w, $h, $w * $aa, $h * $aa);
    for my $txtargs ( @{ $self->{'TXT'} } ) {
        $result->stringFT( @{ $txtargs } );
    }   
    return $result;
}

=begin comment

# finish drawing, export PNG

=end comment

=cut

sub _finish {
    return shift->_downsample->png;
}

=begin comment

# -x1 => $x1,
# -x2 => $x2,
# -y1 => $y1,
# -y2 => $y2,
# -width => $width,
# -color => $color

=end comment

=cut

sub _draw_curve {
    $logger->debug("drawing curved branch");
    my $self = shift;
    my %args = @_;
    my @keys = qw(-x1 -y1 -x2 -y2 -width -color -api);
    my ( $x1, $y1, $x3, $y3, $linewidth, $color, $api ) = @args{@keys};
    
    # create upsampled coordinates
    ($x1,$y1,$x3,$y3,$linewidth) = $self->_upsample($x1,$y1,$x3,$y3,$linewidth); 
    my ( $x2, $y2 ) = ( $x1, $y3 );
    
    my $img  = $api || $self->_api;
    $img->setThickness( $linewidth || $self->_aa );
    
    # set control points
    my $poly = GD::Polyline->new();
    $poly->addPt( $x1, $y1 );
    $poly->addPt( $x1, ( $y1 + $y3 + $y3 ) / 3 );
    $poly->addPt( ( $x1 + $x1 + $x3 ) / 3, $y3 );
    $poly->addPt( $x3, $y3 );
    
    $img->polydraw( $poly->toSpline(), $self->_make_color( $color ) );
}

=begin comment

# -x1 => $x1,
# -x2 => $x2,
# -y1 => $y1,
# -y2 => $y2,
# -width => $width,
# -color => $color

=end comment

=cut

sub _draw_arc {    
    $logger->debug("drawing arc");
    my $self = shift;
    
    # process arguments
    my %args = @_;
    my @keys = qw(-x1 -y1 -x2 -y2 -radius -width -color -api);
    my ($x1,$y1,$x2,$y2,$radius,$linewidth,$linecolor,$api) = @args{@keys};
    ($x1,$y1,$x2,$y2,$radius,$linewidth) = $self->_upsample($x1,$y1,$x2,$y2,$radius,$linewidth);

    # get center of arc
    my $drawer = $self->_drawer;
    my $cx = $drawer->get_width  * $self->_aa / 2;
    my $cy = $drawer->get_height * $self->_aa / 2;
    
    # get width and height (are equal for arcs)
    my ( $width, $height );
    $width = $height = $radius * 2;
    
    # change line thickness
    my $img = $api || $self->_api;
    $img->setThickness( $linewidth || $self->_aa );
    
    # compute start and end
    my ( $r1, $start ) = $drawer->cartesian_to_polar( $x1 - $cx, $y1 - $cy );
    my ( $r2, $end )   = $drawer->cartesian_to_polar( $x2 - $cx, $y2 - $cy );
    $start += 360 if $start < 0;
    $end   += 360 if $end < 0;
    
    # draw
    $img->arc($cx,$cy,$width,$height,$start,$end,$self->_make_color($linecolor));
}

=begin comment

# required:
# -x1 => $x1,
# -y1 => $y1,
# -x2 => $x2,
# -y2 => $y2,
# -x3 => $x3,
# -y3 => $y3,

# optional:
# -fill   => $fill,
# -stroke => $stroke,
# -width  => $width,
# -url    => $url,
# -api    => $api,

=end comment

=cut

sub _draw_triangle {
    my $self = shift;
    $logger->debug("drawing triangle @_");
    my %args = @_;
    my @keys = qw(-x1 -y1 -x2 -y2 -x3 -y3 -fill -stroke -width -url -api);
    my ( $x1, $y1, $x2, $y2, $x3, $y3, $fill, $stroke, $width, $url, $api ) =
      @args{@keys};
    if ($url) {
        $logger->warn( ref($self) . " can't embed links" );
    }
    my $img = $api || $self->_api;

    # create polygon
    my $poly = GD::Polygon->new();
    $poly->addPt( $x1, $y1 );
    $poly->addPt( $x2, $y2 );
    $poly->addPt( $x3, $y3 );
    $poly->addPt( $x1, $y1 );

    # set line thickness
    $img->setThickness( $width || 1 );

    # create antialiased stroke color
    my $strokeColorObj = $self->_make_color( $stroke || $blackHex );
    $img->setAntiAliased($strokeColorObj);

    # create fill color
    my $fillColorObj = $self->_make_color( $fill || $whiteHex );

    # draw polygon
    $img->polydraw( $poly, GD::gdAntiAliased );

    # fill polygon
    $img->fill(
        ( ( $x1 + $x2 + $x3 ) / 3 ),
        ( ( $y1 + $y2 + $y3 ) / 3 ),
        $fillColorObj
    );
}

=begin comment

 Type    : Internal method.
 Title   : _draw_pies
 Usage   : $svg->_draw_pies();
 Function: Draws likelihood pies
 Returns :
 Args    : None.
 Comments:

=end comment

=cut

sub _draw_pies {
    my $self = shift;
    my %piecolors;
    $self->_tree->visit_level_order(
        sub {
            my $node = shift;
            if ( not $node->get_collapsed and my $values = $node->get_generic('pie') ) {
                
                # get center coordinates and radius
                my ( $cx, $cy ) = ( $node->get_x, $node->get_y );
                my $method = sprintf 'get_%s_radius', $node->is_internal ? 'node' : 'tip';
                my $r = $self->_drawer->$method($node);
                ( $cx, $cy, $r ) = $self->_upsample( $cx, $cy, $r );
                
                # calculate sum of all pie values
                my @keys  = keys %{$values};                
                my $total;
                $total += $values->{$_} for @keys;
                
                my $start = 0;
                for my $i ( 0 .. $#keys ) {
                    my $key = $keys[$i];
                    next if not $values->{$key};                                        
                                        
                    # allocate pie chunk color
                    if ( not defined $piecolors{$key} ) {
                        my $fraction = int($i / $#keys * 255);                        
                        my $hex = uc(sprintf("%.2x",$fraction)) x 3;
                        $logger->debug("$fraction = $hex");
                        $piecolors{$key} = $self->_make_color($hex);
                    }
                    
                    # calculate slice angle
                    my $slice = $values->{$key} / $total * 360;
                    $self->_api->filledArc( $cx, $cy, $r, $r, $start, $slice + $start, $piecolors{$key} );
                    $start += $slice;
                }
                
                # final circle around node
                $self->_api->arc( $cx, $cy, $r, $r, 0, 360, $self->_make_color($blackHex) );
            }
        }
    );
}

=begin comment

# -x1 => $x1,
# -x2 => $x2,
# -y1 => $y1,
# -y2 => $y2,
# -width => $width,
# -color => $color

=end comment

=cut

sub _draw_line {
    $logger->debug("drawing line");
    my $self = shift;
    my %args = @_;
    my @keys = qw(-x1 -y1 -x2 -y2 -width -color -api);
    my ( $x1, $y1, $x2, $y2, $width, $color, $api ) = @args{@keys};
    ( $x1, $y1, $x2, $y2, $width ) = $self->_upsample( $x1, $y1, $x2, $y2, $width );
    my $img = $api || $self->_api;
    $img->setThickness( $width || $self->_aa );
    $img->line( $x1, $y1, $x2, $y2, $self->_make_color( $color ) );
}

=begin comment

# -x1 => $x1,
# -x2 => $x2,
# -y1 => $y1,
# -y2 => $y2,
# -width => $width,
# -color => $color

=end comment

=cut

sub _draw_multi {
    $logger->debug("drawing multi line");
    my $self = shift;
    my %args = @_;
    my @keys = qw(-x1 -y1 -x2 -y2 -width -color -api);
    my ( $x1, $y1, $x3, $y3, $linewidth, $color, $api ) = @args{@keys};
    ($x1,$y1,$x3,$y3,$linewidth) = $self->_upsample($x1,$y1,$x3,$y3,$linewidth);
    my ( $x2, $y2 ) = ( $x1, $y3 );    
    my $img = $api || $self->_api;    
    my $poly = GD::Polyline->new();
    $poly->addPt( $x1, $y1 );
    $poly->addPt( $x2, $y2 );
    $poly->addPt( $x3, $y3 );
    $img->setThickness( $linewidth || $self->_aa );
    $img->polydraw( $poly, $self->_make_color( $color ) );
}

=begin comment

# required:
# -x => $x,
# -y => $y,
# -text => $text,
#
# optional:
# -url  => $url,

=end comment

=cut

sub _draw_text {
    $logger->debug("drawing text");
    my $self = shift;
    my %args = @_;
    my @keys = qw(-x -y -text -url -size -api -rotation);
    my ( $x, $y, $text, $url, $size, $api, $rotation ) = @args{@keys};
    if ($url) {
        $logger->warn( ref($self) . " can't embed links" );
    }
    
    # to place the text, we need to calculate where the vertical and horizontal
    # offsets end up given the rotation. We compute these offsets by taking the
    # difference between the provided $x,$y coordinates (which include the
    # offsets) and those in $rotation->[1],$rotation->[2], which normally is
    # the location of the terminal node next to which the text is placed and
    # around which it is rotated.
    my $radius_x = $x - $rotation->[1];
    my $radius_y = $y - $rotation->[2];
    
    # for the vertical offset we need to add 90 degrees
    my $rotation1 = $rotation->[0] + 90;
    $rotation1 -= 360 if $rotation1 > 360;
    my ( $x1, $y1 ) = $self->_drawer->polar_to_cartesian( $radius_x, $rotation->[0] );
    my ( $x2, $y2 ) = $self->_drawer->polar_to_cartesian( $radius_y, $rotation1 );
    
    # rotations in GD are counter-clockwise, so need to be "inverted"
    my $gdrotation = ( $rotation->[0] - 360 ) * - 1;
    $gdrotation -= 360 if $gdrotation > 360;
    
    push @{ $self->{'TXT'} }, [
        $self->_make_color($blackHex),
        '/System/Library/Fonts/Thonburi.ttf',
        $size || 12,
        $gdrotation / 180 * _PI_,
        $rotation->[1] + $x1 + $x2,
        $rotation->[2] + $y1 + $y2,
        $text        
    ];
}

=begin comment

# -x => $x,
# -y => $y,
# -width  => $width,
# -stroke => $color,
# -radius => $radius,
# -fill   => $file,
# -api    => $api,
# -url    => $url,

=end comment

=cut

sub _draw_circle {
    $logger->debug("drawing circle");
    my $self = shift;
    my %args = @_;
    my @keys = qw(-x -y -width -stroke -radius -fill -api -url);
    my ( $x, $y, $width, $stroke, $radius, $fill, $api, $url ) = @args{@keys};
    if ($url) {
        $logger->warn( ref($self) . " can't embed links" );
    }
    ( $x, $y, $width, $radius ) = $self->_upsample( $x, $y, $width, $radius );
    my @args = ( $x, $y, $radius, $radius );
    my $img = $api || $self->_api;
    if ( defined $fill ) {
        $img->filledEllipse( @args, $self->_make_color($fill || $whiteHex) );
    }
    $img->ellipse( @args, $self->_make_color($stroke) );
}

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::Treedrawer>

The pdf treedrawer is called by the L<Bio::Phylo::Treedrawer> object. Look there
to learn how to create tree drawings.

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
