package Bio::Phylo::Treedrawer::Abstract;
use strict;
use warnings;
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::Logger ':levels';

my $logger = Bio::Phylo::Util::Logger->new;
our $DEFAULT_FONT = 'Arial';
our @FONT_DIR;

=head1 NAME

Bio::Phylo::Treedrawer::Abstract - Abstract graphics writer used by treedrawer, no
serviceable parts inside

=head1 DESCRIPTION

This module is an abstract super class for the various graphics formats that 
Bio::Phylo supports. There is no direct usage of this class. Consult 
L<Bio::Phylo::Treedrawer> for documentation on how to draw trees.

=cut

sub _new {
    my $class = shift;
    my %args  = @_;
    my $self  = {
        'TREE'   => $args{'-tree'},
        'DRAWER' => $args{'-drawer'},
        'API'    => $args{'-api'},
    };
    return bless $self, $class;
}
sub _api    { shift->{'API'} }
sub _drawer { shift->{'DRAWER'} }
sub _tree   { shift->{'TREE'} }

=begin comment

 Type    : Internal method.
 Title   : _draw
 Usage   : $svg->_draw;
 Function: Main drawing method.
 Returns :
 Args    : None.

=end comment

=cut

sub _draw {
    my $self = shift;
    my $td   = $self->_drawer;
    $self->_draw_scale;
    $self->_tree->visit_depth_first(
        '-post' => sub {
            my $node        = shift;
            my $x           = $node->get_x;
            my $y           = $node->get_y;            
            my $is_terminal = $node->is_terminal;
            my $r = $is_terminal ? $td->get_tip_radius : $td->get_node_radius;
            $logger->debug("going to draw branch");
            $self->_draw_branch($node);
            if ( $node->get_collapsed ) {
            	$logger->debug("going to draw collapsed clade");
                $self->_draw_collapsed($node);
            }
            else {
                if ( my $name = $node->get_name ) {
                	$logger->debug("going to draw node label '$name'");
                    $name =~ s/_/ /g;
                    $name =~ s/^'(.*)'$/$1/;
                    $name =~ s/^"(.*)"$/$1/;
                    $self->_draw_text(
                        '-x'           => int( $x + $td->get_text_horiz_offset ),
                        '-y'           => int( $y + $td->get_text_vert_offset ),
                        '-text'        => $name,
                        '-rotation'    => [ $node->get_rotation, $x, $y ],
                        '-font_face'   => $node->get_font_face,
                        '-font_size'   => $node->get_font_size,
                        '-font_style'  => $node->get_font_style,
                        '-font_colour' => $node->get_font_colour,
                        '-font_weight' => $node->get_font_weight,
                        '-url'         => $node->get_link,
                        'class'        => $is_terminal ? 'taxon_text' : 'node_text',
                    );
                }
            }
            if ( $r ) {
				$self->_draw_circle(
					'-radius' => $r,
					'-x'      => $x,
					'-y'      => $y,
					'-width'  => $node->get_branch_width,
					'-stroke' => $node->get_node_outline_colour,
					'-fill'   => $node->get_node_colour,
					'-url'    => $node->get_link,
				);
            }
            if ( $node->get_clade_label ) {
            	if ( not $self->_tree->get_meta_object('map:tree_size') ) {
            		my $tips = $self->_tree->get_root->get_terminals;
            		$self->_tree->set_meta_object( 'map:tree_size' => scalar(@$tips) );
            	}
            	$logger->debug("going to draw clade label");
            	$self->_draw_clade_label($node);
            }
        }
    );
    $logger->debug("going to draw node pie charts");
    $self->_draw_pies;
    $logger->debug("going to draw legend");
    $self->_draw_legend;
    return $self->_finish;
}

sub _draw_pies {
    my $self = shift;
    $logger->warn( ref($self) . " can't draw pies" );
}

sub _draw_legend {
    my $self = shift;
    $logger->warn( ref($self) . " can't draw a legend" );
}

sub _finish {
    my $self = shift;
    throw 'NotImplemented' => ref($self) . " won't complete its drawing";
}

sub _draw_text {
    my $self = shift;
    throw 'NotImplemented' => ref($self) . " can't draw text";
}

sub _draw_line {
    my $self = shift;
    throw 'NotImplemented' => ref($self) . " can't draw line";
}

sub _draw_arc {
    my $self = shift;
    throw 'NotImplemented' => ref($self) . " can't draw arc";    
}

sub _draw_curve {
    my $self = shift;
    throw 'NotImplemented' => ref($self) . " can't draw curve";
}

