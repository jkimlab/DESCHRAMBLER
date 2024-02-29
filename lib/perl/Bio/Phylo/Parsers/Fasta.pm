package Bio::Phylo::Parsers::Fasta;
use strict;
use warnings;
use base 'Bio::Phylo::Parsers::Abstract';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT ':objecttypes';

=head1 NAME

Bio::Phylo::Parsers::Fasta - Parser used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

A very symplistic FASTA file parser. To use it, you need to pass an argument
that specifies the data type of the FASTA records into the parse function, i.e.

 my $project = parse(
    -type   => 'dna', # or rna, protein
    -format => 'fasta',
    -file   => 'infile.fa',
    -as_project => 1
 );

For each FASTA record, the first "word" on the definition line is used as the
name of the produced datum object. The entire line is assigned to:

 $datum->set_generic( 'fasta_def_line' => $line )
 
So you can retrieve it by calling:

 my $line = $datum->get_generic('fasta_def_line');

BioPerl actually parses definition lines to get GIs and such out of there, so if
you're looking for that, use L<Bio::SeqIO> from the bioperl-live distribution.
You can always pass the resulting Bio::Seq objects to
Bio::Phylo::Matrices::Datum->new_from_bioperl to turn the L<Bio::Seq> objects
that Bio::SeqIO produces into L<Bio::Phylo::Matrices::Datum> objects. 

=cut

sub _parse {
    my $self = shift;
    my $fh   = $self->_handle;
    my $fac  = $self->_factory;
    my $sh   = $self->_handlers(_DATUM_);
    my $type = $self->_args->{'-type'} or throw 'BadArgs' => 'No data type specified!';
    my $matrix = $fac->create_matrix( '-type' => $type );
    my ( $seq, $datum );
    while (<$fh>) {
        chomp;
        my $line = $_;
        if ( $line =~ />(\S+)/ ) {
            my $name = $1;
            if ( $seq && $datum ) {
                $datum->set_char($seq);
                $sh->($datum) if $sh;
                $matrix->insert($datum);
            }
            $datum = $fac->create_datum(
                '-type'    => $type,
                '-name'    => $name,
                '-generic' => { 'fasta_def_line' => $line }
            );
            $seq = '';
        }
        else {
            $seq .= $line;
        }
    }

# within the loop, insertions are triggered by encountering the next definition line,
# hence, the last $datum needs to be inserted explicitly when we leave the loop
    $datum->set_char($seq);
    $sh->($datum) if $sh;
    $matrix->insert($datum);
    return $matrix;
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
