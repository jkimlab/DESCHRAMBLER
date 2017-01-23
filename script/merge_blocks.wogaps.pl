#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw($Bin);

my $resolution = shift;
my $ancspc = shift;
my $config_f = shift;
my $data_dir = shift;

my $refspc = "";
my @spcs = ();
my @ospcs = ();
open(F,"$config_f");
while(<F>) {
    chomp;
    if (length($_) == 0 || $_ =~ /^#/) { next; }
    if ($_ =~ /^(\S+)\s+(\d)/) {
		my ($spc, $type) = ($1, $2);
        if ($type == 0 || $type == 1) { push(@spcs, $1); }
        elsif ($type == 2) { push(@ospcs, $1); }

		if ($type == 0) { $refspc = $1; }
    }
}
close(F);

# ingroup
foreach my $spc (@spcs) {
	if ($spc eq $refspc) {
		`$Bin/merge_pos3ex.ref.wogaps.pl $resolution $ancspc $spc $data_dir/APCF_$spc.map > $data_dir/APCF_$spc.merged.map`;
	} else {
		`$Bin/merge_pos3ex.wogaps.pl $resolution $ancspc $spc $data_dir/APCF_$refspc.map $data_dir/APCF_$spc.map > $data_dir/APCF_$spc.merged.map`; 	
	}
}
# outgroup
foreach my $spc (@ospcs) {
	`$Bin/split_ospc_map.pl APCF $data_dir/APCF_$spc.map > $data_dir/APCF_$spc.map.split`;
	`$Bin/merge_pos3ex.ref.wogaps.pl $resolution $ancspc $spc $data_dir/APCF_$spc.map.split > $data_dir/APCF_$spc.merged.map`; 	
}