sub _draw_multi {
    my $self = shift;
    throw 'NotImplemented' => ref($self) . " can't draw multi line";
}

sub _draw_triangle {
    my $self = shift;
    throw 'NotImplemented' => ref($self) . " can't draw triangle";
}

sub _draw_rectangle {
	my $self = shift;
	throw 'NotImplemented' => ref($self) . " can't draw rectangle";
}

# XXX incomplete, still needs work for the radial part
sub _draw_clade_label {    
    my ( $self, $node ) = @_;
    $logger->info("Drawing clade label ".$node->get_clade_label);
    my $td  = $self->_drawer;
    my $tho = $td->get_text_horiz_offset;
    my $tw  = $td->get_text_width;
    
    my $desc = $node->get_descendants;
    my $ntips = [ grep { $_->is_terminal } @$desc ];
    my $lmtl = $node->get_leftmost_terminal;
    my $rmtl = $node->get_rightmost_terminal;
    my $root = $node->get_tree->get_root;    
    my $ncl  = scalar( grep { $_->get_clade_label } @{ $node->get_ancestors } );
    
    # copy font preferences, if any
    my %font = ( '-text' => $node->get_clade_label );
    my $f = $node->get_clade_label_font || {};
	my @properties = qw(face size style weight colour);
	for my $p ( @properties ) {
		if ( my $value = $f->{"-$p"} ) {
			$font{"-font_$p"} = $value;
		}
		else {
			my $method = "get_font_$p";
			if ( $value = $node->$method ) {
				$font{"-font_$p"} = $value;
			}
		}
	}
   
    # get cartesian coordinates for root and leftmost and rightmost tip
    my ( $cx, $cy ) = ( $root->get_x, $root->get_y );
    my ( $rx, $ry ) = ( $rmtl->get_x, $rmtl->get_y );
    my ( $lx, $ly ) = ( $lmtl->get_x, $lmtl->get_y );
    
    # handle radial projection, either phylogram or cladogram
    if ( $td->get_shape =~ /radial/i ) {
        
        # compute tallest node in the clade and radius from the root
        my $radius;
        if ( @$desc ) {
            for my $d ( @$desc ) {
                
                # pythagoras
                my ( $x1, $y1 ) = ( $d->get_x, $d->get_y );            
                my $h1 = sqrt( abs($cx-$x1)*abs($cx-$x1) + abs($cy-$y1)*abs($cy-$y1) );
                $radius = $h1 if not defined $radius; # initialize
                $radius = $h1 if $h1 >= $radius; # bump up if higher value
            }
        }
        else {
                # pythagoras
                my ( $x1, $y1 ) = ( $node->get_x, $node->get_y );            
                $radius = sqrt( abs($cx-$x1)*abs($cx-$x1) + abs($cy-$y1)*abs($cy-$y1) );            
        }
        
        # compute angles and coordinates of start and end of arc
        my $offset = $td->get_clade_label_width * $ncl;
        $radius += ( $tho * 2 + $tw + $offset );
        my ( $rr, $ra ) = $td->cartesian_to_polar( ($rx-$cx), ($ry-$cy) ); # rightmost
        my ( $lr, $la ) = $td->cartesian_to_polar( ($lx-$cx), ($ly-$cy) ); # leftmost
        my ( $x1, $y1 ) = $td->polar_to_cartesian( $radius, $ra ); # + add origin!
        my ( $x2, $y2 ) = $td->polar_to_cartesian( $radius, $la ); # + add origin!
        
        # draw line and label
        #my $ntips = $node->get_terminals;
        #my $rtips = $root->get_terminals;
        my $size = $node->get_tree->get_meta_object('map:tree_size');
        my $large = (scalar(@$ntips)/$size) > 1/2 ? 1 : 0; # spans majority of tips
        $self->_draw_arc(
            '-x1' => $x1 + $cx,
            '-y1' => $y1 + $cy,
            '-x2' => $x2 + $cx,
            '-y2' => $y2 + $cy,
            '-radius' => $radius,
            '-large'  => $large,
            '-sweep'  => 0,
        );
        
        # include $tho
        my ( $tx1, $ty1 ) = $td->polar_to_cartesian(($radius+$tho),$ra); # + add origin!
        $self->_draw_text( %font,
        	'-x' => $tx1 + $cx,
        	'-y' => $ty1 + $cy,
        	'-rotation' => [ $ra, $tx1 + $cx, $ty1 + $cy ],
        );
    }
    
    # can do the same thing for clado and phylo
    else {
                
        # fetch the tallest node in t
        my $x1;
        for my $d ( @$desc ) {
            my $x = $d->get_x;
            $x1 = $x if not defined $x1; # initialize
            $x1 = $x if $x >= $x1; # bump if $higher
        }
        
        # draw line and label
        my $offset = $td->get_clade_label_width * $ncl;
        $x1 += ( $tho * 2 + $tw + $offset );
        my ( $y1, $y2 ) = ( $lmtl->get_y, $rmtl->get_y );
        $self->_draw_line(
            '-x1' => $x1,
            '-x2' => $x1,            
            '-y1' => $y1,
            '-y2' => $y2,
        );
        $self->_draw_text( %font,
            '-x' => ($x1+$tho),
            '-y' => $y1,
            '-rotation' => [ 90, ($x1+$tho), $y1 ],
        );
    }
    
    
}

