#!/usr/bin/perl

use strict;
use warnings;
use List::Util qw[min max];

my $anc_spc = shift; 
my $ref_spc = shift;
my $out_spc = shift;
my $src_f = shift;  
my $tar_f = shift;  

open(F,"$src_f");
my @lines = <F>;
close(F);
chomp(@lines);

my %refpos = ();
my %tardirs = ();
for (my $i = 0; $i <= $#lines; $i++) {
	if ($lines[$i] !~ /^>/) { next; }

	my $refline = $lines[$i+1];
	my $tarline = $lines[$i+2];
	$tarline =~ /$ref_spc\.(\S+):(\S+)\-(\S+) (\S+)/;
	my ($tchr, $tstart, $tend, $tdir) = ($1, $2, $3, $4);
	my $key = "$ref_spc.$tchr:$tstart-$tend"; 
	$refpos{$key} = $refline;
	$tardirs{$key} = $tdir;
}

open(F,"$tar_f");
@lines = <F>;
close(F);
chomp(@lines);

my %hs_outs = ();
my @lines_new = ();
for (my $i = 0; $i <= $#lines; $i++) {
	if ($lines[$i] !~ /^>/) { next; }

	$lines[$i+1] =~ /$out_spc\.(\S+):(\S+)\-(\S+) (\S+)/;
	my ($ochr, $ostart, $oend, $odir) = ($1,$2,$3,$4);		
	
	$lines[$i+2] =~ /$ref_spc\.(\S+):(\S+)\-(\S+) (\S+)/;
	my ($rchr, $rstart, $rend, $rdir) = ($1,$2,$3,$4);		
	my $key = "$ref_spc.$rchr:$rstart-$rend";
	my $rec_line = $refpos{$key};
	my $rec_dir = $tardirs{$key};

	my $out = "$rec_line\n";
	$rec_line =~ /$anc_spc\.(\S+):(\S+)\-(\S+) (\S+)/;
	my ($recchr, $recstart, $recend, $recdir) = ($1,$2,$3,$4);		
	
	my $newdir = $odir;
	if ($rec_dir ne $rdir) { 
		if ($newdir eq "+") { $newdir = "-"; }
		else { $newdir = "+"; }
	}
	
	$out .= "$out_spc.$ochr:$ostart-$oend $newdir\n\n";	
	my $newkey = "$recchr:$recstart-$recend";
	$hs_outs{$newkey} = $out;
}

my $segid = 1;
foreach my $key (sort my_sort keys %hs_outs) {
    my $out = $hs_outs{$key};
    print ">$segid\n";
    print "$out";
    $segid++;
}

sub my_sort {
    $a =~ /(\S+):(\S+)\-(\S+)/;
    my ($scf1, $start1, $end1) = ($1,$2,$3);
    $b =~ /(\S+):(\S+)\-(\S+)/;
    my ($scf2, $start2, $end2) = ($1,$2,$3);

    return -1 if ($scf1 < $scf2);
    return 1 if ($scf1 > $scf2);
    return -1 if ($start1 < $start2);
    return 1 if ($start2 < $start1);
    return 0;
}

