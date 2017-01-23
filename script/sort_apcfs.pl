#!/usr/bin/perl

use strict;
use warnings;

my $refspc = shift;
my $apcf_f = shift;
my $cons_f = shift;

my $bid = -1;
my %blens = ();
open(F,"$cons_f");
while(<F>) {
	chomp;
	if (length($_) == 0) { next; }

	if ($_ =~ /^>(\S+)/) {
		$bid = $1;
	} elsif ($_ =~ /$refspc\.\S+:(\S+)\-(\S+) \S+/) {
		my $len = $2 - $1;
		$blens{$bid} = $len;
	}	
}
close(F);

my $topline = "";
my $apcfid = -1;
my %apcf_lines = ();
my %apcf_lens = ();
open(F,"$apcf_f");
while(<F>) {
	chomp;
	if ($_ =~ /^#/) { 
		my @ar = split(/\s+/);
		$apcfid = $ar[2];	
	} elsif ($_ =~ /^>/) { $topline = $_; }
	else {
		my @ar = split(/\s+/);
		my $total_len = 0;
		for (my $i = 0; $i < $#ar; $i++) {
			my $bid = $ar[$i];
			my $len = $blens{abs($bid)};
			$total_len += $len;
		}
		if (defined($apcf_lens{$total_len})) {
			my $rar = $apcf_lens{$total_len};
			push(@$rar, $apcfid);
		} else {
			$apcf_lens{$total_len} = [$apcfid];
		}
		$apcf_lines{$apcfid} = $_;
	}
}
close(F);

my $new_apcfid = 1;
print "$topline\n";
foreach my $len (sort {$b<=>$a} keys %apcf_lens) {
	my $rar = $apcf_lens{$len};
	print "# APCF $new_apcfid\n";
	$new_apcfid++;
	foreach my $apcfid (@$rar) {
		my $apcf_line = $apcf_lines{$apcfid};
		print "$apcf_line\n";
	}
}