sub _draw_collapsed {
    $logger->info("drawing collapsed node");
    my ( $self, $node ) = @_;
    my $td = $self->_drawer;
    $node->set_collapsed(0);

    # Get the height of the tallest node above the collapsed clade; for cladograms this
    # is 1, for phylograms it's the sum of the branch lengths. Then, compute x1 and x2,
    # i.e. the tip and the base of the triangle, which consequently are different between
    # cladograms and phylograms.
    my $tallest = 0;
    my ( $x1, $x2 );
    my $clado = $td->get_mode =~ m/clado/i;
    if ( $clado ) {
        $tallest = 1;        
        $x1 = $node->get_x - $tallest * $td->_get_scalex;
        $x2 = $node->get_x;
    }
    else {
        $node->visit_depth_first(
            '-pre' => sub {
                my $n = shift;
                my $height = $n->get_parent->get_generic('height') + $n->get_branch_length;
                $n->set_generic( 'height' => $height );
                $tallest = $height if $height > $tallest;
            }
        );
        $tallest -= $node->get_branch_length;
        $x1 = $node->get_x;
        $x2 = ( $tallest * $td->_get_scalex + $node->get_x );         
    }
    
    # draw the collapsed triangle
    my $padding = $td->get_padding;
    my $cladew  = $td->get_collapsed_clade_width($node);
    my $y1 = $node->get_y;
    $self->_draw_triangle(
        '-fill'   => $node->get_node_colour,
        '-stroke' => $node->get_node_outline_colour,
        '-width'  => $td->get_branch_width($node),
        '-url'    => $node->get_link,
        'id'      => 'collapsed' . $node->get_id,
        'class'   => 'collapsed',         
        '-x1'     => $x1,
        '-y1'     => $y1,
        '-x2'     => $x2,
        '-y2'     => $y1 + $cladew / 2 * $td->_get_scaley,
        '-x3'     => $x2,
        '-y3'     => $y1 - $cladew / 2 * $td->_get_scaley,
    );
    
    # draw the collapsed clade label
    if ( my $name = $node->get_name ) {
        $name =~ s/_/ /g;
        $name =~ s/^'(.*)'$/$1/;
        $name =~ s/^"(.*)"$/$1/;
        $self->_draw_text(
            'id'           => 'collapsed_text' . $node->get_id,
            'class'        => 'collapsed_text',
            '-font_face'   => $node->get_font_face,
            '-font_size'   => $node->get_font_size,
            '-font_style'  => $node->get_font_style,
            '-font_colour' => $node->get_font_colour,
            '-font_weight' => $node->get_font_weight,              
            '-x'           => int( $x2 + $td->get_text_horiz_offset ),
            '-y'           => int( $y1 + $td->get_text_vert_offset ),
            '-text'        => $name,
        );
    }
    $node->set_collapsed(1);
}

=begin comment

 Type    : Internal method.
 Title   : _draw_scale
 Usage   : $svg->_draw_scale();
 Function: Draws scale for phylograms
 Returns :
 Args    : None

=end comment

=cut

