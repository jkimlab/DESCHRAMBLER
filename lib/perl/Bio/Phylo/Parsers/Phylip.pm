package Bio::Phylo::Parsers::Phylip;
use strict;
use warnings;
use base 'Bio::Phylo::Parsers::Abstract';
use Bio::Phylo::Util::Exceptions 'throw';

=head1 NAME

Bio::Phylo::Parsers::Phylip - Parser used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module is used for parsing PHYLIP character state matrix files. At present this only
works on non-interleaved files. As PHYLIP files don't indicate what data type they are you 
should indicate this as an argument to the Bio::Phylo::IO::parse function, i.e.:

 use Bio::Phylo::IO 'parse';
 my $file = shift @ARGV;
 my $type = 'dna'; # or rna, protein, restriction, standard, continuous
 my $matrix = parse(
 	'-file'   => $file,
 	'-format' => 'phylip',
 	'-type'   => $type,
 )->[0];
 print ref($matrix); # probably prints Bio::Phylo::Matrices::Matrix;

=cut

sub _parse {
    my $self    = shift;
    my $factory = $self->_factory;
    my $type    = $self->_args->{'-type'} || 'standard';
    my $handle  = $self->_handle;
    my $matrix  = $factory->create_matrix( '-type' => $type );
    my ( $ntax, $nchar );
    LINE: while (<$handle>) {
        my ( $name, $seq );
        if ( /^\s*(\d+)\s+(\d+)\s*$/ && !$ntax && !$nchar ) {
            ( $ntax, $nchar ) = ( $1, $2 );
            next LINE;
        }
        elsif ( /^\s*(\S+)\s+(.+)$/ ) {
            ( $name, $seq ) = ( $1, $2 );
            $seq =~ s/\s//g;
        }
        else {
            $name = substr( $_, 0, 10 );
            $seq = substr( $_, 10 );            
        }
        $matrix->insert(
            $factory->create_datum(
                '-type' => $type,
                '-name' => $name,
                '-char' => $matrix->get_type_object->split($seq),
            )
        );        
    }
    my ( $my_nchar, $my_ntax ) = ( $matrix->get_nchar, $matrix->get_ntax );
    $nchar != $my_nchar
      && throw 'BadFormat' => "observed ($my_nchar) != expected ($nchar) nchar";
    $ntax != $my_ntax
      && throw 'BadFormat' => "observed ($my_ntax) != expected ($ntax) ntax";
    return $matrix;
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The PHYLIP parser is called by the L<Bio::Phylo::IO> object.
Look there for examples.

=item L<Bio::Phylo::Manual>

Also see the manual: L<Bio::Phylo::Manual> and L<http://rutgervos.blogspot.com>.

=back

=head1 CITATION

If you use Bio::Phylo in published research, please cite it:

B<Rutger A Vos>, B<Jason Caravas>, B<Klaas Hartmann>, B<Mark A Jensen>
and B<Chase Miller>, 2011. Bio::Phylo - phyloinformatic analysis using Perl.
I<BMC Bioinformatics> B<12>:63.
L<http://dx.doi.org/10.1186/1471-2105-12-63>

=cut

1;
