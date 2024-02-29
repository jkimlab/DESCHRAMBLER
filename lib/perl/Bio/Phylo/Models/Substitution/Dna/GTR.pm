package Bio::Phylo::Models::Substitution::Dna::GTR;
use strict;
use warnings;
use base 'Bio::Phylo::Models::Substitution::Dna';

=head1 NAME

Bio::Phylo::Models::Substitution::Dna::GTR - General Time Reversible model

=head1 DESCRIPTION

See L<Bio::Phylo::Models::Substitution::Dna>

=head1 METHODS

=over

=item get_nst

Getter for number of transition rate parameters.

 Type    : method
 Title   : get_nst
 Usage   : $model->get_nst;
 Function: Getter for number of transition rate parameters.
 Returns : scalar
 Args    : None.

=cut

sub get_nst { 6 }

=back

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

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
