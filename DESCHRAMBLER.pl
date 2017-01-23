#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw($Bin);
use Cwd;
use Cwd 'abs_path';

# check the number of argument
if ($#ARGV+1 != 1) {
	print STDERR "Usage: ./DESCHRAMBLER.pl <parameter file>\n";
	exit(1);
}

my $params_f = $ARGV[0];

# parse parameter file
my %params = ();
open(F,"$params_f");
while(<F>) {
	chomp;
	my $line = trim($_);
	if ($line =~ /^#/ || $line eq "") { next; }
	my ($name, $value) = split(/=/);
	$name = trim($name);
	$value = trim($value);
	if (-f $value || -d $value) {
		$params{$name} = abs_path($value);
	} else {
		$params{$name} = $value;
	}
}
close(F);

check_parameters(\%params);

my $sf_dir = $params{"OUTPUTDIR"}."/SFs";
`mkdir -p $params{"OUTPUTDIR"}`;

# make blocks
print STDERR "\n## Constructing syntenic fragments ##\n"; 
my $cwd = getcwd();
`mkdir -p $sf_dir`;
`sed -e 's:<resolutionwillbechanged>:$params{"RESOLUTION"}:' $params{"CONFIGSFSFILE"} > $sf_dir/config.file`;
`sed -e 's:<willbechanged>:$Bin/code/makeBlocks:;s:<treewillbechanged>:$params{"TREEFILE"}:' $params{"MAKESFSFILE"} > $sf_dir/Makefile`;
#}
chdir($sf_dir);
`make all`;

chdir($cwd);
`$Bin/script/create_blocklist.pl $params{"REFSPC"} $sf_dir`; 

# reconstruct APCFs
`$Bin/script/wrap_recon_apcf.pl $params{"TREEFILE"} $params{"RESOLUTION"} $params{"REFSPC"} $params{"MINADJSCR"} $sf_dir $params{"OUTPUTDIR"}`; 

###############################################################
sub check_parameters {
	my $rparams = shift;
	my $flag = 0;
	my $out = "";
	my @parnames = ("REFSPC","OUTPUTDIR","RESOLUTION","TREEFILE","CONFIGSFSFILE","MAKESFSFILE","MINADJSCR"); 

	foreach my $pname (@parnames) {
		if (!defined($$rparams{$pname})) {
			$out .= "$pname "; 
			$flag = 1;
		}
	}

	if ($flag == 1) {
		print STDERR "missing parameters: $out\n";
		exit(1);
	}	
}

sub trim {
	my $str = shift;
	$str =~ s/^\s+//;
	$str =~ s/\s+$//;
	return $str;
}
