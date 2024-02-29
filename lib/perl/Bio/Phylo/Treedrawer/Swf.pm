package Bio::Phylo::Treedrawer::Swf;
use strict;
use warnings;
use base 'Bio::Phylo::Treedrawer::Abstract';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw'looks_like_hash _PI_';
use Bio::Phylo::Util::Dependency 'SWF::Builder';
use Bio::Phylo::Util::Logger;

our $FONT  = __PACKAGE__->_font_path;
my $logger = Bio::Phylo::Util::Logger->new;
my $PI     = _PI_;
my %colors;

=head1 NAME

Bio::Phylo::Treedrawer::Swf - Graphics format writer used by treedrawer, no
serviceable parts inside

=head1 DESCRIPTION

This module creates a flash movie from a Bio::Phylo::Forest::DrawTree
object. It is called by the L<Bio::Phylo::Treedrawer> object, so look there to
learn how to create tree drawings.


=begin comment

 Type    : Constructor
 Title   : _new
 Usage   : my $swf = Bio::Phylo::Treedrawer::Swf->_new(%args);
 Function: Initializes a Bio::Phylo::Treedrawer::Swf object.
 Alias   :
 Returns : A Bio::Phylo::Treedrawer::Swf object.
 Args    : none.

=end comment

=cut

sub _new {
    my $class = shift;
    my %opt   = looks_like_hash @_;
    my $self  = $class->SUPER::_new(
        %opt,
        '-api' => SWF::Builder->new(
            'FrameRate' => 15,
            'FrameSize' =>
              [ 0, 0, $opt{'-drawer'}->get_width, $opt{'-drawer'}->get_height ],
            'BackgroundColor' => 'ffffff'
        )
    );
    return bless $self, $class;
}

sub _finish {
    $logger->debug("finishing drawing");
    my $self = shift;
    require File::Temp;
    my ( $fh, $filename ) = File::Temp::tempfile();
    $self->_api->save($filename);
    my $result = do { local $/; <$fh> };
    unlink $filename;
    return $result;
}

# -x1 => $x1,
# -x2 => $x2,
# -y1 => $y1,
# -y2 => $y2,
# -width => $width,
# -color => $color
sub _draw_curve {
    $logger->debug("drawing curved branch");
    my $self = shift;
    my %args = @_;
    my @keys = qw(-x1 -y1 -x2 -y2 -width -color);
    my ( $x1, $y1, $x3, $y3, $width, $color ) = @args{@keys};
    my ( $x2, $y2 ) = ( $x1, $y3 );
    return $self->_api->new_shape->linestyle( $width || 1, $color || '000000' )
      ->moveto( $x1, $y1 )->curveto( $x1, $y1, $x1, $y1, $x2, $y2, $x3, $y3 )
      ->place;
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
    $logger->debug("darwing arc");
    my $self = shift;
    my %args = @_;
    my @keys = qw(-x1 -y1 -x2 -y2 -radius -width -color);
    my ($x1, $y1, $x2, $y2, $radius, $width, $color) = @args{@keys};
    
    # get center of arc
    my $drawer = $self->_drawer;
    my $cx = $drawer->get_width  / 2;
    my $cy = $drawer->get_height / 2;
    
    # compute start and end
    my ( $r1, $start ) = $drawer->cartesian_to_polar( $x1 - $cx, $y1 - $cy );
    my ( $r2, $end )   = $drawer->cartesian_to_polar( $x2 - $cx, $y2 - $cy );
    $start += 360 if $start < 0;
    $end   += 360 if $end < 0;
    $end -= $start;    
    
    my $shape = $self->_api->new_shape->linestyle( $width || 1, $color || '000000' );
    $shape->moveto( $x1, $y1 );
    $shape->arcto( $start, $end, $r1, $r2 );      
    $shape->place;    
}

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
sub _draw_triangle {
    my $self = shift;
    $logger->debug("drawing triangle @_");
    my %args = @_;
    my @keys = qw(-x1 -y1 -x2 -y2 -x3 -y3 -fill -stroke -width -url -api);
    my ( $x1, $y1, $x2, $y2, $x3, $y3, $fill, $stroke, $width, $url, $api ) =
      @args{@keys};
    return $self->_api->new_shape    # red triangle.
      ->fillstyle( $fill || 'ffffff' )
      ->linestyle( $width || 1, $stroke || '000000' )
      ->moveto( int $x1, int $y1 )->lineto( int $x2, int $y2 )
      ->lineto( int $x3, int $y3 )->lineto( int $x1, int $y1 )->place;
}

# -x1 => $x1,
# -x2 => $x2,
# -y1 => $y1,
# -y2 => $y2,
# -width => $width,
# -color => $color
sub _draw_line {
    $logger->debug("drawing line");
    my $self = shift;
    my %args = @_;
    my @keys = qw(-x1 -y1 -x2 -y2 -width -color);
    my ( $x1, $y1, $x2, $y2, $width, $color ) = @args{@keys};
    return $self->_api->new_shape->linestyle( $width || 1, $color || '000000' )
      ->moveto( $x1, $y1 )->lineto( $x1, $y1, $x2, $y2 )->place;
}

# -x1 => $x1,
# -x2 => $x2,
# -y1 => $y1,
# -y2 => $y2,
# -width => $width,
# -color => $color
sub _draw_multi {
    $logger->debug("drawing rectangular branch");
    my $self = shift;
    my %args = @_;
    my @keys = qw(-x1 -y1 -x2 -y2 -width -color);
    my ( $x1, $y1, $x3, $y3, $width, $color ) = @args{@keys};
    my ( $x2, $y2 ) = ( $x1, $y3 );
    return $self->_api->new_shape->linestyle( $width || 1, $color || '000000' )
      ->moveto( $x1, $y1 )->lineto( $x1, $y1, $x2, $y2, $x3, $y3 )->place;
}

# required:
# -x => $x,
# -y => $y,
# -text => $text,
#
# optional:
# -url  => $url,
sub _draw_text {    
    my $self = shift;
    if ( not $self->{'FONT'} ) {
        $self->{'FONT'} =
          $self->_api->new_font($Bio::Phylo::Treedrawer::Swf::FONT);
    }
    my %args = @_;
    my ( $x, $y, $text, $url, $size ) = @args{qw(-x -y -text -url -size)};
    $logger->debug("drawing text $text");
    if ($url) {
        $text = sprintf( '<a href="%s">%s</a>', $url, $text );
    }
    my $textobj =
      $self->_api->new_html_text->font( $self->{'FONT'} )->size( $size || 12 )
      ->text($text);
    return $textobj->place->moveto( $x, $y );
}

# -x => $x,
# -y => $y,
# -width  => $width,
# -stroke => $color,
# -radius => $radius,
# -fill   => $file,
# -api    => $api,
# -url    => $url,
sub _draw_circle {
    $logger->debug("drawing circle");
    my $self = shift;
    my %args = @_;
    my @keys = qw(-x -y -width -stroke -radius -fill -api -url);
    my ( $x, $y, $width, $stroke, $radius, $fill, $api, $url ) = @args{@keys};
    my $circle =
      $self->_api->new_shape->fillstyle( $fill || '000000' )
      ->linestyle( $width || 1, $stroke || '000000' )->circle($radius);
    return $circle->place->moveto( $x, $y );
}

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::Treedrawer>

The SWF treedrawer is called by the L<Bio::Phylo::Treedrawer> object. Look there
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
