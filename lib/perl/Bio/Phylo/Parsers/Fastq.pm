package Bio::Phylo::Parsers::Fastq;
use strict;
use warnings;
use base 'Bio::Phylo::Parsers::Abstract';
use Bio::Phylo::Util::Logger ':simple';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT ':objecttypes';

=head1 NAME

Bio::Phylo::Parsers::Fastq - Parser used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

A FASTQ file parser. To use it, you need to pass an argument
that specifies the data type of the phred scores into the parse function, i.e.

 my $handler_type = _DATUM_;
 parse(
    -format => 'fastq',
    -type   => 'illumina', # to indicate how phred scores are scaled
    -file   => 'infile.fastq',
    -flush  => 1, # don't store record, flush and move on
    -handlers => {
    
        # specifies a handler that is executed on each newly created datum
        $handler_type => sub {
            my $seq = shift;
            my @char = $seq->get_char;
            my @anno = @{ $seq->get_annotations };
            
            # print fasta, omit bases with low phred scores
            print ">$seq\n";
            for my $i ( 0 .. $#char ) {
                if ( $anno[$i]->{phred} > 20 ) {
                    print $char[$i];
                }
            }
            print "\n";
        }
    }
 );

=cut

sub _parse {
    my $self   = shift;
    my $fh     = $self->_handle;
    my $fac    = $self->_factory;
    my $type   = $self->_args->{'-type'} or throw 'BadArgs' => 'No data type specified!';
    my $to     = $fac->create_datatype($type);
    my $matrix;
    $matrix = $fac->create_matrix( '-type' => 'dna' ) unless $self->_flush;

    my ( $readseq, $readphred );
    my ( $id, $seq, $phred );
    LINE: while( my $line = $fh->getline ) {
        chomp $line;

        # found the FASTQ id line
        if ( $line =~ /^\@(.+)$/ and not $readphred ) {
            my $capture = $1;
            
            # process previous record
            if ( $id && $seq && $phred ) {              
                $self->_process_seq(
                    'phred' => $phred,
                    'seq'   => $seq,
                    'id'    => $id,
                    'to'    => $to,
                );
            }
            
            # start new record
            $id        = $capture;
            $readseq   = 1;
            $readphred = 0;
            $seq       = '';
            INFO "found record ID $id, going to read sequence";
            next LINE;
        }

        # found the FASTQ plus line
        elsif ( $line =~ /^\+/ and not $readphred ) {
            $readseq   = 0;
            $readphred = 1;
            $phred     = '';
            INFO "found plus line, going to read sequence quality";
            next LINE;
        }

        # concatenate sequence
        elsif ( $readseq ) {
            $seq .= $line;
            next LINE;
        }

        # concatenate quality line
        elsif ( $readphred ) {
            $phred .= $line;
            if ( length($phred) == length($seq) ) {
                INFO "found all phred characters";
                $readphred = 0;
            }
            next LINE;
        }
    }
    
    # process last record
    $self->_process_seq(
        'phred' => $phred,
        'seq'   => $seq,
        'id'    => $id,
        'to'    => $to,
    );  
    
    # done
    return $self->_flush ? undef : $matrix;
}

sub _process_seq {
    my ($self,%args) = @_;
    my $sh = $self->_handlers(_DATUM_);
    
    # turn the phred line into column-level annotations
    my @scores = map { { 'phred' => $_ } }
                 map { @{ $args{to}->get_states_for_symbol($_) } }
                 @{ $args{to}->split($args{phred}) };
                 
    # create the sequence object
    my $datum = $self->_factory->create_datum(
        '-type' => 'dna',
        '-name' => $args{id},
        '-char' => $args{seq},
        '-annotations' => \@scores,
    );
    
    $sh->($datum) if $sh;
    $args{'matrix'}->insert($datum) unless $self->_flush;
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The fasta parser is called by the L<Bio::Phylo::IO|Bio::Phylo::IO> object.
Look there to learn more about parsing.

=item L<Bio::Phylo::Manual>

Also see the manual: L<Bio::Phylo::Manual> and L<http://rutgervos.blogspot.com>

=back

=head1 CITATION

If you use Bio::Phylo in published research, please cite it:

B<Rutger A Vos>, B<Jason Caravas>, B<Klaas Hartmann>, B<Mark A Jensen>
and B<Chase Miller>, 2011. Bio::Phylo - phyloinformatic analysis using Perl.
I<BMC Bioinformatics> B<12>:63.
L<http://dx.doi.org/10.1186/1471-2105-12-63>

=cut

1;
