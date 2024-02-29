package Bio::Phylo::Matrices::Datatype::Protein;
use strict;
use warnings;
use base 'Bio::Phylo::Matrices::Datatype';
our ( $LOOKUP, $MISSING, $GAP );

=head1 NAME

Bio::Phylo::Matrices::Datatype::Protein - Validator subclass,
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

=head1 FORUM

CPAN hosts a discussion forum for Bio::Phylo. If you have trouble
using this module the discussion forum is a good place to start
posting questions (NOT bug reports, see below):
L<http://www.cpanforum.com/dist/Bio-Phylo>

=cut

$LOOKUP = {
    'A' => ['A'],
    'B' => [ 'D', 'N' ],
    'C' => ['C'],
    'D' => ['D'],
    'E' => ['E'],
    'F' => ['F'],
    'G' => ['G'],
    'H' => ['H'],
    'I' => ['I'],
    'K' => ['K'],
    'L' => ['L'],
    'M' => ['M'],
    'N' => ['N'],
    'P' => ['P'],
    'Q' => ['Q'],
    'R' => ['R'],
    'S' => ['S'],
    'T' => ['T'],
    'U' => ['U'],
    'V' => ['V'],
    'W' => ['W'],
    'X' => ['X'],
    'Y' => ['Y'],
    'Z' => [ 'E', 'Q' ],
    '*' => ['*'],
};
$MISSING = '?';
$GAP     = '-';
1;
