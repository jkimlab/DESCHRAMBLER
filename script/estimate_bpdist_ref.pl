#!/usr/bin/perl

use strict;
use warnings;

my $tar_spc = shift;
my $ref_spc = shift;
my $data_dir = shift;

my $f = "$data_dir/Conserved.Segments";

my %mappings = ();
my $refline = "";

open(F,"$f");
while(<F>) {
	chomp;
	if ($_ =~ /$tar_spc\.(\S+):(\S+)\-(\S+) (\S+)/) {
		my ($tscf, $tstart, $tend, $tdir) = ($1,$2,$3,$4);
	
		if ($tdir eq "-") {
			$refline =~ /$ref_spc\.(\S+):(\S+)\-(\S+) (\S+)/;
			my ($rchr, $rstart, $rend, $rdir) = ($1,$2,$3,$4);
			if ($rdir eq "+") { $rdir = "-"; }
			else { $rdir = "+"; }
			$refline = "$ref_spc.$rchr:$rstart-$rend $rdir";
		}	

		$mappings{$tscf}{$tstart} = $refline;
		$refline = ();
	} elsif ($_ =~ /^$ref_spc/) {
		$refline = $_;
	}
}
close(F);

my @tscfs = keys %mappings;
my $totalscfs = scalar(@tscfs);
			
my $totalblocks = 0;
foreach my $tscf (sort keys %mappings) {
	my $rhs = $mappings{$tscf};

	# collect all blocks
	my @outblocks = ();
	foreach my $tstart (sort {$a<=>$b} keys %$rhs) {
		my $rline = $$rhs{$tstart};
		push(@outblocks, $rline);
	}

	my $numblocks = 0;
	# merge collinear blocks
	my $asize = scalar(@outblocks);
	if ($asize == 0) {
		$numblocks = 0;
	} elsif ($asize == 1) {
		$numblocks = 1;
	} elsif ($asize > 1) {
		$numblocks = 0;
		my ($pochr, $podir) = ("","");
		foreach my $outblock (@outblocks) {
			$outblock =~ /$ref_spc\.(\S+):(\S+)\-(\S+) (\S+)/;
			my ($ochr, $odir) = ($1,$4);

			if (length($pochr) == 0) {
				($pochr, $podir) = ($ochr, $odir);
				$numblocks++;
				next;
			}

			if ($pochr eq $ochr && $podir eq $odir) {
				;
			} else {
				$numblocks++;
				($pochr, $podir) = ($ochr, $odir);
			} 
		}
	}	

	$totalblocks += $numblocks; 
}

my $bpdist = $totalblocks - $totalscfs;
print "$tar_spc\t$bpdist\n";
