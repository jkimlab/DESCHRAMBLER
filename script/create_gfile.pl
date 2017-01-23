#!/usr/bin/perl

use strict;
use warnings;

my $data_dir = shift;

my $gorder_f = "$data_dir/Genomes.Order";
my $outgroup_f = "$data_dir/outgroup.txt";
my $newgorder_f = "$data_dir/Genomes.Order.new";

`cp $gorder_f $newgorder_f`;

open(F,"$outgroup_f");
my @outgroup = <F>;
close(F);
chomp(@outgroup);

foreach my $spc (@outgroup) {
	`echo ">$spc 0" >> $newgorder_f`;
	`echo "# in .joins file" >> $newgorder_f`;
	`echo "" >> $newgorder_f`;
}
