package Bio::Phylo::Matrices::Datatype::Dna;
use strict;
use warnings;
use base 'Bio::Phylo::Matrices::Datatype';
our ( $LOOKUP, $MISSING, $GAP );

=head1 NAME

Bio::Phylo::Matrices::Datatype::Dna - Validator subclass,
no serviceable parts inside

=head1 DESCRIPTION

The Bio::Phylo::Matrices::Datatype::* classes are used to validate data
contained by L<Bio::Phylo::Matrices::Matrix> and L<Bio::Phylo::Matrices::Datum>
objects.

=cut

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::Matrices::Datatype>

This class subclasses L<Bio::Phylo::Matrices::Datatype>.

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

$LOOKUP = {
    'A' => ['A'],
    'C' => ['C'],
    'G' => ['G'],
    'T' => ['T'],
    'M' => [ 'A', 'C' ],
    'R' => [ 'A', 'G' ],
    'W' => [ 'A', 'T' ],
    'S' => [ 'C', 'G' ],
    'Y' => [ 'C', 'T' ],
    'K' => [ 'G', 'T' ],
    'V' => [ 'A', 'C', 'G' ],
    'H' => [ 'A', 'C', 'T' ],
    'D' => [ 'A', 'G', 'T' ],
    'B' => [ 'C', 'G', 'T' ],
    'X' => [ 'G', 'A', 'T', 'C' ],
    'N' => [ 'G', 'A', 'T', 'C' ],
};
$MISSING = '?';
$GAP     = '-';
1;
