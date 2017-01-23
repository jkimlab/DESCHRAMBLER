#!/usr/bin/perl

use strict;
use warnings;

my $apcf_f = shift;	
my $sf_dir = shift;	

# read species information
my @ingroup = ();
my @outgroup = ();
my @allspc = read_spcinfo("$sf_dir/config.file", \@ingroup, \@outgroup);

# read join information
my %hs_join = ();
read_joininfo("$sf_dir", \@allspc, \%hs_join);

# read adj scores for species 
my %hs_scores = ();
open(F, "$sf_dir/block_consscores.txt");
while(<F>) {
	chomp;
	my ($bid1, $bid2, $score) = split(/\s+/);
	my ($rbid1, $rbid2) = (-1*$bid1, -1*$bid2);

	$hs_scores{"$bid1:$bid2"} = $score;
	$hs_scores{"$rbid2:$rbid1"} = $score;		
}
close(F);

# process merged map file
open(F, "$apcf_f");
while(<F>) {
	chomp;
	if ($_ =~ /^>/ || $_ =~ /^#/) { next; }

	my @ar = split(/\s+/);
	pop(@ar);
	for (my $i = 0; $i <$#ar; $i++) {
		my $bid1 = $ar[$i];
		my $bid2 = $ar[$i+1];
	
		my $injoin = get_joinspc("$bid1:$bid2", \@ingroup, \%hs_join);
		my $outjoin = get_joinspc("$bid1:$bid2", \@outgroup, \%hs_join);
		my $score = $hs_scores{"$bid1:$bid2"};

		my ($incnt, $outcnt) = (0, 0);
		if (length($injoin) > 0) {
			my @artmp = split(/,/, $injoin);
			$incnt = scalar(@artmp);
		}
		if (length($outjoin) > 0) {
			my @artmp = split(/,/, $outjoin);
			$outcnt = scalar(@artmp);
		}

		print "($bid1:$bid2)\t$score\t$incnt\t$outcnt\t$injoin\t$outjoin\n";
	}	
}
close(F);


#########
sub read_idmap {
	my $f = shift;
	my $rhs = shift;

	open(F, "$f");
	while(<F>) {
		chomp;
		my @ar = split(/\s+/);
		for (my $i = 1; $i <= $#ar; $i++) {
			$$rhs{$ar[$i]} = $ar[0];
		}
	}
	close(F);
}

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

sub read_joininfo {
	my $dir = shift;
	my $rar_allspc = shift;
	my $rhs_join = shift;

	foreach my $spc (@$rar_allspc) {
		my $f = "$dir/$spc.joins";
		open(F, "$f");
		while(<F>) {
			chomp;
			if (length($_) == 0 || $_ =~ /^#/) { next; }
			my $line = $_;
			#trimming
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;

			my ($bid1, $bid2) = split(/\s+/, $line);
			my ($rbid1, $rbid2) = (-1*$bid1, -1*$bid2);
			$$rhs_join{$spc}{"$bid1:$bid2"} = 1;
			$$rhs_join{$spc}{"$rbid2:$rbid1"} = 1;	
		}
		close(F);
	}
}

sub get_joinspc {
	my $key = shift;
	my $rar_spc = shift;
	my $rhs_join = shift;

	my $spcjoin = "";
	foreach my $spc (@$rar_spc) {
		if (defined($$rhs_join{$spc}{$key})) {
			my $spcname = $spc;
			$spcjoin .= "$spcname,";
		}
	}

	if (length($spcjoin) == 0) {
		return "";
	} else {
		# remove the last ,
		return substr($spcjoin, 0, length($spcjoin)-1);
	}
}
