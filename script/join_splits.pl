#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib/perl";
use Bio::TreeIO;
use Array::Utils qw(:all);
use List::Util qw(max);

my $min_adj_scr = shift;
my $tree_f = shift;
my $join_f = shift;
my $sf_dir = shift;
my $splits_f = shift; 

my $ingroup_f = "$sf_dir/ingroup.txt";
my $outgroup_f = "$sf_dir/outgroup.txt";
my $cs_f = "$sf_dir/Conserved.Segments";
my $order_f = "$sf_dir/Genomes.Order";
my $adjscore_f = "$sf_dir/block_consscores.txt";

my $MIN_SCORE = $min_adj_scr;

# read species information
my @ingroup = ();
my @outgroup = ();
my @allspc = read_spcinfo("$sf_dir/config.file", \@ingroup, \@outgroup);

# read assembly information
my %hs_nonchrspc = ();
open(F, "$sf_dir/config.file");
while(<F>) {
	chomp;
	if ($_ =~ /(\S+)\s+(\d+)\s(\d+)/) {
		my ($spc, $tag, $chrassm) = ($1, $2, $3);
		if ($chrassm == 0) {
			$hs_nonchrspc{$spc} = 1;
		}
	}
}
close(F);

# read previously split points
my %hs_splits = ();
open(F,"$splits_f");
while(<F>) {
	chomp;
	if (length($_) == 0 || $_ =~ /^#/) { next; }
	my ($bid1, $bid2) = split(/\s+/);
	$hs_splits{$bid1}{$bid2} = 1;
	$hs_splits{-1*$bid2}{-1*$bid1} = 1;
}
close(F);

# read order file
my %hs_order = ();
my $orspc = "";
open(F,"$order_f");
while(<F>) {
	chomp;
	if (length($_) == 0 || $_ =~ /^#/) { next; }

	if ($_ =~ /^>(\S+)/) {
		$orspc = $1;
	} else {
		my @ar = split(/\s+/);
		pop(@ar);
		if (scalar(@ar) >= 2) {
			for (my $i = 0; $i < $#ar; $i++) {
				my $bid1 = $ar[$i];	
				my $bid2 = $ar[$i+1];
				$hs_order{$orspc}{$bid1} = $bid2;	
				$hs_order{$orspc}{-1*$bid2} = -1*$bid1;	
			}
		}
	}
}
close(F);

# read adj. scores
my %hs_adjscores = ();
open(F,"$adjscore_f");
while(<F>) {
	chomp;
	my ($bid1, $bid2, $score) = split(/\s+/);
	$hs_adjscores{$bid1}{$bid2} = $score;
	$hs_adjscores{-1*$bid2}{-1*$bid1} = $score;
}
close(F);

# read tree
my $treein = new Bio::TreeIO(-format => "newick", -file => "$tree_f");
my $alltree = $treein->next_tree;

my $root = $alltree->get_root_node();
my $rootnid = $root->internal_id;

my $taranc = $alltree->find_node(-id => "@");
my $tarnid = $taranc->internal_id;

# create a new subtree with $taranc as a root
my $subtree = Bio::Tree::Tree->new(-root => $taranc, -nodelete => 1);

# read ingroup species
my %ingrps = ();
open(F,"$ingroup_f");
while(<F>) {
	chomp;
	$ingrps{$_} = 1;
}
close(F);

# read outgroup species
my %outgrps = ();
open(F,"$outgroup_f");
while(<F>) {
	chomp;
	$outgrps{$_} = 1;
}
close(F);

my @allspcs = (keys %ingrps, keys %outgrps);

# read original join information
my %hs_leafjoins = ();
my %hs_leafbids = ();
foreach my $spc (@allspcs) {
	my $jf = "$sf_dir/$spc.joins";
	open(F, "$jf");
	while(<F>) {
		chomp;
		if ($_ =~ /^#/) { next; } 
		my $str = $_;
		$str =~ s/^\s+//;
		$str =~ s/\s+$//;
		my ($bid1, $bid2) = split(/\s+/, $str);

		if ($bid1 == 0 || $bid2 == 0) { next; }

		my ($rbid1, $rbid2) = (-1*$bid1, -1*$bid2);
		$hs_leafjoins{$spc}{$bid1} = $bid2;	
		$hs_leafjoins{$spc}{$rbid2} = $rbid1;	

		$hs_leafbids{$spc}{abs($bid1)} = 1;
		$hs_leafbids{$spc}{abs($bid2)} = 1;
	}
	close(F);
}

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

# read join file
my %hs_joins = ();
open(F,"$join_f");
my $join_header = <F>; 
chomp($join_header);
my $apcf_id = "";
while(<F>) {
	chomp;
	if ($_ =~ /^# APCF (\S+)/) {
		$apcf_id = $1;
	} else {
		my @ar = split(/\s+/);
		pop(@ar); # remove '$'
		$hs_joins{$apcf_id} = join(' ',@ar);
	}	
}
close(F);

my %hs_work = %hs_joins;
while(1) {
	my $changed = 0;
	my @apcfs = sort {$a<=>$b} keys %hs_work;
	for (my $ai = 0; $ai <= $#apcfs-1; $ai++) {
		my $join_i = $hs_work{$apcfs[$ai]};
		my @ari = split(/\s+/, $join_i);
		my ($fi, $bi) = ($ari[0], $ari[-1]);

		for (my $aj = $ai+1; $aj <= $#apcfs; $aj++) {
			my $join_j = $hs_work{$apcfs[$aj]};
			my @arj = split(/\s+/, $join_j);
			my ($fj, $bj) = ($arj[0], $arj[-1]);
		
			# check four cases
			my $score1 = check_join($bi, $fj);
			my $score2 = check_join($bi, -1*$bj);
			my $score3 = check_join(-1*$fi, $fj);
			my $score4 = check_join(-1*$fi, -1*$bj);

			my $smax = max($score1, $score2, $score3, $score4);
		
			if ($score1 > 0.0 && $score1 == $smax) {
				my $endscorei = $hs_adjscores{$bi}{0};
				my $endscorej = $hs_adjscores{0}{$fj};

					my $newjoin = "$join_i $join_j";
					delete $hs_work{$apcfs[$aj]};
					$hs_work{$apcfs[$ai]} = $newjoin;
					$changed = 1;
			} elsif ($score2 > 0.0 && $score2 == $smax) {
				my $endscorei = $hs_adjscores{$bi}{0};
				my $endscorej = $hs_adjscores{0}{-1*$bj};

					my $newjoin = $join_i;

					for (my $ak = $#arj; $ak >= 0; $ak--) {
						my $akid = $arj[$ak];
						$akid = -1*$akid;
						$newjoin = "$newjoin $akid"; 
					}
					delete $hs_work{$apcfs[$aj]};
					$hs_work{$apcfs[$ai]} = $newjoin;
					$changed = 1;	
			} elsif ($score3 > 0.0 && $score3 == $smax) {
				my $endscorei = $hs_adjscores{-1*$fi}{0};
				my $endscorej = $hs_adjscores{0}{$fj};

					my $newjoin = $join_j;

					for (my $ak = 0; $ak <= $#ari; $ak++) {
						my $akid = $ari[$ak];
						$akid = -1*$akid;
						$newjoin = "$akid $newjoin"; 
					}
					delete $hs_work{$apcfs[$aj]};
					$hs_work{$apcfs[$ai]} = $newjoin;
		
					$changed = 1;	
			} elsif ($score4 > 0.0 && $score4 == $smax) {
				my $endscorei = $hs_adjscores{-1*$fi}{0};
				my $endscorej = $hs_adjscores{0}{-1*$bj};

					my $newjoin = "";

					for (my $ak = $#ari; $ak >= 0; $ak--) {
						my $akid = $ari[$ak];
						$akid = -1*$akid;
						if ($ak == $#ari) { $newjoin = "$akid"; }
						else { $newjoin = "$newjoin $akid"; }
					}
				
					for (my $ak = $#arj; $ak >= 0; $ak--) {
						my $akid = $arj[$ak];
						$akid = -1*$akid;
						$newjoin = "$newjoin $akid"; 
					}

					delete $hs_work{$apcfs[$aj]};
					$hs_work{$apcfs[$ai]} = $newjoin;
					$changed = 1;
			}

			if ($changed == 1) { last; }
		} # for $aj 
			
		if ($changed == 1) { last; }
	} # for $ai

	if ($changed == 0) { last; }
} # end of while

# output the results
print "$join_header\n";
my $new_id = 1;
foreach my $key (keys %hs_work) {
	print "# APCF $new_id\n";
	my $join_str = $hs_work{$key};
	print "$join_str \$\n";
	$new_id++;
}

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

sub check_join {
	my $bid1 = shift;
	my $bid2 = shift;

	my $adjscore = $hs_adjscores{$bid1}{$bid2};
	if (!defined($adjscore) || $adjscore < $MIN_SCORE || defined($hs_splits{$bid1}{$bid2})) { 
		return 0.0; 
	}

	my ($incnt, $injoin) = get_joinspc($bid1, $bid2, \@ingroup, \%hs_leafjoins);
    my ($outcnt, $outjoin) = get_joinspc($bid1, $bid2, \@outgroup, \%hs_leafjoins);

	my %hs_leaf_adjs = ();
	foreach my $ospc (@allspcs) {
		my $join_flag = 2;
		if (!defined($hs_leafbids{$ospc}{abs($bid1)}) || !defined($hs_leafbids{$ospc}{abs($bid2)})) {
			# missing blocks	
			$join_flag = 2;
		} elsif (defined($hs_leafjoins{$ospc}{$bid1}) && $hs_leafjoins{$ospc}{$bid1} == $bid2) {
			$join_flag = 1;
		} else {
			if (defined($hs_nonchrspc{$ospc})) {
				my $tbid1 = $hs_leafjoins{$ospc}{$bid1};
				my $tbid2 = $hs_leafjoins{$ospc}{-1*$bid2};

				if (defined($tbid1) && $tbid1 != $bid2) {
					$join_flag = 0;
				} elsif (defined($tbid2) && $tbid2 != -1*$bid1) {
					$join_flag = 0;
				} else {	
					$join_flag = 2;
				}
			} else {
				$join_flag = 0; 
			}
		}

        $hs_leaf_adjs{$ospc} = $join_flag;
	}

	# at least one ingroup species should have join
	my $iflag = 0;
	my $icnt = 0;
	foreach my $inspc (keys %ingrps) {
		if (defined($hs_order{$inspc}{$bid1}) && $hs_order{$inspc}{$bid1} == $bid2) {
			$iflag = 1;
			$icnt++;
		}      	
	}
	if ($iflag == 0) { 
		return 0.0; 
	}	

	my %hs_adj_out = ();
	my ($ancadjs, $firstadj) = num_ancadj($subtree, \%hs_leaf_adjs, \%hs_adj_out); 

	if (($ancadjs == 1 && $firstadj == 1) || $ancadjs > 1) {
		my %hs_adj_out2 = ();
		my ($alladjs, $allfirstadj) = num_ancadj($alltree, \%hs_leaf_adjs, \%hs_adj_out2); 
		my $rootar = $hs_adj_out2{$rootnid};
	
		my @tar_adjs = ();
		foreach my $root_adj (@$rootar) {
			my %hs_adj_assn = ();
			assign_ancadj($alltree, $root_adj, \%hs_adj_out2, \%hs_adj_assn);
			my $tar_adj = $hs_adj_assn{$tarnid};
			push(@tar_adjs, $tar_adj);
		} 

		my $inconsistent = 0;
		# check consistency of results
		if (scalar(@tar_adjs) > 1) {
			if ($tar_adjs[0] != $tar_adjs[1]) {
				$inconsistent = 1;	
			}
		} 
			
		if (!$inconsistent && $tar_adjs[0] == 1) {
			return $adjscore;
		}

	}

	return 0.0;
}
        

##########

sub get_joinspc {
	my $kbid1 = shift;
	my $kbid2 = shift;
    my $rar_spc = shift;
    my $rhs_join = shift;

    my $spcjoin = "";
    foreach my $spc (@$rar_spc) {
        if (defined($$rhs_join{$spc}{$kbid1}) && $$rhs_join{$spc}{$kbid1} == $kbid2) {
            my $spcname = $spc;
            $spcjoin .= "$spcname,";
        }
    }

    my $numspc = 0;
    if (length($spcjoin) == 0) {
        return ($numspc, "");
    } else {
        my $outstr = substr($spcjoin, 0, length($spcjoin)-1);
        my @artmp = split(/,/, $outstr);
        $numspc = scalar(@artmp);
        return ($numspc, $outstr);
    }
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

sub num_ancadj {
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

sub assign_ancadj {
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
