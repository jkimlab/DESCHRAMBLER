package Bio::Phylo::Util::Math;
use strict;
use warnings;
use base 'Exporter';

BEGIN {
    our ( @EXPORT_OK, %EXPORT_TAGS );
    @EXPORT_OK = qw(nchoose gcd gcd_divide);
    %EXPORT_TAGS = (
        'all' => [@EXPORT_OK],
    );
}

=head1 NAME

Bio::Phylo::Util::Math - Utility math functions

=head1 EXPORTED FUNCTIONS

=over

=item nchoose_static

Calculation of n choose j. This version saves partial results for use later.

 Type    : Exported function
 Title   : nchoose_static
 Usage   : $c = nchoose_static( $n, $j )
 Function: Calculation of n choose j.
 Returns : n-choose
 Args    : $n, $j

=cut

# Calculation of n choose j
# This version saves partial results for use later
my @nc_matrix; #stores the values of nchoose(n,j)
# -- note: order of indices is reversed
sub nchoose_static {
	my ( $n, $j, @nc_matrix ) = @_;
	return 0 if $j > $n;
	if ( @nc_matrix < $j + 1 ) {
		push @nc_matrix, [] for @nc_matrix .. $j;
	}
	if ( @{ $nc_matrix[$j] } < $n + 1 ) {	
		push @{ $nc_matrix[$j] }, 0 for @{ $nc_matrix[$j] } .. $j - 1;
	}
	push @{ $nc_matrix[$j] }, 1 if @{ $nc_matrix[$j] } == $j;
	for my $i ( @{ $nc_matrix[$j] } .. $n ) {
		push @{ $nc_matrix[$j] }, $nc_matrix[$j]->[$i-1] * $i / ( $i - $j );
	}
	return $nc_matrix[$j]->[$n];
}

=item nchoose

Calculation of n choose j. Dynamic version.

 Type    : Exported function
 Title   : nchoose
 Usage   : $c = nchoose( $n, $j )
 Function: Calculation of n choose j.
 Returns : n-choose
 Args    : $n, $j

=cut

# dynamic programming version
sub nchoose {
	my ( $n, $j ) = @_;
	return nchoose_static($n,$j,@nc_matrix);
}

=item gcd

Greatest common denominator - assumes positive integers as input

 Type    : Exported function
 Title   : gcd
 Usage   : $gcd = gcd( $n, $m )
 Function: Greatest common denominator
 Returns : $gcd
 Args    : $n, $m

=cut

# GCD - assumes positive integers as input
# (subroutine for compare(t,u,v))
sub gcd {
	my ( $n, $m ) = @_;
	return $n if $n == $m;
	( $n, $m ) =  ( $m, $n ) if $m > $n;
	my $i = int($n / $m);
	$n = $n - $m * $i;		
	return $m if $n == 0;
	
	# recurse
	return gcd($m,$n);
}

=item gcd_divide

Takes two large integers and attempts to divide them and give
the float answer without overflowing

 Type    : Exported function
 Title   : gcd_divide
 Usage   : $gcd = gcd_divide( $n, $m )
 Function: Greatest common denominator
 Returns : $gcd
 Args    : $n, $m

=cut

# Takes two large integers and attempts to divide them and give
# the float answer without overflowing
# (subroutine for compare(t,u,v))
# does this by first taking out the greatest common denominator
sub gcd_divide {
	my ( $n, $m ) = @_;
	my $x = gcd($n,$m);
	$n /= $x;
	$m /= $x;
	return $n/$m;
}

=back

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

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