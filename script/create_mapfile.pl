#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin";

my $config_f = shift;
my $cons_f = shift;
my $adjscore_f = shift;
my $apcf_f = shift;
my $adjs_f = shift;
my $out_dir = shift;

system("mkdir -p $out_dir");

my %hs_adjscores = ();
open(F,"$adjscore_f");
while(<F>) {
	chomp;
	my ($bid1, $bid2, $score) = split(/\s+/);
	$hs_adjscores{$bid1}{$bid2} = $score;
	$hs_adjscores{-1*$bid2}{-1*$bid1} = $score;	
}
close(F);

my @spcs = ();
open(F,"$config_f");
while(<F>) {
	chomp;
	if (length($_) == 0 || $_ =~ /^#/) { next; }
	if ($_ =~ /^(\S+)\s+(\d)/) {
		my ($spc, $type) = ($1, $2);
		if ($type == 0 || $type == 1 || $type == 2) { push(@spcs, $1); }
	}	
}
close(F);

my %hs_cons = ();
open(F,"$cons_f");
my $consid = 0;
while(<F>) {
	chomp;
	if (length($_) == 0) { next; }
	if ($_ =~ /^>/) {
		$consid = substr($_, 1);
	} else {
		my @ar = split(/\./);
		#$_ =~ /(\S+)\./;
		my $spc = $ar[0];#$1;
		if (defined($hs_cons{$consid}{$spc})) {
			my $rar = $hs_cons{$consid}{$spc};
			push(@$rar, "$_");
		} else {
			$hs_cons{$consid}{$spc} = [$_];
		}
	}
}
close(F);

# read adj. score file
my %hs_scores = ();
open(F,"$adjs_f");
while(<F>) {
	chomp;
	my ($bid1, $bid2, $score) = split(/\s+/);	
	$hs_scores{$bid1}{$bid2} = $score;
	$hs_scores{-1*$bid2}{-1*$bid1} = $score;
}
close(F);

# create dynamic filehandles
my %fh = ();
foreach my $spc (@spcs) {
	open($fh{$spc}, ">$out_dir/APCF_$spc.map") or die "open $out_dir/APCF_$spc.map: $!";
}

my $apcfid = 0;
my $bnum = 1;
open(F,"$apcf_f");
while(<F>) {
	chomp;
	if ($_ =~ /^>/) { next; }
	if ($_ =~ /^# APCF (\d+)/) {
		$apcfid = $1;
	} else {
		my @bids = split(/\s+/);
		pop(@bids);	# remove the last $ symbol	
		my $astart = 0;
		my $aend = 0;
		my $pbid = 0;
		my $paend = 0;
		for (my $i = 0; $i <= $#bids; $i++) {
			my $bid = $bids[$i];

			my $scnt = 0;
			foreach my $spc (@spcs) {
				my $rar_spcstr = $hs_cons{abs($bid)}{$spc};
				if (!defined($rar_spcstr)) { next; }
				
				if ($scnt == 0) {
					# refspc
					$$rar_spcstr[0] =~ /:(\S+)\-(\S+) (\S)/;
					my ($start, $end, $dir) = ($1, $2, $3);
					$aend = $astart + ($end - $start);

					if ($pbid != 0) {
						my $adjscore = $hs_scores{$pbid}{$bid};
						if (!defined($adjscore)) {
							$adjscore = $hs_adjscores{$pbid}{$bid}; 
						}
						my $new_astart = $astart + 1;
					}
				}

				my @newar = ();
				if ($bid > 0) {
					@newar = @$rar_spcstr;
				} else {
					# revese block directions
					my $numelt = scalar(@$rar_spcstr);
					for (my $ai = $numelt-1; $ai >= 0; $ai--) {
						my $spcstr = $$rar_spcstr[$ai];
						my ($crds, $dir) = split(/\s+/, $spcstr);
						my $rdir = "-";
						if ($dir eq "-") { $rdir = "+"; }
						push(@newar, "$crds $rdir");
					}	
				}
		
				my $nfh = $fh{$spc};
				print $nfh ">$bnum\n";
				print $nfh "APCF.$apcfid:$astart-$aend +\n";
				foreach my $spcstr (@newar) {
					print $nfh "$spcstr\n";
				}
				print $nfh "\n";

				$scnt++;
			}
			
			$astart = $aend;
			$bnum++;
			$pbid = $bid;
			$paend = $aend;
		}
	}	
}
close(F);

## ingroup
foreach my $spc (@spcs) {
	close($fh{$spc}) or die "close APCF_$spc.map: $!";
}
