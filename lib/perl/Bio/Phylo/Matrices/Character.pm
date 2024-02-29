package Bio::Phylo::Matrices::Character;
use strict;
use warnings;
use base 'Bio::Phylo::Matrices::TypeSafeData';
use Bio::Phylo::Factory;
use Bio::Phylo::Util::CONSTANT qw'_CHARACTER_ _CHARACTERS_ _NS_BIOPHYLO_ /looks_like/';
use Bio::Phylo::Util::Exceptions 'throw';

my $fac = Bio::Phylo::Factory->new;

=head1 NAME

Bio::Phylo::Matrices::Character - A character (column) in a matrix

=head1 SYNOPSIS

 # No direct usage

=head1 DESCRIPTION

Objects of this type represent a single character in a matrix. By default, a
matrix will adjust the number of such objects it requires automatically as its
contents grow or shrink. The main function, at present, for objects of this
type is to facilitate NeXML serialization of characters and their annotations.

=head1 METHODS

=head2 MUTATORS

=over

=item set_weight()

 Type    : Mutator
 Title   : set_weight
 Usage   : $character->set_weight(2);
 Function: Sets character weight
 Returns : $self
 Args    : A number

=cut

sub set_weight : Clonable {
    my ( $self, $weight ) = @_;
    if ( looks_like_number $weight ) {
        if ( my ($meta) = @{ $self->get_meta('bp:charWeight') } ) {
            $meta->set_triple( 'bp:charWeight' => $weight );
        }
        else {
            $self->add_meta(
                $fac->create_meta(
                    '-namespaces' => { 'bp' => _NS_BIOPHYLO_ },
                    '-triple'     => { 'bp:charWeight' => $weight },
                )
            );
        }
    }
    elsif ( defined $weight ) {
        throw 'BadNumber' => "'$weight' is not a number";
    }
    return $self;    
}

=item set_codonpos()

 Type    : Mutator
 Title   : set_codonpos
 Usage   : $character->set_codonpos(2);
 Function: Sets codon position for the column
 Returns : $self
 Args    : A number

=cut

sub set_codonpos : Clonable {
    my ( $self, $codonpos ) = @_;
    if ( $codonpos ) {
        if ( $codonpos == 1 || $codonpos == 2 || $codonpos == 3 ) {
            if ( my ($meta) = @{ $self->get_meta('bp:codonPos') } ) {
                $meta->set_triple( 'bp:codonPos' => $codonpos );
            }
            else {
                $self->add_meta(
                    $fac->create_meta(
                        '-namespaces' => { 'bp' => _NS_BIOPHYLO_ },
                        '-triple'     => { 'bp:codonPos' => $codonpos },
                    )
                );
            }
        }
        elsif ( defined $codonpos ) {
            throw 'BadNumber' => "'$codonpos' is not a valid 1-based codon position";
        }   
    }
    return $self;
}

=back

=head2 ACCESSORS

=over

=item get_weight()

 Type    : Accessor
 Title   : get_weight
 Usage   : my $weight = $character->get_weight();
 Function: Gets character weight
 Returns : A number (default is 1)
 Args    : NONE

=cut

sub get_weight {
    shift->get_meta_object('bp:charWeight');
}

=item get_codonpos()

 Type    : Mutator
 Title   : get_codonpos
 Usage   : my $pos = $character->get_codonpos;
 Function: Gets codon position for the column
 Returns : 1, 2, 3 or undef
 Args    : None

=cut

sub get_codonpos {
    shift->get_meta_object('bp:codonPos');
}

=back

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
    if ( my $to = $self->get_type_object ) {
        if ( $to->get_type !~ m/continuous/i ) {
            $self->set_attributes( 'states' => $to->get_xml_id );
        }
    }
    return $self->SUPER::to_xml;
}
sub _validate  { 1 }
sub _container { _CHARACTERS_ }
sub _type      { _CHARACTER_ }
sub _tag       { 'char' }

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
