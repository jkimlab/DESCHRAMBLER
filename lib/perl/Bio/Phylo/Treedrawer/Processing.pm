package Bio::Phylo::Treedrawer::Processing;
use strict;
use warnings;
use base 'Bio::Phylo::Treedrawer::Abstract';
use Bio::Phylo::Util::Logger;
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT '_PI_';

=head1 NAME

Bio::Phylo::Treedrawer::Processing - Graphics format writer used by treedrawer,
no serviceable parts inside

=head1 DESCRIPTION

This module creates a Processing graphic from a Bio::Phylo::Forest::DrawTree
object. It is called by the L<Bio::Phylo::Treedrawer> object, so look there to
learn how to create tree drawings.

=cut

my $logger = Bio::Phylo::Util::Logger->new;
my $black  = 0;
my $white  = 255;
my %colors;
my $PI = _PI_;

sub _new {
    my $class = shift;
    my %args  = @_;
    my $commands;
    my $self = $class->SUPER::_new( %args, '-api' => \$commands );
    return bless $self, $class;
}

sub _draw_pies {
    my $self = shift;
    my $api  = $self->_api;
    $self->_tree->visit_level_order(
        sub {
            my $node = shift;
            if ( not $node->get_collapsed ) {
                my $cx = sprintf( "%.3f", $node->get_x );
                my $cy = sprintf( "%.3f", $node->get_y );
                my $r;
                if ( $node->is_internal ) {
                    $r =
                      sprintf( "%.3f", $self->_drawer->get_node_radius($node) );
                }
                else {
                    $r =
                      sprintf( "%.3f", $self->_drawer->get_tip_radius($node) );
                }
                if ( my $pievalues = $node->get_generic('pie') ) {
                    my @keys  = keys %{$pievalues};
                    my $start = 0;
                    my $total;
                    $total += $pievalues->{$_} for @keys;
                    for my $i ( 0 .. $#keys ) {
                        next if not $pievalues->{ $keys[$i] };
                        my $slice =
                          $pievalues->{ $keys[$i] } / $total * 2 * $PI;
                        my $color = $colors{ $keys[$i] };
                        if ( not $color ) {
                            $colors{ $keys[$i] } = $color =
                              int( ( $i / $#keys ) * 256 );
                        }
                        my $stop = $start + $slice;
                        $$api .=
                          "    drawArc($cx,$cy,$r,0,1,$color,$start,$stop);\n";
                        $start += $slice;
                    }
                }
            }
        }
    );
}

sub _draw_legend {
    my $self = shift;
    if (%colors) {
        my $api  = $self->_api;
        my $tree = $self->_tree;
        my $draw = $self->_drawer;
        my @keys = keys %colors;
        my $increment =
          ( $tree->get_tallest_tip->get_x - $tree->get_root->get_x ) /
          scalar @keys;
        my $x = sprintf( "%.3f", $tree->get_root->get_x + 5 );
        foreach my $key (@keys) {
            my $y      = sprintf( "%.3f", $draw->get_height - 90 );
            my $width  = sprintf( "%.3f", $increment - 10 );
            my $height = sprintf( "%.3f", 10.0 );
            my $color  = int $colors{$key};
            $$api .= "    drawRectangle($x,$y,$width,$height,$color);\n";
            $self->_draw_text(
                '-x'    => int($x),
                '-y'    => int( $draw->get_height - 60 ),
                '-text' => $key || ' ',
            );
            $x += $increment;
        }
        $self->_draw_text(
            '-x' => int(
                $tree->get_tallest_tip->get_x + $draw->get_text_horiz_offset
            ),
            '-y'    => int( $draw->get_height - 80 ),
            '-text' => 'Node value legend',
        );
    }
}

sub _finish {
    my $self     = shift;
    my $commands = $self->_api;
    my $tmpl     = do { local $/; <DATA> };
    return sprintf( $tmpl,
        __PACKAGE__, my $time = localtime(),
        $self->_drawer->get_width, $self->_drawer->get_height,
        $white, $$commands );
}

sub _draw_text {
    my $self = shift;
    my %args = @_;
    my ( $x, $y, $text, $url, $stroke ) = @args{qw(-x -y -text -url -color)};
    $stroke = $black if not defined $stroke;
    my $api = $self->_api;
    $$api .= "    drawText(\"$text\",$x,$y,$stroke);\n";
}

sub _draw_line {
    my $self = shift;
    my %args = @_;
    my @keys = qw(-x1 -y1 -x2 -y2 -width -color);
    my ( $x1, $y1, $x2, $y2, $width, $color ) = @args{@keys};
    $color = $black if not defined $color;
    $width = 1      if not defined $width;
    my $api = $self->_api;
    $$api .= sprintf("    drawLine(%u,%u,%u,%u,%u,%u);\n",$x1,$y1,$x2,$y2,$color,$width);
}

sub _draw_curve {
    my $self = shift;
    my $api  = $self->_api;
    my %args = @_;
    my @keys = qw(-x1 -y1 -x2 -y2 -width -color);
    my ( $x1, $y1, $x3, $y3, $width, $color ) = @args{@keys};
    $x1 = sprintf( "%.3f", $x1 );
    $x3 = sprintf( "%.3f", $x3 );
    $y1 = sprintf( "%.3f", $y1 );
    $y3 = sprintf( "%.3f", $y3 );
    $color = $black if not defined $color;
    $width = 1      if not defined $width;
    $$api .= "    drawCurve($x1,$y1,$x3,$y3,$color,$width);\n";
}

sub _draw_arc {
    my $self = shift;
    my $api  = $self->_api;
    my %args = @_;
    my @keys = qw(-x1 -y1 -x2 -y2 -radius -width -color);
    my ( $x1, $y1, $x2, $y2, $radius, $lineWidth, $lineColor ) = @args{@keys};
    $lineColor = $black if not defined $lineColor;
    $lineWidth = 1      if not defined $lineWidth;
    $radius = 0         if not defined $radius;
    $radius *= 2;
    my $fillColor = $white;    
    
    # get center of arc
    my $drawer = $self->_drawer;
    my $cx = $drawer->get_width  / 2;
    my $cy = $drawer->get_height / 2;

    # compute start and end
    my ( $r1, $start ) = $drawer->cartesian_to_polar( $x1 - $cx, $y1 - $cy );
    my ( $r2, $stop )  = $drawer->cartesian_to_polar( $x2 - $cx, $y2 - $cy );
    $start += 360 if $start < 0;
    $stop  += 360 if $stop < 0;
    $start = ( $start / 360 ) * 2 * $PI;
    $stop  = ( $stop / 360 ) * 2 * $PI;
    $start = sprintf( "%.3f", $start );
    $stop  = sprintf( "%.3f", $stop );    
        
    $$api .= "    drawArc($cx,$cy,$radius,$lineColor,$lineWidth,$fillColor,$start,$stop);\n";
}

sub _draw_multi {
    my $self = shift;
    my $api  = $self->_api;
    my %args = @_;
    my @keys = qw(-x1 -y1 -x2 -y2 -width -color);
    my ( $x1, $y1, $x2, $y2, $width, $color ) = @args{@keys};
    $color = $black if not defined $color;
    $width = 1      if not defined $width;
    $$api .= sprintf( "    drawMulti(%u,%u,%u,%u,%u,%u);\n",
        $x1, $y1, $x2, $y2, $color, $width );
}

sub _draw_triangle {
    my $self  = shift;
    my $api   = $self->_api;
    my %args  = @_;
    my @coord = qw(-x1 -y1 -x2 -y2 -x3 -y3);
    my ( $x1, $y1, $x2, $y2, $x3, $y3 ) = @args{@coord};
    my @optional = qw(-fill -stroke -width -url -api);
    my $fill     = $args{'-fill'} || $white;
    my $stroke   = $args{'-stroke'} || $black;
    my $width    = $args{'-width'} || 1;
    my $url      = $args{'-url'};
    $$api .=
      "    drawTriangle($x1,$y1,$x2,$y2,$x3,$y3,$stroke,$width,$fill);\n";
}

sub _draw_circle {
    my $self = shift;
    my $api  = $self->_api;
    my %args = @_;
    my ( $x, $y, $radius, $width, $stroke, $fill, $url ) =
      @args{qw(-x  -y  -radius  -width  -stroke  -fill  -url)};
    $stroke = $black if not defined $stroke;
    $width  = 1      if not defined $width;
    $fill   = $white if not defined $fill;
    $$api .= sprintf( "    drawCircle(%u,%u,%u,%u,%u,%u,\"%s\");\n",
        $x, $y, $radius, $stroke, $width, $fill, $url );
}

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<http://processing.org>

This treedrawer produces a tree description in Processing language syntax. Visit
the website to learn more about how to deploy such graphics.

=item L<Bio::Phylo::Treedrawer>

The processing treedrawer is called by the L<Bio::Phylo::Treedrawer> object.
Look there to learn how to create tree drawings.

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
__DATA__

/*
* This code was generated by %s on %s - do need edit this, regenerate it
*/

ArrayList coordinates = new ArrayList();

void mouseClicked() {
    for (int i = coordinates.size()-1; i >= 0; i--) {
        HashMap co = (HashMap) coordinates.get(i);
        int minX = (Integer) co.get("minX");
        int maxX = (Integer) co.get("maxX");
        int minY = (Integer) co.get("minY");
        int maxY = (Integer) co.get("maxY");
        if ( mouseX > minX && mouseX < maxX && mouseY > minY && mouseY < maxY ) {
            link((String)co.get("url"));
        }
    }  
}

void drawText(String textString, int x, int y, int textColor) {
    fill(textColor);
    text(textString,x,y);
    noFill();    
}

void drawLine(int x1, int y1, int x2, int y2, int lineColor, int lineWidth) {
    stroke(lineColor);
    strokeWeight(lineWidth);    
    line(x1,y1,x2,y2);
    strokeWeight(1);
    noStroke();
}    

void drawMulti(int x1, int y1, int x2, int y2, int lineColor, int lineWidth) {
    drawLine(x1,y1,x1,y2,lineColor,lineWidth);
    drawLine(x1,y2,x2,y2,lineColor,lineWidth);
}

void drawCircle(int x, int y, int radius, int lineColor, int lineWidth, int fillColor, String url) {
    fill(fillColor);
    stroke(lineColor);
    strokeWeight(lineWidth);
    ellipse(x, y, radius, radius);
    strokeWeight(1);
    noStroke();
    noFill();
    if ( url != null ) {
        HashMap coordinate = new HashMap();
        coordinate.put("url",url);
        coordinate.put("minX",x-radius);
        coordinate.put("maxX",x+radius);
        coordinate.put("minY",y-radius);
        coordinate.put("maxY",y+radius);
        coordinates.add(coordinate);
    }
}

void drawCurve(float x1, float y1, float x3, float y3, int lineColor, int lineWidth) {
    stroke(lineColor);
    strokeWeight(lineWidth);
    noFill();
    float ellipseWidth = abs(x1-x3) * 2;
    float ellipseHeight = abs(y1-y3) * 2;
    float start;
    float stop;
    if ( y1 < y3 ) {
        start = PI / 2;
        stop = PI;
    }
    else {
        start = PI;
        stop = TWO_PI - PI / 2;
    }
    arc(x3,y1,ellipseWidth,ellipseHeight,start,stop);    
    strokeWeight(1);
    noStroke();
}

void drawArc(float x, float y, float radius, int lineColor, int lineWidth, int fillColor, float start, float stop) {
    fill(fillColor);
    stroke(lineColor);
    strokeWeight(lineWidth);
    arc(x,y,radius,radius,start,stop);
    strokeWeight(1);
    noStroke();
    noFill();    
}

void drawRectangle(float x, float y, float width, float height, int fillColor) {
    fill(fillColor);
    stroke(0);
    strokeWeight(1);
    rect(x,y,width,height);
    noStroke();
    noFill();      
}

void drawTriangle(float x1, float y1, float x2, float y2, float x3, float y3, int lineColor, int lineWidth, int fillColor) {
    fill(fillColor);
    stroke(lineColor);
    strokeWeight(lineWidth);
    triangle(x1, y1, x2, y2, x3, y3);
    strokeWeight(1);
    noStroke();
    noFill();    
}

void setup() {
    size(%u, %u);
    background(%s);
    smooth();
%s
}

void draw() {}    
