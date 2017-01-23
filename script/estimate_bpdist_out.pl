#!/usr/bin/perl

use strict;
use warnings;

my $resolution = shift;
my $tar_spc = shift;
my $outspc_f = shift;
my $data_dir = shift;

my $f = "$data_dir/Conserved.Segments";

open(F,"$outspc_f");
my @outspcs = <F>;
close(F);
chomp(@outspcs); 

foreach my $out_spc (@outspcs) {
	my %mappings = ();
	my ($tscf, $tstart, $tend, $tdir) = ("",-1,-1,"");
	my @outlines = ();

	open(F,"$f");
	while(<F>) {
		chomp;
		if ($_ =~ /$tar_spc\.(\S+):(\S+)\-(\S+) (\S+)/) {
			if (length($tscf) > 0) {
	
				# remove small intermediate blocks
				my @newout = ();	
				for (my $i = 0; $i <= $#outlines; $i++) {
					if ($i > 0 && $i < $#outlines) {
						$outlines[$i] =~ /$out_spc\.(\S+):(\S+)\-(\S+) (\S+)/;
						my ($ochr, $ostart, $oend, $odir) = ($1,$2,$3,$4);
						if ($oend - $ostart <= $resolution) { next; }
					}
					push(@newout, $outlines[$i]);
				}	

				if ($tdir eq "-") {
					my @newout2 = ();
					for (my $i = $#newout; $i >= 0; $i--) {
						$newout[$i] =~ /$out_spc\.(\S+):(\S+)\-(\S+) (\S+)/;
						my ($ochr, $ostart, $oend, $odir) = ($1,$2,$3,$4);
						if ($odir eq "+") { $odir = "-"; }
						else { $odir = "+"; }
						push(@newout2, "$out_spc.$ochr:$ostart-$oend $odir");	
					}
					@newout = @newout2;
				}	

				$mappings{$tscf}{$tstart} = \@newout;
			}

			($tscf, $tstart, $tend, $tdir) = ($1,$2,$3,$4);
			@outlines = ();
		} elsif ($_ =~ /^$out_spc/) {
			push(@outlines, $_);
		}
	}
	close(F);
			
	# remove small intermediate blocks
	my @newout = ();	
	for (my $i = 0; $i <= $#outlines; $i++) {
		if ($i > 0 && $i < $#outlines) {
			$outlines[$i] =~ /$out_spc\.(\S+):(\S+)\-(\S+) (\S+)/;
			my ($ochr, $ostart, $oend, $odir) = ($1,$2,$3,$4);
			if ($oend - $ostart <= $resolution) { next; }
		}
		push(@newout, $outlines[$i]);
	}	

	if ($tdir eq "-") {
		my @newout2 = ();
		for (my $i = $#newout; $i >= 0; $i--) {
			$newout[$i] =~ /$out_spc\.(\S+):(\S+)\-(\S+) (\S+)/;
			my ($ochr, $ostart, $oend, $odir) = ($1,$2,$3,$4);
			if ($odir eq "+") { $odir = "-"; }
			else { $odir = "+"; }
			push(@newout2, "$out_spc.$ochr:$ostart-$oend $odir");	
		}
		@newout = @newout2;
	}	
	$mappings{$tscf}{$tstart} = \@newout;

	my @tscfs = keys %mappings;
	my $totalscfs = scalar(@tscfs);

	my $totalblocks = 0;
	foreach my $tscf (sort keys %mappings) {
		my $rhs = $mappings{$tscf};

		# collect all blocks
		my @outblocks = ();
		foreach my $tstart (sort {$a<=>$b} keys %$rhs) {
			my $rar = $$rhs{$tstart};
			push(@outblocks, @$rar);
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
				$outblock =~ /$out_spc\.(\S+):(\S+)\-(\S+) (\S+)/;
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
	print "$out_spc\t$bpdist\n";
}
