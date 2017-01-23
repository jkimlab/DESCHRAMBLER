#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib/perl";
use Bio::TreeIO;
use Array::Utils qw(:all);

my $join_f = shift;
my $sf_dir = shift;
my $outjoin_f = shift;
my $split_f = shift;

my $MIN_OCNT_FRAC = 0.1;
my $MIN_OCNT = 2;
my $MIN_ICNT = 2;
my $MIN_ICNT_FRAC = 0.2;

# read species information
my @ingroup = ();
my @outgroup = ();
my @allspc = read_spcinfo("$sf_dir/config.file", \@ingroup, \@outgroup);

# read join information
my %hs_join = ();
read_joininfo("$sf_dir", \@allspc, \%hs_join);

open(O,">$outjoin_f");
open(OS, ">$split_f");

print OS "#bid1\tbid2\tingroup_cnt\toutgroup_cnt\n";

my $newid = 1;
open(F,"$join_f");
while(<F>) {
    chomp;
    if ($_ =~ /^>/) {
        print O "$_\n";
    } elsif ($_ =~ /^#/) {
    } else {
        my @ar = split(/\s+/);
        pop(@ar);
        my @splitpoints = ();
        for (my $i = 0; $i < $#ar; $i++) {
            my $bid1 = $ar[$i];
            my $bid2 = $ar[$i+1];

			my $injoin = get_joinspc("$bid1:$bid2", \@ingroup, \%hs_join);
			my $outjoin = get_joinspc("$bid1:$bid2", \@outgroup, \%hs_join);

			my ($incnt, $outcnt) = (0, 0);
			if (length($injoin) > 0) {
				my @artmp = split(/,/, $injoin);
				$incnt = scalar(@artmp);
			}
			if (length($outjoin) > 0) {
				my @artmp = split(/,/, $outjoin);
				$outcnt = scalar(@artmp);
			}

			my $outcntfrac = $outcnt/scalar(@outgroup);
			my $incntfrac = $incnt / scalar(@ingroup);

			if ($incnt == 0 || ($incnt == 1 && $outcnt == 0)) {
				push(@splitpoints, $i+1);
				print OS "$bid1\t$bid2\t$incnt\t$outcnt\n";
			}
        }
        
		if (scalar(@splitpoints) == 0) {
            print O "# APCF $newid\n";
            print O "$_\n";
            $newid++;
        } else {
            my $psp = 0;
            foreach my $sp (@splitpoints, scalar(@ar)) {
                print O "# APCF $newid\n";
                $newid++;
                for (my $i = $psp; $i < $sp; $i++) {
                    my $bid = $ar[$i];
                    print O "$bid ";
                }
                print O "\$\n";
                $psp = $sp;
            }
        }
    }
}                                                             
close(F);  
close(O);
close(OS);

##########
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
        return substr($spcjoin, 0, length($spcjoin)-1);
    }                                                            
}                                            
