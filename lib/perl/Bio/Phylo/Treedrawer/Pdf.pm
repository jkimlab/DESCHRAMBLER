package Bio::Phylo::Treedrawer::Pdf;
use strict;
use warnings;
use base 'Bio::Phylo::Treedrawer::Abstract';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw'looks_like_hash _PI_';
use Bio::Phylo::Util::Dependency qw'PDF::API2::Lite PDF::API2::Annotation';
use Bio::Phylo::Util::Logger;
my $logger = Bio::Phylo::Util::Logger->new;
my $PI     = _PI_;
my %colors;

=head1 NAME

Bio::Phylo::Treedrawer::Pdf - Graphics format writer used by treedrawer, no
serviceable parts inside

=head1 DESCRIPTION

This module creates a pdf file from a Bio::Phylo::Forest::DrawTree
object. It is called by the L<Bio::Phylo::Treedrawer> object, so look there to
learn how to create tree drawings.


=begin comment

 Type    : Constructor
 Title   : _new
 Usage   : my $pdf = Bio::Phylo::Treedrawer::Pdf->_new(%args);
 Function: Initializes a Bio::Phylo::Treedrawer::Pdf object.
 Alias   :
 Returns : A Bio::Phylo::Treedrawer::Pdf object.
 Args    : none.

=end comment

=cut

sub _new {
    my $class = shift;
    my %opt   = looks_like_hash @_;
    my $pdf   = PDF::API2::Lite->new;
    my $self  = $class->SUPER::_new( %opt, '-api' => $pdf );
    my $d     = $self->_drawer;
    my $page  = $self->_api->page( $d->get_width, $d->get_height );
    return bless $self, $class;
}

=begin comment

# finish drawing

=end comment

=cut

sub _finish {
    $logger->debug("finishing drawing");
    my $self = shift;
    require File::Temp;
    my ( $fh, $filename ) = File::Temp::tempfile();
    $self->_api->saveas($filename);
    my $result = do { local $/; <$fh> };
    unlink $filename;
    return $result;
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
    my @keys = qw(-x1 -y1 -x2 -y2 -width -color);
    my ( $x1, $y1, $x3, $y3, $linewidth, $color ) = @args{@keys};
    my $height = $self->_drawer->get_height;
    my ( $x2, $y2 ) = ( $x1, $y3 );
    return $self->_api->linewidth( $linewidth || 1 )
      ->strokecolor( $color ? "#$color" : "#000000" )
      ->move( $x1, $height - $y1 )
      ->curve( $x1, $height - $y1, $x2, $height - $y2, $x3, $height - $y3 )
      ->stroke();
}

=begin comment

# -x1 => $x1,
# -x2 => $x2,
# -y1 => $y1,
# -y2 => $y2,
# -radius => $radius
# -width => $width,
# -color => $color

=end comment

=cut

sub _draw_arc {    
    my $self = shift;
    my $drawer = $self->_drawer;
    my %args = @_;
    my @keys = qw(-x1 -y1 -x2 -y2 -radius -width -color);
    my ( $x1, $y1, $x2, $y2, $radius, $linewidth, $color ) = @args{@keys};    
    
    # calculate center
    my $height = $drawer->get_height;
    my $width  = $drawer->get_width;
    my $cx = $width / 2;
    my $cy = $height / 2;
    
    # compute start and end
    my ( $r1, $start ) = $drawer->cartesian_to_polar( $x1 - $cx, $y1 - $cy );
    my ( $r2, $end )   = $drawer->cartesian_to_polar( $x2 - $cx, $y2 - $cy );
    $start += 360 if $start < 0;
    $end   += 360 if $end < 0;
    
    # rotations in PDF are counter-clockwise, so need to be "inverted"
    $start = ( $start - 360 ) * - 1;
    $start -= 360 if $start > 360;
    
    $end = ( $end - 360 ) * - 1;
    $end -= 360 if $end > 360;        
    
    $logger->debug("drawing arc cx:$cx cy:$cy radius:$radius start:$start end:$end");
    
    if ( $start != $end ) {
        return $self->_api->linewidth( $linewidth || 1 )
          ->strokecolor( $color ? "#$color" : "#000000" )
          ->move( $x1, $cy + ( $cy - $y1 ) )
          ->arc( $cx, $cy, $radius, $radius, $start, $end )
          ->stroke();
    }
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
        $logger->warn( ref($self) . " can't embed links, yet" );
    }
    my $height = $self->_drawer->get_height;
    my $pdf = $api || $self->_api;
    return $pdf->move( $x1, $height - $y1 )->linewidth( $width || 1 )
      ->strokecolor( $stroke ? "#$stroke" : "#000000" )
      ->fillcolor( $fill     ? "#$fill"   : "white" )->poly(
        $x1, $height - $y1, $x2, $height - $y2,
        $x3, $height - $y3, $x1, $height - $y1,
      )->fillstroke();
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
    my @keys = qw(-x1 -y1 -x2 -y2 -width -color);
    my ( $x1, $y1, $x2, $y2, $width, $color ) = @args{@keys};
    my $height = $self->_drawer->get_height;
    return $self->_api->linewidth( $width || 1 )
      ->strokecolor( $color ? "#$color" : "#000000" )
      ->move( $x1, $height - $y1 )
      ->poly( $x1, $height - $y1, $x2, $height - $y2 )->stroke();
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
    $logger->debug("drawing rectangular branch");
    my $self = shift;
    my %args = @_;
    my @keys = qw(-x1 -y1 -x2 -y2 -width -color);
    my ( $x1, $y1, $x3, $y3, $width, $color ) = @args{@keys};
    my ( $x2, $y2 ) = ( $x1, $y3 );
    my $height = $self->_drawer->get_height;
    return $self->_api->linewidth( $width || 1 )
      ->strokecolor( $color ? "#$color" : "#000000" )
      ->move( $x1, $height - $y1 )
      ->poly( $x1, $height - $y1, $x2, $height - $y2, $x3, $height - $y3 )
      ->stroke();
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
    my $self = shift;
    if ( not $self->{'FONT'} ) {
        $self->{'FONT'} = $self->_api->corefont('Times-Roman');
    }
    my %args = @_;
    my ( $x, $y, $text, $url, $size, $rotation ) = @args{qw(-x -y -text -url -size -rotation)};
    if ($url) {
        $logger->warn( ref($self) . " can't embed links, yet" );
    }
    my $height = $self->_drawer->get_height;
    
    # rotations in PDF are counter-clockwise, so need to be "inverted"
    my $angle = ( $rotation->[0] - 360 ) * - 1;
    $angle -= 360 if $angle > 360;;
    
    $logger->debug("drawing text $text - $angle");
    
    return $self->_api->fillcolor("#000000")
      ->print( $self->{'FONT'}, $size || 12, $rotation->[1], $height - $rotation->[2], $angle, 0, $text, );
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
    my $height = $self->_drawer->get_height;
    my $pdf = $api || $self->_api;
    my $circle =
      $pdf->circle( $x, $height - $y, $radius )->linewidth( $width || 1 )
      ->strokecolor( $stroke ? "#$stroke" : "#000000" )
      ->fillcolor( $fill     ? "#$fill"   : "white" )->fillstroke();

    if ($url) {
        $logger->warn( ref($self) . " can't embed links, yet" );

        #my $ann = PDF::API2::Annotation->new;
        #$ann->url(
        #    $url,
        #    '-rect' => [
        #        $x - $radius,
        #        ( $height - $y ) - $radius,
        #        $x + $radius,
        #        ( $height - $y ) + $radius,
        #    ]
        #);
    }
    return $circle;
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