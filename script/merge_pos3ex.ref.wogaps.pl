#!/usr/bin/perl

use strict;
use warnings;
use List::Util qw(min max);

my $resolution = shift;
my $ref_prefix = shift;
my $tar_prefix = shift;
my $src_f = shift;

my $ref_prefix_str = $ref_prefix;

my %hs_blockpos = ();
open(F,"$src_f");
while(<F>) {
	chomp;
	if ($_ =~ /$tar_prefix\.(\S+):(\S+)\-(\S+) (\S+)/) {
		my $chr = $1;
		my $start = $2;
		my $end = $3;
		my $dir = $4;
		$hs_blockpos{$chr}{$start} = $end;
	}
}
close(F);

open(F,"$src_f");
my @lines = <F>;
close(F);
chomp(@lines);

my $segid = 1;
my ($prchr, $prstart, $prend, $prdir) = ("", "", "", "");
my ($ptchr, $ptstart, $ptend, $ptdir) = ("", "", "", "");
my $ptsub_start = -1;
for (my $i = 0; $i <= $#lines; $i++) {
	if ($lines[$i] !~ /^>/) { next; }
	my $ref_line = $lines[$i+1];
	$ref_line =~ /$ref_prefix\.(\S+):(\S+)\-(\S+) (\S+)/;
	my ($ref_chr, $ref_start, $ref_end, $ref_dir) = ($1, $2, $3, $4);
	my $tar_line = $lines[$i+2];
	$tar_line =~ /$tar_prefix\.(\S+):(\S+)\-(\S+) (\S+)/;
	my ($tar_chr, $tar_start, $tar_end, $tar_dir) = ($1, $2, $3, $4);

	if (length($prchr) > 0 && $prchr ne $ref_chr) {
		print ">$segid\n";
		print "$ref_prefix_str.$prchr:$prstart-$prend $prdir\n";
		print "$tar_prefix.$ptchr:$ptstart-$ptend $ptdir\n\n";
		
		$segid++;
		($prchr, $prstart, $prend, $prdir) = ($ref_chr, $ref_start, $ref_end, $ref_dir);
		($ptchr, $ptstart, $ptend, $ptdir) = ($tar_chr, $tar_start, $tar_end, $tar_dir);
		$ptsub_start = $ptstart;
	} elsif (length($prchr) == 0) {
		($prchr, $prstart, $prend, $prdir) = ($ref_chr, $ref_start, $ref_end, $ref_dir);
		($ptchr, $ptstart, $ptend, $ptdir) = ($tar_chr, $tar_start, $tar_end, $tar_dir);
		$ptsub_start = $ptstart;
	} else {
		if ($ptchr ne $tar_chr || $ptdir ne $tar_dir) {
			print ">$segid\n";
			print "$ref_prefix_str.$prchr:$prstart-$prend $prdir\n";
			print "$tar_prefix.$ptchr:$ptstart-$ptend $ptdir\n\n";
			
			$segid++;
			($prchr, $prstart, $prend, $prdir) = ($ref_chr, $ref_start, $ref_end, $ref_dir);
			($ptchr, $ptstart, $ptend, $ptdir) = ($tar_chr, $tar_start, $tar_end, $tar_dir);
			$ptsub_start = $ptstart;
		} else {
			# check the continuity of two blocks
			die if ($ptchr ne $tar_chr);
			my $bindex1 = get_ordernum($hs_blockpos{$tar_chr}, $ptsub_start);
			my $bindex2 = get_ordernum($hs_blockpos{$tar_chr}, $tar_start);

			if (abs($bindex1 - $bindex2) != 1) {
				print ">$segid\n";
				print "$ref_prefix_str.$prchr:$prstart-$prend $prdir\n";
				print "$tar_prefix.$ptchr:$ptstart-$ptend $ptdir\n\n";
			
				$segid++;
				($prchr, $prstart, $prend, $prdir) = ($ref_chr, $ref_start, $ref_end, $ref_dir);
				($ptchr, $ptstart, $ptend, $ptdir) = ($tar_chr, $tar_start, $tar_end, $tar_dir);
				$ptsub_start = $ptstart;
			} else {
				
				if ($tar_dir eq "+") {
                    my $pmin = min($ptstart, $ptend, $tar_start, $tar_end);
                    my $pmax = max($ptstart, $ptend, $tar_start, $tar_end);
                    if ($pmin == $ptstart && $pmax == $tar_end) {
                        $ptsub_start = $tar_start;
                        $prend = $ref_end;
                        $ptend = $tar_end;
                    } else {
                        print ">$segid\n";
                        print "$ref_prefix_str.$prchr:$prstart-$prend $prdir\n";
                        print "$tar_prefix.$ptchr:$ptstart-$ptend $ptdir\n\n";

                        $segid++;
                        ($prchr, $prstart, $prend, $prdir) = ($ref_chr, $ref_start, $ref_end, $ref_dir);
                        ($ptchr, $ptstart, $ptend, $ptdir) = ($tar_chr, $tar_start, $tar_end, $tar_dir);
                        $ptsub_start = $ptstart;
                    }
                } else {
                    my $pmin = min($ptstart, $ptend, $tar_start, $tar_end);
                    my $pmax = max($ptstart, $ptend, $tar_start, $tar_end);
                    if ($pmin == $tar_start && $pmax == $ptend) {
                        $ptsub_start = $tar_start;
                        $prend = $ref_end;
                        $ptstart = $tar_start;
                    } else {
                        print ">$segid\n";
                        print "$ref_prefix_str.$prchr:$prstart-$prend $prdir\n";
                        print "$tar_prefix.$ptchr:$ptstart-$ptend $ptdir\n\n";

                        $segid++;
                        ($prchr, $prstart, $prend, $prdir) = ($ref_chr, $ref_start, $ref_end, $ref_dir);
                        ($ptchr, $ptstart, $ptend, $ptdir) = ($tar_chr, $tar_start, $tar_end, $tar_dir);
                        $ptsub_start = $ptstart;
                    }
                }
			}
		}	
	}	
}
				
print ">$segid\n";
print "$ref_prefix_str.$prchr:$prstart-$prend $prdir\n";
print "$tar_prefix.$ptchr:$ptstart-$ptend $ptdir\n\n";

sub get_ordernum {
	my $rhs_pos = shift;
	my $bstart = shift;

	my @rstarts = sort {$a<=>$b} keys %$rhs_pos;
	my $i = 0;
	for ( ; $i <= $#rstarts; $i++) {
		if ($bstart == $rstarts[$i]) { last; }
	}
	return $i;
}