sub _draw_scale {
    my $self   = shift;
    my $drawer = $self->_drawer;
    
    # if not options provided, won't attempt to draw a scale
    if ( my $options = $drawer->get_scale_options ) {
		my $tree   = $self->_tree;
		my $root   = $tree->get_root;
		my $rootx  = $root->get_x;
		my $height = $drawer->get_height;
    
    	# read and convert the font preferences for the _draw_text method
        my %font;
        if ( $options->{'-font'} and ref $options->{'-font'} eq 'HASH' ) {
            for my $key ( keys %{ $options->{'-font'} } ) {
                my $nk = $key;
                $nk =~ s/-/-font_/;
                $font{$nk} = $options->{'-font'}->{$key};  
            }
        }

		# convert width and major/minor ticks to absolute pixel values
        my ( $major, $minor ) = ( $options->{'-major'}, $options->{'-minor'} );
        my $width  = $options->{'-width'};
        my $blocks = $options->{'-blocks'};
        
        # find the tallest tip, irrespective of it being collapsed
        my ($tt) = sort { $b->get_x <=> $a->get_x } @{ $tree->get_entities };        
        my $ttx = $tt->get_x;
        my $ptr = $tt->calc_path_to_root;
        if ( $width =~ m/^(\d+)%$/ ) {
            $width = ( $1 / 100 ) * ( $ttx - $rootx );
        }        
        if ( my $units = $options->{'-units'} ) {
            
            # now we need to calculate how much each branch length unit (e.g.
            # substitutions) is in pixels. The $width then becomes the length
            # of one branch length unit in pixels times $units                        
            my $unit_in_pixels = ( $ttx - $rootx ) / $ptr;
            $width = $units * $unit_in_pixels;
        }
        if ( $major =~ m/^(\d+)%$/ ) {
            $major = ( $1 / 100 ) * $width;
        }
        if ( $minor =~ m/^(\d+)%$/ ) {
            $minor = ( $1 / 100 ) * $width;
        }
        if ( $blocks and $blocks =~ m/^(\d+)%$/ ) {
        	$blocks = ( $1 / 100 ) * $width;
        }
        
        # draw scale line and apply label
        my $x1 = $options->{'-reverse'} ? $ttx : $rootx;
        my $ws = $options->{'-reverse'} ? -1 : 1;
        my $ts = $options->{'-reverse'} ?  0 : 1;        
        $self->_draw_line(
            '-x1'   => $x1,
            '-y1'   => ( $height - 40 ),
            '-x2'   => $x1 + ($width*$ws),
            '-y2'   => ( $height - 40 ),
            'class' => 'scale_bar',
        );
        $self->_draw_text( %font,
            '-x'    => ( $x1 + ($width*$ts) + $drawer->get_text_horiz_offset ),
            '-y'    => ( $height - 30 ),
            '-text' => $options->{'-label'} || ' ',
            'class' => 'scale_label',
        );
        
        # pre-compute indexes so we can reverse
        my ( @maji, @mini, @blocksi ); # major/minor/blocks indexes
        my $j = 0;
        if ( $options->{'-reverse'} ) {
            for ( my $i = $ttx ; $i >= ( $ttx - $width ) ; $i -= $minor ) {
                if ( not $j % sprintf('%.0f', $major/$minor) ) {
                	push @maji, $i;
                	if ( $blocks and not scalar(@maji) % 2 ) {
                		push @blocksi, $i;
                	}
                }
                push @mini, $i;
                $j++;
            }
        }
        else {
            for ( my $i = $rootx ; $i <= ( $rootx + $width ) ; $i += $minor ) {
                if ( not $j % sprintf('%.0f', $major/$minor) ) {
                	push @maji, $i;
                	if ( $blocks and not scalar(@maji) % 2 ) {
                		push @blocksi, $i;
                	}
                }
                push @mini, $i;
                $j++;
            }
        }        
        
        # draw ticks and labels
        my $major_text = 0;
        my $major_scale = ( $major / $width ) * $ptr;
        my $tmpl = $options->{'-tmpl'} || '%s';
        my $code = ref $tmpl ? $tmpl : sub { sprintf $tmpl, shift };                
        for my $i ( @maji ) {
            $self->_draw_line(
                '-x1'   => $i,
                '-y1'   => ( $height - 40 ),
                '-x2'   => $i,
                '-y2'   => ( $height - 25 ),
                'class' => 'scale_major',
            );
            $self->_draw_text( %font,
                '-x'    => $i,
                '-y'    => ( $height - 5 ),
                '-text' => $code->( $major_text ),
                'class' => 'major_label',
            );
            $major_text += $major_scale;
        }
        for my $i ( @mini ) {
            next if not $i % $major;
            $self->_draw_line(
                '-x1'   => $i,
                '-y1'   => ( $height - 40 ),
                '-x2'   => $i,
                '-y2'   => ( $height - 35 ),
                'class' => 'scale_minor',
            );
        }
        
        # draw blocks
        if ( @blocksi ) {
        	my @y = map { $_->get_y } sort { $a->get_y <=> $b->get_y } @{ $tree->get_entities };
        	my $y = $y[0] - 20;
        	my $height = ( $y[-1] - $y[0] ) + 40;
        	my $width  = ( $blocksi[0] - $blocksi[1] ) / 2;        
			for my $i ( @blocksi ) {
				$self->_draw_rectangle(
					'-x'      => $i,
					'-y'      => $y,
					'-height' => $height,
					'-width'  => $width,
					'-fill'   => 'whitesmoke',
					'-stroke_width' => 0,
					'-stroke'       => 'whitesmoke',					
				);
			}
        }
    }
}

