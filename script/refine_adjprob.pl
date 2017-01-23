#!/usr/bin/perl

use strict;
use warnings;

my $prob_f = shift;

my $max_prob = 0;
my %hs_probs = ();
open(F, "$prob_f");
while(<F>) {
	chomp;
	if ($_ =~ /^#/ || length($_) == 0) { next; }
	my ($bid1, $bid2, $prob) = split(/\s+/);

	if ($prob > $max_prob) { $max_prob = $prob; }

	if (abs($bid1) > abs($bid2)) {
		my $tmp = $bid1;
		$bid1 = -1*$bid2;
		$bid2 = -1*$tmp;
	}

	if (defined($hs_probs{$bid1}{$bid2})) {
		my $pval = $hs_probs{$bid1}{$bid2} = $prob;	
		die if ($prob != $pval);
	} else {
		$hs_probs{$bid1}{$bid2} = $prob;	
	}
}
close(F);

# normalization and print out
foreach my $bid1 (sort {abs($a)<=>abs($b)} keys %hs_probs) {
	my $rhs = $hs_probs{$bid1};
	foreach my $bid2 (sort {abs($a)<=>abs($b)} keys %$rhs) {
		my $prob = $$rhs{$bid2};
		print "$bid1\t$bid2\t$prob\n"; 
	}
}

