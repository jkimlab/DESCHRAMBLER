#!/usr/bin/perl 

use strict;
use warnings;

my $config_f = shift;
my $out_dir = shift;

my @ingroup = ();
my @outgroup = ();
open(F,"$config_f");
while(<F>) {
    chomp;
    if (length($_) == 0 || $_ =~ /^#/) { next; }
    if ($_ =~ /^(\S+)\s+(\d)/) {
        my ($spc, $type) = ($1, $2);
        if ($type == 0 || $type == 1) { push(@ingroup, $1); }
		elsif ($type == 2) { push(@outgroup, $1); }
		else {
			print STDERR "Parse error: $config_f\n";
			die;
		}
    }
}
close(F);

open(O,">$out_dir/ingroup.txt");
foreach my $spc (@ingroup) {
	print O "$spc\n";
}
close(O);
open(O,">$out_dir/outgroup.txt");
foreach my $spc (@outgroup) {
	print O "$spc\n";
}
close(O);
