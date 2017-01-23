#!/usr/bin/perl

use strict;
use warnings;

my $ancstr = shift;
my $src_f = shift;

my $bid = 1;
my ($achr, $astart, $aend, $adir) = ("",-1,-1,"");
my @tblocks = ();
open(F,"$src_f");
while(<F>) {
	chomp;
	if ($_ =~ /^>/) { next; }
	if (length($_) == 0) { 
		my $asize = scalar(@tblocks);
		if ($asize == 1) {
			# only one target block
			print ">$bid\n";
			print "$ancstr.$achr:$astart-$aend $adir\n";
			print "$tblocks[0]\n";
			print "\n";	
			$bid++;
		} else {
			# more than one target blocks
			my $total_alen = $aend - $astart;

			## 
			my $total_tlen = 0;
			foreach my $tblock (@tblocks) {
				$tblock =~ /(\S+)\.(\S+):(\S+)\-(\S+) (\S+)/;
				my ($tspc, $tchr, $tstart, $tend, $tdir) = ($1,$2,$3,$4,$5);
				my $tlen = $tend - $tstart;
				$total_tlen += $tlen;
			}

			## 
			my ($new_astart, $new_aend) = ($astart, -1);
			for (my $i = 0; $i <= $#tblocks; $i++) {
				my $tblock = $tblocks[$i];
				$tblock =~ /(\S+)\.(\S+):(\S+)\-(\S+) (\S+)/;
				my ($tspc, $tchr, $tstart, $tend, $tdir) = ($1,$2,$3,$4,$5);
				my $tlen = $tend - $tstart;
				my $alen = int($total_alen * $tlen / $total_tlen);
				$new_aend = $new_astart + $alen;
				if ($i == $#tblocks) { $new_aend = $aend; }

				print ">$bid\n";
				print "$ancstr.$achr:$new_astart-$new_aend $adir\n";
				print "$tblock\n";
				print "\n";
				$bid++;	
				$new_astart = $new_aend;
			}			
		}

		@tblocks = ();	
	} elsif ($_ =~ /$ancstr\.(\S+):(\S+)\-(\S+) (\S+)/) {
		($achr, $astart, $aend, $adir) = ($1,$2,$3,$4);
	} else {
		push(@tblocks, $_);
	}
}
close(F);
