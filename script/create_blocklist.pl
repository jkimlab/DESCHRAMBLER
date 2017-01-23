#!/usr/bin/perl

use strict;
use warnings;

my $spc = shift;
my $data_dir = shift;

my %data = ();
my %data_blockid = ();
my %data_dir = ();
my $f = "$data_dir/Conserved.Segments";
my $o = "$data_dir/block_list.txt";

my $blockid = -1;
my $rchr = "";
open(F,"$f");
while(<F>) {
	chomp;

	if ($_ =~ /^>/) {
		$blockid = substr($_,1);
	} elsif ($_ =~ /^$spc\.(\S+):(\S+)\-(\S+) (\S+)/) {
		my ($scf, $start, $end, $dir) = ($1,$2,$3,$4);
		$data{$scf}{$start} = $end;	
		$data_blockid{$scf}{$start} = $blockid;	
		$data_dir{$scf}{$start} = $dir;	
	}
}
close(F);

open(O,">$o");
foreach my $scf (sort keys %data) {
	my $rhs = $data{$scf};
	foreach my $start (sort {$a<=>$b} keys %$rhs) {
		my $end = $$rhs{$start};
		my $blockid = $data_blockid{$scf}{$start};
		my $dir = $data_dir{$scf}{$start};
		print O "$scf\t$start\t$end\t$dir\t$blockid\n";
	} 
}
close(O);
