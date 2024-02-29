package Bio::Phylo::Matrices::Datatype::Custom;
use strict;
use warnings;
use base 'Bio::Phylo::Matrices::Datatype';

=head1 NAME

Bio::Phylo::Matrices::Datatype::Custom - Validator subclass,
no serviceable parts inside

=head1 DESCRIPTION

The Bio::Phylo::Matrices::Datatype::* classes are used to validated data
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

sub _new {
    my $class = shift;
    my $self  = shift;
    my %args  = @_;
    die if not $args{'-lookup'};
    bless $self, $class;
    $self->set_lookup( $args{'-lookup'} );
    return $self;
}
1;
