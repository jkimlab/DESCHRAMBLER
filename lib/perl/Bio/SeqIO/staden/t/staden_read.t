# -*-Perl-*-
## Bioperl Test Harness Script for Modules
## $Id: test.pl,v 1.2 2002/07/11 12:18:50 amackey Exp $
#

use strict;
use vars qw($DEBUG @BASEDIR @FORMATS $formatlooptests $ztrlooptests);

$DEBUG = $ENV{'BIOPERLDEBUG'};

sub BEGIN {

    @BASEDIR = ('.');

    use Bio::Root::IO;
    splice(@INC, 2, 1, Bio::Root::IO->catfile(@BASEDIR));

    # to handle systems with no installed Test module
    # we include the t dir (where a copy of Test.pm is located)
    # as a fallback
    eval { require Test; };
    if( $@ ) {
        unshift @INC, Bio::Root::IO->catfile(@BASEDIR, 't');
    }
    use Test;

    @FORMATS = qw(abi alf ctf pln exp ztr);

    $formatlooptests = 12;
    $ztrlooptests = 7;
    plan tests =>
	1 +
	    ($formatlooptests * scalar @FORMATS) +
		($ztrlooptests * 3),
	todo => [ 7..13, 14..25, 31..37 ];
}

sub END {
    unlink grep {
	-e $_
    } map {
	Bio::Root::IO->catfile(@BASEDIR, 't', 'staden', 'data', "readtestchk.$_");
    } @FORMATS;
}

eval { local $^W = 0; use Bio::SeqIO::staden::read };
ok($@, '', $@);

use Bio::SeqIO;
my ($in, $out, $seq, $newseq);

for my $format (@FORMATS) {

    if ($format eq 'abi' || $format eq 'alf') {
	$in = new Bio::SeqIO -file => Bio::Root::IO->catfile( @BASEDIR, qw( t staden data readtestabi.fa)), -format => 'fasta';
    } else {
	$in = new Bio::SeqIO -file => Bio::Root::IO->catfile(@BASEDIR, qw( t staden data readtestref.scf)), -format => 'scf';	
    }
    my $refseq = $in->next_seq();

    if ($format eq 'alf') {
	ok(0, undef, "Still missing test files for $format format") for (1..$formatlooptests);
	next;
    }

    eval { $in = new Bio::SeqIO -file => Bio::Root::IO->catfile(@BASEDIR, qw( t staden data), "readtest.$format"), -format => $format; };
    ok($@, '', $@); # 2

    eval { $seq = $in->next_seq(); };
    ok($@, '', $@); # 3
    
    ok($seq->seq, $refseq->seq); # 4

    if ($seq->isa('Bio::Seq::SeqWithQuality')) { # "plain" files, etc, only have sequence, nothing else
	ok(join(" ", @{$seq->qual}), join(" ", @{$refseq->qual}), "Quality lengths don't match");
	ok(0, scalar(mismatch($seq->qual, $refseq->qual)), "Quality values don't match");
    } else {
	ok(1);
	ok(1);
    }

    # OK, now try some round-trip checks:
    if ($format ne 'abi' && $format ne 'alf') {
	if ($format ne 'ctf') {
	    eval { $out = new Bio::SeqIO -file => ">" . Bio::Root::IO->catfile(@BASEDIR, qw( t staden data), "readtestchk.$format"), -format => $format; };
	    ok($@, '', $@);

	    eval { $out->write_seq($refseq); };
	    ok($@, '', $@);

	    eval { $in = new Bio::SeqIO -file => Bio::Root::IO->catfile(@BASEDIR, qw( t staden data), "readtestchk.$format"), -format => $format; };
	    ok($@, '', $@);

	    eval { $newseq = $in->next_seq(); };
	    ok($@, '', $@);

	    ok($refseq->seq, $newseq->seq);

	    if ($newseq->isa('Bio::Seq::SeqWithQuality')) { # "plain" files only have sequence, nothing else
		ok(join(" ", @{$refseq->qual}), join(" ", @{$newseq->qual}), "Quality lengths don't match"); # 13
		ok(0, scalar(mismatch($refseq->qual, $newseq->qual)), "Quality values don't match"); # 14
	    } else {
		ok(1);
		ok(1);
	    }
	} else {
	    ok(0, undef, "Can't write valid ctf files until we have a trace object") for 1..7;
	}
    } else {
	ok(0, undef, "We don't have the ability to write files for $format format") for 1..7;
    }
}

for my $comp (1..3) {

    $in = new Bio::SeqIO -file => Bio::Root::IO->catfile(@BASEDIR, qw( t staden data readtestref.scf)), -format => 'scf';	
    my $refseq = $in->next_seq();

    eval { $out = new Bio::SeqIO -file => ">" . Bio::Root::IO->catfile(@BASEDIR, qw( t staden data), "readtestchk.ztr"), -format => "ztr", -compression => $comp; };
    ok($@, '', $@);

    eval { $out->write_seq($refseq); };
    ok($@, '', $@);

    eval { $in = new Bio::SeqIO -file => Bio::Root::IO->catfile(@BASEDIR, qw( t staden data), "readtestchk.ztr"), -format => "ztr"; };
    ok($@, '', $@);

    eval { $newseq = $in->next_seq(); };
    ok($@, '', $@);

    ok($refseq->seq, $newseq->seq);

    ok(join(" ", @{$refseq->qual}), join(" ", @{$newseq->qual}), "Quality lengths don't match");
    ok(0, scalar(mismatch($refseq->qual, $newseq->qual)), "Quality values don't match");
}

sub mismatch {

    my ($a, $b) = @_;

    for (my $i = 0 ; $i < @$a && $i < @$a ; $i++) {
	return 1 if $a->[$i] != $b->[$i];
    }
    return 0;
}