=begin comment

 Type    : Internal method.
 Title   : _draw_branch
 Usage   : $svg->_draw_branch($node);
 Function: Draws internode between $node and $node->get_parent, if any
 Returns :
 Args    : 

=end comment

=cut

sub _draw_branch {
    my ( $self, $node ) = @_;
    $logger->info( "Drawing branch for " . $node->get_internal_name );
    if ( my $parent = $node->get_parent ) {
        my ( $x1, $x2 ) = ( int $parent->get_x, int $node->get_x );
        my ( $y1, $y2 ) = ( int $parent->get_y, int $node->get_y );
        my $shape = $self->_drawer->get_shape;
        my $drawer = '_draw_curve';
        if ( $shape =~ m/CURVY/i ) {
            $drawer = '_draw_curve';
        }
        elsif ( $shape =~ m/RECT/i ) {
            $drawer = '_draw_multi';
        }
        elsif ( $shape =~ m/DIAG/i ) {
            $drawer = '_draw_line';
        }
        elsif ( $shape =~ m/UNROOTED/i ) {
            $drawer = '_draw_line';
        }
        elsif ( $shape =~ m/RADIAL/i ) {
            return $self->_draw_radial_branch($node);
        }
        return $self->$drawer(
            '-x1'    => $x1,
            '-y1'    => $y1,
            '-x2'    => $x2,
            '-y2'    => $y2,
            '-width' => $self->_drawer->get_branch_width($node),
            '-color' => $node->get_branch_color
        );
    }
}

=begin comment

 Type    : Internal method.
 Title   : _draw_radial_branch
 Usage   : $svg->_draw_radial_branch($node);
 Function: Draws radial internode between $node and $node->get_parent, if any
 Returns :
 Args    : 

=end comment

=cut

sub _draw_radial_branch {
    my ( $self, $node ) = @_;
    
    if ( my $parent = $node->get_parent ) {
        my $td = $self->_drawer;
        my $center_x = $td->get_width / 2;
        my $center_y = $td->get_height / 2;
        my $width    = $td->get_branch_width($node);
    
        # first the straight piece up to the arc
        my ( $x1, $y1 ) = ( $node->get_x, $node->get_y );
        my $rotation = $node->get_rotation;        
        my $parent_radius = $parent->get_generic('radius');
        my ( $x2, $y2 ) = $td->polar_to_cartesian( $parent_radius, $rotation );
        $x2 += $center_x;
        $y2 += $center_y;
        $self->_draw_line(
            '-x1'      => $x1,
            '-y1'      => $y1,
            '-x2'      => $x2,
            '-y2'      => $y2,
            '-width'   => $width,
            '-color'   => $node->get_branch_color,
            '-linecap' => 'square'
        );
                    
        # then the arc
        my ( $x3, $y3 ) = ( $parent->get_x, $parent->get_y );
        if ( $parent->get_rotation < $rotation ) {
            ( $x2, $x3 ) = ( $x3, $x2 );
            ( $y2, $y3 ) = ( $y3, $y2 );
        }
        $self->_draw_arc(
            '-x1'      => $x2,
            '-y1'      => $y2,
            '-x2'      => $x3,
            '-y2'      => $y3,
            '-radius'  => $parent_radius,
            '-width'   => $width,
            '-color'   => $node->get_branch_color,
            '-linecap' => 'square'
        )
    }
}

sub _font_path {
    my $self = shift;
    my $font = shift || $DEFAULT_FONT;
    if ( $^O =~ /darwin/ ) {
        push @FONT_DIR, '/System/Library/Fonts', '/Library/Fonts';
    }
    elsif ( $^O =~ /linux/ ) {
        push @FONT_DIR, '/usr/share/fonts';
    }
    elsif ( $^O =~ /MSWin/ ) {
        push @FONT_DIR, $ENV{'WINDIR'} . '\Fonts';
    }
    else {
        $logger->warn("Don't know where fonts are on $^O");
    }
    for my $dir ( @FONT_DIR ) {
        if ( -e "${dir}/${font}.ttf" ) {
            return "${dir}/${font}.ttf";
        }
    }
    $logger->warn("Couldn't find font $font");
}

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::Treedrawer>

Treedrawer subclasses are called by the L<Bio::Phylo::Treedrawer> object. Look
there to learn how to create tree drawings.

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
