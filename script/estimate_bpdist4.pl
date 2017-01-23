#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw($Bin);
use Cwd;

my $inspc_f = shift;
my $outspc_f = shift;
my $ref_spc = shift;
my $data_dir = shift;
my $out_f = shift;

open(F,"$inspc_f");
my @inspcs = <F>;
close(F);
chomp(@inspcs);

open(F,"$outspc_f");
my @outspcs = <F>;
close(F);
chomp(@outspcs);

push(@inspcs, @outspcs);
my %hs_outspcs = ();
foreach my $ospc (@outspcs) {
	$hs_outspcs{$ospc} = 1;
}
	
`echo "#species\tnum" >> $out_f`;

my $curdir = getcwd;
foreach my $tar_spc (@inspcs) {
	if ($tar_spc eq $ref_spc) { next; }
	my $out_dir = "$data_dir/SFs_$tar_spc";
	`mkdir -p $out_dir`;
	`cp $data_dir/Makefile $out_dir/`;

	my $sedstr = "sed ";
	foreach my $spc (@inspcs) {
		if ($spc eq $ref_spc || $spc eq $tar_spc) { next; }
		$sedstr .= "-e 's:^$spc"."[[:space:]][[:space:]]*:#$spc :' ";
	}

	`$sedstr $data_dir/config.file > $out_dir/config.file`;

	if (defined($hs_outspcs{$tar_spc})) {
		`sed -e 's:${tar_spc}[[:space:]][[:space:]]*2:$tar_spc 1:' $out_dir/config.file > $out_dir/config.file.new`;
		`mv $out_dir/config.file.new $out_dir/config.file`;	
	}

	`cp $data_dir/Makefile $out_dir/`;

	chdir($out_dir);
	`make pair`;
	
	open(F,"Genomes.Order");
	my $num_tarscf = 0;
	my $num_sf = 0;
	my $flag = "";
	while(<F>) {
		chomp;
		if (length($_) == 0 || $_ =~ /^#/) { next; }
		if ($_ =~ /^>$ref_spc\s+(\d+)/) {
			$flag = "ref";
		} elsif ($_ =~ /^>$tar_spc\s+(\d+)/) {
			$flag = "tar";
			$num_tarscf = $1;
		} else {
			if ($flag eq "ref") {
				my @ar = split(/\s+/);
				pop(@ar);
				my $num = $ar[-1];
				if ($num > $num_sf) { $num_sf = $num; }	
			}
		}
	}	
	close(F);
	chdir($curdir);

	my $dist = $num_sf - $num_tarscf;
	`echo "$tar_spc\t$dist" >> $out_f`;
}
