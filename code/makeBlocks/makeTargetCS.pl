#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../../lib/perl";
use Bio::TreeIO;
use Array::Utils qw(:all);
use List::Util qw(max);

my $config_f = shift;
my $tree_f = shift;
my $cs_f = shift;

# read species information
my @ingroup = ();
my @outgroup = ();
my @allspcs = read_spcinfo("$config_f", \@ingroup, \@outgroup);

# read tree
my $treein = new Bio::TreeIO(-format => "newick", -file => "$tree_f");
my $alltree = $treein->next_tree;

my $root = $alltree->get_root_node();
my $rootnid = $root->internal_id;

my $taranc = $alltree->find_node(-id => "@");
my $tarnid = $taranc->internal_id;

# create a new subtree with $taranc as a root
my $subtree = Bio::Tree::Tree->new(-root => $taranc, -nodelete => 1);

# read conserved segments
my %cs_list = ();
my %tmp_list = ();
my $csid = "";
open(F,"$cs_f");
while(<F>) {
	chomp;
	if (length($_) == 0) {
		foreach my $spc (@allspcs) {
			my $rar = $tmp_list{$spc};
			if (!defined($rar)) { next; }
			my @ar = ($$rar[0], $$rar[-1]);
			$cs_list{$csid}{$spc} = \@ar;

		}
		%tmp_list = ();
	}

	if ($_ =~ /^>(\S+)/) {
		$csid = $1;
	} elsif ($_ =~ /(\S+)\.(\S+):(\S+)\-(\S+) (\S+)/) {
		my ($spc, $chr, $start, $end, $str) = ($1,$2,$3,$4,$5);	
			if (defined($tmp_list{$spc})) {
				my $rar = $tmp_list{$spc};
				push(@$rar, $chr);
			} else {
				my @ar = ($chr);
				$tmp_list{$spc} = \@ar;
			}
	} 

}
close(F);

my %exist_csid = ();
foreach my $csid (sort {$a<=>$b} keys %cs_list) {
	my $rhs = $cs_list{$csid};

	my %hs_leaf_ext = ();
	foreach my $spc (@allspcs) {
		if (defined($$rhs{$spc})) {
			$hs_leaf_ext{$spc} = 1;
		} else {
			$hs_leaf_ext{$spc} = 0;
		}
	} 

	my %hs_out = ();
	my ($ancext, $firstext) = num_ancext($alltree, \%hs_leaf_ext, \%hs_out); 
	my $rootar = $hs_out{$rootnid};
	
	my %tar_exts = ();
	foreach my $root_ext (@$rootar) {
		my %hs_ext_assn = ();
		assign_ancext($alltree, $root_ext, \%hs_out, \%hs_ext_assn);
		my $tar_ext = $hs_ext_assn{$tarnid};
		$tar_exts{$tar_ext} = 1;
	} 

	my @tar_out = keys %tar_exts;
	if (scalar(@tar_out) == 1 && $tar_out[0] == 1) {
		$exist_csid{$csid} = 1;
	}
}

my $new_csid = 1;
$csid = "";
my $cs_lines = "";
open(F,"$cs_f");
while(<F>) {
    chomp;
    if (length($_) == 0) {
		if (defined($exist_csid{$csid})) {
			print ">$new_csid\n";
			print "$cs_lines\n";	
			$new_csid++;
		}

		$csid = 0; 
		$cs_lines = "";                                               
    }                                                                 
                                                                      
    if ($_ =~ /^>(\S+)/) {                                            
        $csid = $1;                                                   
    } elsif ($_ =~ /(\S+)\.(\S+):(\S+)\-(\S+) (\S+)/) {               
		$cs_lines .= "$_\n";
    }                                                                 
                                                                      
}                                                                     
close(F);                             

#########################################
sub read_spcinfo {
    my $f = shift;
    my $rar_ingroup = shift;
    my $rar_outgroup = shift;
    my @allspc = ();
    
    open(F, "$f");
    while (<F>) {
        chomp; 
        if ($_ =~ /^(\S+)\s+(\d+)/) {
            my ($spc, $flag) = ($1, $2);
            
            push(@allspc, $spc);
            
            if ($flag == 0 || $flag == 1) {
                push(@$rar_ingroup, $spc);
            } elsif ($flag == 2) {
                push(@$rar_outgroup, $spc);
            } else {
                die;
            }
        }
    }
    close(F);
    return @allspc;
}

sub rec_infer_ancadj {
	my $node = shift;
	my $rhs_leaf_adj = shift;	
	my $rhs_out_adjs = shift;	
		
	my $spcname = $node->id;	
	my $nid = $node->internal_id;

	if ($node->is_Leaf) {
		my $adj = $$rhs_leaf_adj{$spcname};	
		my @nar = ($adj);
		if ($adj == 2) { @nar = (0,1); }
		$$rhs_out_adjs{$nid} = \@nar;	
	} else {
		my @descs = $node->each_Descendent;
		foreach my $desc (@descs) {
			rec_infer_ancadj($desc, $rhs_leaf_adj, $rhs_out_adjs);
		}

		my $nid1 = $descs[0]->internal_id;
		my $nid2 = $descs[1]->internal_id;
		my $rar1 = $$rhs_out_adjs{$nid1};
		my $rar2 = $$rhs_out_adjs{$nid2};

		my @insec = intersect(@$rar1, @$rar2);
		if (scalar(@insec) > 0) {
			$$rhs_out_adjs{$nid} = \@insec;
		} else {
			my @union = unique(@$rar1, @$rar2);
			$$rhs_out_adjs{$nid} = \@union;
		} 
	}	
}

sub num_ancext {
	my $tree = shift;
	my $rhs_leaf_adj = shift;	
	my $rhs_out_adjs = shift;	

	my $root = $tree->get_root_node();
	my $spcname = $root->id;
	my $nid = $root->internal_id;
	rec_infer_ancadj($root, $rhs_leaf_adj, $rhs_out_adjs);
	my $rar = $$rhs_out_adjs{$nid};
	return (scalar(@$rar), $$rar[0]);	
}          

sub rec_assn_adjs {
	my $parent_adj = shift;
	my $node = shift;
	my $rhs_anc_adj = shift;	 
	my $rhs_assn_adjs = shift;	

	my $spcname = $node->id;
    my $nid = $node->internal_id;

	my $rar = $$rhs_anc_adj{$nid};
	my $current_adj = $parent_adj;
	if (scalar(@$rar) == 1) {
		$current_adj = $$rar[0];
	} 
	$$rhs_assn_adjs{$nid} = $current_adj;

    if ($node->is_Leaf) {
    } else {
        my @descs = $node->each_Descendent;
        foreach my $desc (@descs) {
            rec_assn_adjs($current_adj, $desc, $rhs_anc_adj, $rhs_assn_adjs);
        }
    }

}

sub assign_ancext {
	my $tree = shift;
	my $root_adj = shift;
	my $rhs_anc_adj = shift;	 
	my $rhs_assn_adjs = shift;	

	my $root = $tree->get_root_node();
	my $spcname = $root->id;
	my $nid = $root->internal_id;
	
	$$rhs_assn_adjs{$nid} = $root_adj;
	my @descs = $root->each_Descendent;
	foreach my $desc (@descs) {
		rec_assn_adjs($root_adj, $desc, $rhs_anc_adj, $rhs_assn_adjs);
	}
}          
