package Bio::Phylo::Models::Substitution::Dna::K80;
use strict;
use warnings;
use base 'Bio::Phylo::Models::Substitution::Dna::JC69';
my %purines = ( 'A' => 1, 'G' => 1 );

=head1 NAME

Bio::Phylo::Models::Substitution::Dna::K80 - Kimura 2-parameter

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

sub get_nst { 2 }

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

# subst rate
sub get_rate {
    my $self = shift;
    if ( scalar @_ == 2 ) {
        my ( $src, $trgt ) = ( uc $_[0], uc $_[1] );

        # transversion
        if ( $purines{$src} xor $purines{$trgt} ) {
            return $self->get_kappa;
        }

        # transition
        else {
            return 1;
        }
    }
}

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
