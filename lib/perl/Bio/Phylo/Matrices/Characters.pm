package Bio::Phylo::Matrices::Characters;
use strict;
use warnings;
use base 'Bio::Phylo::Matrices::TypeSafeData';
use Bio::Phylo::Util::CONSTANT qw'_CHARACTERS_ _NONE_';
use Bio::Phylo::Factory;

=head1 NAME

Bio::Phylo::Matrices::Characters - Container of character objects

=head1 SYNOPSIS

 # No direct usage

=head1 DESCRIPTION

Objects of this type hold a list of L<Bio::Phylo::Matrices::Character> objects,
i.e. columns in a matrix. By default, a matrix will be initialized to hold
one object of this type (which can be retrieved using $matrix->get_characters).
Its main function is to facilitate NeXML serialization of matrix objects, though
this may expand in the future.

=head1 METHODS

=head2 SERIALIZERS

=over

=item to_xml()

Serializes characters to nexml format.

 Type    : Format convertor
 Title   : to_xml
 Usage   : my $xml = $characters->to_xml;
 Function: Converts characters object into a nexml element structure.
 Returns : Nexml block (SCALAR).
 Args    : NONE

=cut

sub to_xml {
    my $self = shift;
    my $xml = '';
    for my $ent ( @{ $self->get_entities } ) {
        $xml .= $ent->to_xml;
    }
    $xml .= $self->sets_to_xml;
    return $xml;
}
sub _validate  { 1 }
sub _container { _NONE_ }
sub _type      { _CHARACTERS_ }
sub _tag       { 'chars' }

=back

=cut

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::Matrices::TypeSafeData>

This object inherits from L<Bio::Phylo::Matrices::TypeSafeData>, so the
methods defined therein are also applicable to characters objects
objects.

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
