#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
use Cwd 'abs_path';
use FindBin qw($Bin);

my $tree_f = shift;
my $resolution = shift;
my $ref_spc = shift;
my $min_adj_scr = shift;
my $src_dir = shift;
my $out_dir = shift;

$tree_f = abs_path($tree_f);
system("mkdir -p $out_dir");

# extract outgroup species: ingroup.txt outgroup.txt
`$Bin/ext_spcgroups.pl $src_dir/config.file $src_dir`;

# estimate breakpoint distance
if (-f "$src_dir/bpdist.txt") { `rm $src_dir/bpdist.txt`; } 
`$Bin/estimate_bpdist4.pl $src_dir/ingroup.txt $src_dir/outgroup.txt $ref_spc $src_dir $src_dir/bpdist.txt`;

# check tree.txt file
if (!(-f "$tree_f")) {
	print STDERR "File doesn't exist: $tree_f\n";
	die;
}

my $tout = `cat $tree_f`;
print STDERR "TREE $tout\n";

# eatimate JC model parameter
open(F,"$src_dir/$ref_spc.joins");
my $tmp = <F>;
close(F);
chomp($tmp);
my $numblocks = substr($tmp, 1);
my $jkalpha = `$Bin/estparJC.pl $numblocks $ref_spc $tree_f $src_dir/bpdist.txt`;
chomp($jkalpha);
print STDERR "Estimate JC parameter: $jkalpha\n";

# create new genome file
`$Bin/create_gfile.pl $src_dir`;

# compute adjacency probabilities
my $curdir = getcwd;
chdir($src_dir);

`$Bin/../code/inferAdjProb $ref_spc $jkalpha $tree_f Genomes.Order`; 

chdir($curdir);

# refine adjacency probabilities
`$Bin/refine_adjprob.pl $src_dir/adjacencies.prob > $src_dir/block_consscores.txt`;

`$Bin/../code/deschrambler $min_adj_scr $src_dir/block_consscores.txt $out_dir/Ancestor.APCF.partial $out_dir/Ancestor.ADJS`;

`$Bin/add_missing_blocks.pl $src_dir/block_list.txt $out_dir/Ancestor.APCF.partial > $out_dir/Ancestor.APCF.tmp1`;

`$Bin/split_weak_joins.pl $out_dir/Ancestor.APCF.tmp1 $src_dir $out_dir/Ancestor.APCF.tmp2 $out_dir/Ancestor.splits`;
`$Bin/join_splits.pl $min_adj_scr $tree_f $out_dir/Ancestor.APCF.tmp2 $src_dir $out_dir/Ancestor.splits > $out_dir/Ancestor.APCF.unordered`;

`$Bin/sort_apcfs.pl $ref_spc $out_dir/Ancestor.APCF.unordered $src_dir/Conserved.Segments > $out_dir/Ancestor.APCF`; 

`$Bin/ext_join_info.pl $out_dir/Ancestor.APCF $src_dir/ > $out_dir/Ancestor.joins`; 

`$Bin/../code/makeBlocks/createCarFile $out_dir/SFs/config.file $out_dir/Ancestor.APCF $out_dir/SFs/Conserved.Segments > $out_dir/APCFs`;

# create mapping files
my $shortres = int($resolution/1000);
`$Bin/create_mapfile.pl $src_dir/config.file $src_dir/Conserved.Segments $src_dir/block_consscores.txt $out_dir/Ancestor.APCF $out_dir/Ancestor.ADJS $out_dir/`;

# merge blocks in mapping files
`$Bin/merge_blocks.wogaps.pl $resolution APCF $out_dir/SFs/config.file $out_dir/`;
`$Bin/compute_size.pl APCF $out_dir/APCF_$ref_spc.merged.map > $out_dir/APCF_size.txt`;

