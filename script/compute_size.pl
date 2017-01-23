#!/usr/bin/perl

use strict;
use warnings;

my $anc_spc = shift; 
my $f = shift;	

my %hs_size = ();
open(F,"$f");
while(<F>) {
	chomp;
	if ($_ =~ /$anc_spc\.(\S+):(\S+)\-(\S+)/) {
		my ($chr, $start, $end) = ($1,$2,$3);
		my $len = $end - $start;
		if (defined($hs_size{$chr})) {
			$hs_size{$chr} += $len;
		} else {
			$hs_size{$chr} = $len;
		}	
	}     
}
close(F);

my $total = 0;
foreach my $chr (sort {$a<=>$b} keys %hs_size) {
	my $len = $hs_size{$chr};
	$total += $len;
	print "$chr\t$len\n";
}
print "total\t$total\n";
