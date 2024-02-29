package Bio::Phylo::Unparsers::Mrp;
use strict;
use warnings;
use base 'Bio::Phylo::Unparsers::Abstract';
use Bio::Phylo::Util::CONSTANT qw'/looks_like/ :objecttypes';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Factory;

my $factory = Bio::Phylo::Factory->new;

=head1 NAME

Bio::Phylo::Unparsers::Mrp - Serializer used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module turns a L<Bio::Phylo::Forest> object into an MRP nexus
formatted matrix. It is called by the L<Bio::Phylo::IO> facade, don't call it
directly.

=begin comment

 Type    : Wrapper
 Title   : _to_string
 Usage   : my $mrp_string = $mrp->_to_string;
 Function: Stringifies a matrix object into
           an MRP nexus formatted table.
 Alias   :
 Returns : SCALAR
 Args    : Bio::Phylo::Matrices::Matrix;

=end comment

=cut

sub _to_string {
    my $self   = shift;
    my $forest = $self->{'PHYLO'};
    if ( looks_like_implementor $forest, 'get_forests' ) {
        ($forest) = @{ $forest->get_forests };
    }
    if ( looks_like_implementor $forest, 'make_matrix' ) {
        my $proj = $factory->create_project;
        my $matrix = $forest->make_matrix;
        $proj->insert( $matrix->get_taxa, $matrix );
        return $proj->to_nexus( '-charstatelabels' => 1 );
    }
    else {
        throw 'ObjectMismatch' => "Can't make MRP matrix out of $forest";
    }
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The mrp unparser is called by the L<Bio::Phylo::IO> object.
Look there to learn how to create mrp matrices.

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
