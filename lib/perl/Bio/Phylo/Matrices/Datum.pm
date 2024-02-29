package Bio::Phylo::Matrices::Datum;
use strict;
use warnings;
use Bio::Phylo::Matrices::DatumRole;
use base qw'Bio::Phylo::Matrices::DatumRole';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw'/looks_like/';

{

    my $logger = __PACKAGE__->get_logger;
    my @fields = \( my ( %weight, %position, %annotations ) );

=head1 NAME

Bio::Phylo::Matrices::Datum - Character state sequence

=head1 SYNOPSIS

 use Bio::Phylo::Factory;
 my $fac = Bio::Phylo::Factory->new;

 # instantiating a datum object...
 my $datum = $fac->create_datum(
    -name   => 'Tooth comb size,
    -type   => 'STANDARD',
    -desc   => 'number of teeth in lower jaw comb',
    -pos    => 1,
    -weight => 2,
    -char   => [ 6 ],
 );

 # ...and linking it to a taxon object
 my $taxon = $fac->create_taxon(
     -name => 'Lemur_catta'
 );
 $datum->set_taxon( $taxon );

 # instantiating a matrix...
 my $matrix = $fac->create_matrix;

 # ...and insert datum in matrix
 $matrix->insert($datum);

=head1 DESCRIPTION

The datum object models a single observation or a sequence of observations,
which can be linked to a taxon object. This package contains the getters
and setters that alter the internal state of the datum object. Additional 
(stateless) behaviours are defined in the L<Bio::Phylo::Matrices::DatumRole>
package.

=head1 METHODS

=head2 MUTATORS

=over

=item set_weight()

Sets invocant weight.

 Type    : Mutator
 Title   : set_weight
 Usage   : $datum->set_weight($weight);
 Function: Assigns a datum's weight.
 Returns : Modified object.
 Args    : The $weight argument must be a
           number in any of Perl's number
           formats.

=cut

    sub set_weight : Clonable {
        my ( $self, $weight ) = @_;
        my $id = $self->get_id;
        if ( looks_like_number $weight ) {
            $weight{$id} = $weight;
            $logger->info("setting weight '$weight'");
        }
        elsif ( defined $weight ) {
            throw 'BadNumber' => 'Not a number!';
        }
        else {
            $weight{$id} = undef;
        }
        return $self;
    }

=item set_position()

Set invocant starting position.

 Type    : Mutator
 Title   : set_position
 Usage   : $datum->set_position($pos);
 Function: Assigns a datum's position.
 Returns : Modified object.
 Args    : $pos must be an integer.

=cut

    sub set_position : Clonable {
        my ( $self, $pos ) = @_;
        if ( looks_like_number $pos && $pos >= 1 && $pos / int($pos) == 1 ) {
            $position{ $self->get_id } = $pos;
            $logger->info("setting position '$pos'");
        }
        elsif ( defined $pos ) {
            throw 'BadNumber' => "'$pos' not a positive integer!";
        }
        else {
            $position{ $self->get_id } = undef;
        }
        return $self;
    }

=item set_annotation()

Sets single annotation.

 Type    : Mutator
 Title   : set_annotation
 Usage   : $datum->set_annotation(
               -char       => 1,
               -annotation => { -codonpos => 1 }
           );
 Function: Assigns an annotation to a
           character in the datum.
 Returns : Modified object.
 Args    : Required: -char       => $int
           Optional: -annotation => $hashref
 Comments: Use this method to annotate
           a single character. To annotate
           multiple characters, use
           'set_annotations' (see below).

=cut

    sub set_annotation {
        my $self = shift;
        if (@_) {
            my %opt = looks_like_hash @_;
            if ( not exists $opt{'-char'} ) {
                throw 'BadArgs' => "No character to annotate specified!";
            }
            my $i   = $opt{'-char'};
            my $id  = $self->get_id;
            my $pos = $self->get_position;
            my $len = $self->get_length;
            if ( $i > ( $pos + $len ) || $i < $pos ) {
                throw 'OutOfBounds' => "Specified char ($i) does not exist!";
            }
            if ( exists $opt{'-annotation'} ) {
                my $note = $opt{'-annotation'};
                $annotations{$id}->[$i] = {} if !$annotations{$id}->[$i];
                while ( my ( $k, $v ) = each %{$note} ) {
                    $annotations{$id}->[$i]->{$k} = $v;
                }
            }
            else {
                $annotations{$id}->[$i] = undef;
            }
        }
        else {
            throw 'BadArgs' => "No character to annotate specified!";
        }
        return $self;
    }

=item set_annotations()

Sets list of annotations.

 Type    : Mutator
 Title   : set_annotations
 Usage   : $datum->set_annotations(
               { '-codonpos' => 1 },
               { '-codonpos' => 2 },
               { '-codonpos' => 3 },
           );
 Function: Assign annotations to
           characters in the datum.
 Returns : Modified object.
 Args    : Hash references, where
           position in the argument
           list matches that of the
           specified characters in
           the character list. If no
           argument given, annotations
           are reset.
 Comments: Use this method to annotate
           multiple characters. To
           annotate a single character,
           use 'set_annotation' (see
           above).

=cut

    sub set_annotations : Clonable {
        my $self = shift;
        my @anno;
        if ( scalar @_ == 1 and looks_like_instance( $_[0], 'ARRAY' ) ) {
            @anno = @{ $_[0] };
        }
        else {
            @anno = @_;
        }
        my $id = $self->get_id;
        if (@anno) {
            my $max_index = $self->get_length - 1;
            for my $i ( 0 .. $#anno ) {
                if ( $i > $max_index ) {
                    throw 'OutOfBounds' =>
                      "Specified char ($i) does not exist!";
                }
                else {
                    if ( looks_like_instance( $anno[$i], 'HASH' ) ) {
                        $annotations{$id}->[$i] = {}
                          if !$annotations{$id}->[$i];
                        while ( my ( $k, $v ) = each %{ $anno[$i] } ) {
                            $annotations{$id}->[$i]->{$k} = $v;
                        }
                    }
                    else {
                        next;
                    }
                }
            }
        }
        else {
            $annotations{$id} = [];
        }
    }

=back

=head2 ACCESSORS

=over

=item get_weight()

Gets invocant weight.

 Type    : Accessor
 Title   : get_weight
 Usage   : my $weight = $datum->get_weight;
 Function: Retrieves a datum's weight.
 Returns : FLOAT
 Args    : NONE

=cut

    sub get_weight { $weight{ shift->get_id } }

=item get_position()

Gets invocant starting position.

 Type    : Accessor
 Title   : get_position
 Usage   : my $pos = $datum->get_position;
 Function: Retrieves a datum's position.
 Returns : a SCALAR integer.
 Args    : NONE

=cut

    sub get_position { $position{ shift->get_id } }

=item get_annotation()

Retrieves character annotation (hashref).

 Type    : Accessor
 Title   : get_annotation
 Usage   : $datum->get_annotation(
               '-char' => 1,
               '-key'  => '-codonpos',
           );
 Function: Retrieves an annotation to
           a character in the datum.
 Returns : SCALAR or HASH
 Args    : Optional: -char => $int
           Optional: -key => $key

=cut

    sub get_annotation {
        my $self = shift;
        my $id   = $self->get_id;
        if (@_) {
            my %opt = looks_like_hash @_;
            if ( not exists $opt{'-char'} ) {
                throw 'BadArgs' =>
                  "No character to return annotation for specified!";
            }
            my $i   = $opt{'-char'};
            my $pos = $self->get_position;
            my $len = $self->get_length;
            if ( $i < $pos || $i > ( $pos + $len ) ) {
                throw 'OutOfBounds' => "Specified char ($i) does not exist!";
            }
            if ( exists $opt{'-key'} ) {
                return $annotations{$id}->[$i]->{ $opt{'-key'} };
            }
            else {
                return $annotations{$id}->[$i];
            }
        }
        else {
            return $annotations{$id};
        }
    }

=item get_annotations()

Retrieves character annotations (array ref).

 Type    : Accessor
 Title   : get_annotations
 Usage   : my @anno = @{ $datum->get_annotation() };
 Function: Retrieves annotations
 Returns : ARRAY
 Args    : NONE

=cut

    sub get_annotations {
        my $self = shift;
        return $annotations{ $self->get_id } || [];
    }

    sub _cleanup : Destructor {
        my $self = shift;
        $logger->info("cleaning up '$self'");
        if ( defined( my $id = $self->get_id ) ) {
            for my $field (@fields) {
                delete $field->{$id};
            }
        }
    }
    
    sub _update_characters {
        my $self = shift;
        if ( my $matrix = $self->get_matrix ) {
            $matrix->_update_characters;
        }
    }
}

=back

=cut

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::Matrices::DatumRole>

This object inherits from L<Bio::Phylo::Matrices::DatumRole>, so the methods
defined therein are also applicable to L<Bio::Phylo::Matrices::Datum> objects.

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
