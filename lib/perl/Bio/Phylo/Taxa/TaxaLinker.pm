package Bio::Phylo::Taxa::TaxaLinker;
use Bio::Phylo;
use Bio::Phylo::Mediators::TaxaMediator;
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw'_TAXA_ looks_like_object';
use strict;
use warnings;
my $logger        = Bio::Phylo->get_logger;
my $mediator      = 'Bio::Phylo::Mediators::TaxaMediator';
my $TYPE_CONSTANT = _TAXA_;

=head1 NAME

Bio::Phylo::Taxa::TaxaLinker - Superclass for objects that link to taxa objects

=head1 SYNOPSIS

 use Bio::Phylo::Factory;
 my $fac = Bio::Phylo::Factory->new;

 my $matrix = $fac->create_matrix;
 my $taxa = $fac->create_taxa;

 if ( $matrix->isa('Bio::Phylo::Taxa::TaxaLinker') ) {
    $matrix->set_taxa( $taxa );
 }

=head1 DESCRIPTION

This module is a superclass for objects that link to L<Bio::Phylo::Taxa> objects.

=head1 METHODS

=head2 MUTATORS

=over

=item set_taxa()

Associates invocant with Bio::Phylo::Taxa argument.

 Type    : Mutator
 Title   : set_taxa
 Usage   : $obj->set_taxa( $taxa );
 Function: Links the invocant object
           to a taxa object.
 Returns : Modified $obj
 Args    : A Bio::Phylo::Taxa object.

=cut

sub set_taxa : Clonable DeepClonable {
    my ( $self, $taxa ) = @_;
    if ( $taxa and looks_like_object $taxa, $TYPE_CONSTANT ) {
        $logger->info("setting taxa '$taxa'");
        $mediator->set_link(
            '-one'  => $taxa,
            '-many' => $self,
        );
    }
    else {
        $logger->info("re-setting taxa link");
        $mediator->remove_link( '-many' => $self );
    }
    $self->check_taxa;
    return $self;
}

=item unset_taxa()

Removes association between invocant and Bio::Phylo::Taxa object.

 Type    : Mutator
 Title   : unset_taxa
 Usage   : $obj->unset_taxa();
 Function: Removes the link between invocant object and taxa
 Returns : Modified $obj
 Args    : NONE

=cut

sub unset_taxa {
    my $self = shift;
    $logger->info("unsetting taxa");
    $self->set_taxa();
    return $self;
}

=back

=head2 ACCESSORS

=over

=item get_taxa()

Retrieves association between invocant and Bio::Phylo::Taxa object.

 Type    : Accessor
 Title   : get_taxa
 Usage   : my $taxa = $obj->get_taxa;
 Function: Retrieves the Bio::Phylo::Taxa
           object linked to the invocant.
 Returns : Bio::Phylo::Taxa
 Args    : NONE
 Comments: This method returns the Bio::Phylo::Taxa
           object to which the invocant is linked.
           The returned object can therefore contain
           *more* taxa than are actually in the matrix.

=cut

sub get_taxa {
    my $self = shift;
    $logger->debug("getting taxa");
    return $mediator->get_link( '-source' => $self );
}

=item check_taxa()

Performs sanity check on taxon relationships.

 Type    : Interface method
 Title   : check_taxa
 Usage   : $obj->check_taxa
 Function: Performs sanity check on taxon relationships
 Returns : $obj
 Args    : NONE

=cut

sub check_taxa {
    throw 'NotImplemented' => 'Not implemented!';
}

=item make_taxa()

Creates a taxa block from the objects contents if none exists yet.

 Type    : Decorated interface method
 Title   : make_taxa
 Usage   : my $taxa = $obj->make_taxa
 Function: Creates a taxa block from the objects contents if none exists yet.
 Returns : $taxa
 Args    : NONE

=cut

sub make_taxa {
    my $self = shift;
    if ( my $taxa = $self->get_taxa ) {
        return $taxa;
    }
    else {
        throw 'NotImplemented' => 'Not implemented!';
    }
}

sub _cleanup {
    my $self = shift;
}

=back

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::Matrices::Matrix>

The matrix object subclasses L<Bio::Phylo::Taxa::TaxaLinker>.

=item L<Bio::Phylo::Forest>

The forest object subclasses L<Bio::Phylo::Taxa::TaxaLinker>.

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
