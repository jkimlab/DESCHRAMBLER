# POD documentation - main docs before the code

=head1 NAME

Bio::SeqIO::staden::read - trace file input/output stream using the Staden IO "read" library

=head1 SYNOPSIS

Do not use this module directly.  Use it via the Bio::SeqIO class.

=head1 DESCRIPTION

This object can transform Bio::Seq objects to and from various trace
file formats.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bioperl.org                  - General discussion
  http://bioperl.org/wiki/Mailing_lists  - About the mailing lists

=head2 Support 
 
Please direct usage questions or support issues to the mailing list:
  
L<bioperl-l@bioperl.org>
  
rather than to the module maintainer directly. Many experienced and 
reponsive experts will be able look at the problem and quickly 
address it. Please include a thorough description of the problem 
with code and data examples if at all possible.

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.  Bug reports can be submitted via the
web:

  http://bugzilla.open-bio.org/

=head1 AUTHORS - Aaron Mackey

Email: amackey@virginia.edu


=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::SeqIO::staden::read;
use strict;

require Exporter;
*import = \&Exporter::import;
require DynaLoader;

$Bio::SeqIO::staden::read::VERSION = '1.007000';

DynaLoader::bootstrap Bio::SeqIO::staden::read $Bio::SeqIO::staden::read::VERSION;

@Bio::SeqIO::staden::read::EXPORT = ();
@Bio::SeqIO::staden::read::EXPORT_OK = ();

sub dl_load_flags {0} # Prevent DynaLoader from complaining and croaking

use Bio::Root::Root;
use vars qw(@ISA);
my @ISA = ( 'Bio::Root::Root', @ISA );

my %formats = ( scf => 1,
		abi => 2,
		alf => 3,
		pln => 4,
		exp => 5,
		ctf => 6,
		ztr => 7,
		ztr1 => 8,
		ztr2 => 9,
		ztr3 => 10,
	      );

sub read_trace {

    my ($self) = shift;
    my ($fh, $format) = @_;

    unless (exists $formats{$format}) {
	$self->throw( -class => 'Bio::Root::NotImplemented',
		      -text  => "Format '$format' not supported by Staden read lib",
		      -value => $format
		    );
    }

    my @data = $self->staden_read_trace($fh, $formats{$format});

    unless (@data) {
	$self->throw( -class => 'Bio::Root::SystemException',
		      -text  => "Format could not be read - are you sure this is a \"$format\"-formatted trace file?",
		      -value => $format
		    );
    }

    return @data;
}

sub read_trace_with_graph
{
    my ($self) = shift;
    my ($fh, $format) = @_;

    unless (exists $formats{$format}) {
        $self->throw( -class => 'Bio::Root::SystemException',
                    -text  => "Format '$format' not supported by Staden read lib",
                    -value => $format
                    );
    }
    my @data = $self->staden_read_graph($fh, $formats{$format});

    unless (@data) {
      $self->throw( -class => 'Bio::Root::SystemException',
                    -text  => "Format could not be read - are you sure this is a \"$format\"-formatted trace file?",
                    -value => $format
                    );
    }
    return @data;
}

sub write_trace {

    my ($self) = shift;
    my ($fh, $seq, $format) = @_;

    unless (exists $formats{$format}) {
	$self->throw( -class => 'Bio::Root::NotImplemented',
		      -text  => "Format '$format' not supported by Staden read lib",
		      -value => $format
		    );
    }

    my $len = $seq->length();
    if ($len =~ m/DIFFERENT/i) {
	$self->throw( -class => 'Bio::Root::Exception',
		      -text  => "Sequence and quality lengths differ; cannot write seq",
		      -value => $len
		    );
    }

    my $ret = $self->staden_write_trace($fh,
					$formats{$format},
					$seq->seq,
					$len,
					$seq->can('qual') ? $seq->qual : [],
					$seq->display_id || '',
					$seq->desc || ''
				       );
    if ($ret == -1) {
	$self->throw( -class => 'Bio::Root::NotImplemented',
		      -text  => "Error while Writing format '$format'; either bad input or writing not supported by Staden read lib",
		      -value => $ret
		    );
    } elsif ($ret == -2) {
	$self->throw( -class => 'Bio::Root::SytemException',
		      -text  => "Out of memory error while writing seq",
		      -value => $ret
		    );
    }
    return $ret
}

sub get_trace_data {
    my ($self) = shift;
    if (@_) {
        $self->{'get_trace_data'} = 1
    }
    $self->{'get_trace_data'} ? return 1 : return 0;
}

1;
