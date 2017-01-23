#!/usr/bin/perl

use strict;
use warnings;

my $block_f = shift;
my $apcf_f = shift;

my $numblocks = 0;
open(F,"$block_f");
while(<F>) {
	chomp;
	my @ar = split(/\s+/);
	my $bid = abs($ar[4]);
	if ($bid > $numblocks) { $numblocks = $bid; }
} 
close(F);

my $maxid = 0;
my %used = ();
open(F,"$apcf_f");
while(<F>) {
	chomp;
	print "$_\n";

	if ($_ =~ /^>/) { next; }
	if ($_ =~ /^#/) {
		my @ar = split(/\s+/);
		my $pcfid = $ar[2];
		if ($pcfid > $maxid) { $maxid = $pcfid; }
	} else {
		my @ar = split(/\s+/);
		for (my $i = 0; $i < $#ar; $i++) {
			my $bid = $ar[$i];
			$used{abs($bid)} = 1;
		}	
	}
}
close(F);

$maxid++;
for (my $bid = 1; $bid <= $numblocks; $bid++) {
	if (defined($used{$bid})) { next; }
	print "# APCF $maxid\n";
	print "$bid \$\n";
	$maxid++;
}
