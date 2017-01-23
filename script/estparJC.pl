#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib/perl";
use Bio::TreeIO;

my $n = shift;
my $tar_spc = shift;
my $tree_f = shift;
my $bdist_f = shift;

print STDERR "$n $tar_spc $tree_f $bdist_f\n";

my %hs_bdist = ();
open(F,"$bdist_f");
while(<F>) {
	chomp;
	if (length($_) == 0 || $_ =~ /^#/) { next; }
	my ($spc, $bdist) = split(/\s+/);
	if ($bdist == 0) { next; }
	$hs_bdist{$spc} = $bdist;
}
close(F);

my $in = new Bio::TreeIO(-format => "newick", -file => "$tree_f");
my $tree = $in->next_tree;
my $tarnode = $tree->find_node (-id => "$tar_spc");

my $sum = 0;
my $cnt = 0;
foreach my $spc (sort keys %hs_bdist) {
	my $bdist = $hs_bdist{$spc};
	if ($bdist == 0) { $bdist = 0.000001; }
	#print "$spc => $bdist\n";
	my $curnode = $tree->find_node(-id => "$spc");
	my @pair = ($curnode, $tarnode);
	my $t = $tree->distance(-nodes => \@pair);

	my $cmp = 1 - ((2*$n-1)*$bdist)/((2*$n-2)*$n);
	if ($cmp <= 0.0) { next; }
	my $alpha = -1/(2*$n-1) * log($cmp);
	$alpha /= $t;

	$sum += $alpha;
	$cnt++; 
}

my $avgalpha = 0.0001;
if ($cnt > 0) { $avgalpha = $sum/$cnt; } 
print "$avgalpha\n";

