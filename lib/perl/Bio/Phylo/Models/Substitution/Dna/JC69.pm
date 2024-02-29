package Bio::Phylo::Models::Substitution::Dna::JC69;
use strict;
use warnings;
use base 'Bio::Phylo::Models::Substitution::Dna';

=head1 NAME

Bio::Phylo::Models::Substitution::Dna::JC69 - Jukes, Cantor (1969)

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

sub get_nst  { 1 }

=item get_rate

Getter for substitution rate. If bases are given as arguments,
returns corresponding rate. If no arguments given, returns rate matrix or
overall rate, dependent on model.

 Type    : method
 Title   : get_rate
 Usage   : $model->get_rate('A', 'C');
 Function: Getter for transition rate between nucleotides.
 Returns : scalar or array
 Args    : Optional:
           base1: scalar
           base2: scalar

=cut

# substitution rate
sub get_rate { shift->get_mu / 4 }

=item get_catweights

Getter for weights on rate categories.

 Type    : method
 Title   : get_catweights
 Usage   : $model->get_catweights;
 Function: Getter for number of rate categories.
 Returns : array
 Args    : None

=cut

sub get_catweights { [1.0] }

=item get_catrates

Getter for rate categories, implemented by child classes.

 Type    : method
 Title   : get_catrates
 Usage   : $model->get_catrates;
 Function: Getter for rate categories.
 Returns : scalar or array
 Args    : None.

=cut

sub get_catrates { [1.0] }

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
