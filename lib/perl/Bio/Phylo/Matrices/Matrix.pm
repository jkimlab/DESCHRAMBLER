package Bio::Phylo::Matrices::Matrix;
use strict;
use warnings;
use base 'Bio::Phylo::Matrices::MatrixRole';
use Bio::Phylo::Util::CONSTANT qw':objecttypes /looks_like/';
use Bio::Phylo::Util::Exceptions qw'throw';
{

    my $logger             = __PACKAGE__->get_logger;		
    my @inside_out_arrays  = \(
        my (
            %type,             %charlabels, %statelabels,
            %gapmode,          %matchchar,  %polymorphism,
            %case_sensitivity, %characters,
        )
    );

=head1 NAME

Bio::Phylo::Matrices::Matrix - Character state matrix

=head1 SYNOPSIS

 use Bio::Phylo::Factory;
 my $fac = Bio::Phylo::Factory->new;

 # instantiate taxa object
 my $taxa = $fac->create_taxa;
 for ( 'Homo sapiens', 'Pan paniscus', 'Pan troglodytes' ) {
     $taxa->insert( $fac->create_taxon( '-name' => $_ ) );
 }

 # instantiate matrix object, 'standard' data type. All categorical
 # data types follow semantics like this, though with different
 # symbols in lookup table and matrix
 my $standard_matrix = $fac->create_matrix(
     '-type'   => 'STANDARD',
     '-taxa'   => $taxa,
     '-lookup' => { 
         '-' => [],
         '0' => [ '0' ],
         '1' => [ '1' ],
         '?' => [ '0', '1' ],
     },
     '-charlabels' => [ 'Opposable big toes', 'Opposable thumbs', 'Not a pygmy' ],
     '-matrix' => [
         [ 'Homo sapiens'    => '0', '1', '1' ],
         [ 'Pan paniscus'    => '1', '1', '0' ],
         [ 'Pan troglodytes' => '1', '1', '1' ],
     ],
 );
 
 # note: complicated constructor for mixed data!
 my $mixed_matrix = Bio::Phylo::Matrices::Matrix->new( 
    
    # if you want to create 'mixed', value for '-type' is array ref...
    '-type' =>  [ 
    
        # ...with first field 'mixed'...                
        'mixed',
        
        # ...second field is an array ref...
        [
            
            # ...with _ordered_ key/value pairs...
            'dna'      => 10, # value is length of type range
            'standard' => 10, # value is length of type range
            
            # ... or, more complicated, value is a hash ref...
            'rna'      => {
                '-length' => 10, # value is length of type range
                
                # ...value for '-args' is an array ref with args 
                # as can be passed to 'unmixed' datatype constructors,
                # for example, here we modify the lookup table for
                # rna to allow both 'U' (default) and 'T'
                '-args'   => [
                    '-lookup' => {
                        'A' => [ 'A'                     ],
                        'C' => [ 'C'                     ],
                        'G' => [ 'G'                     ],
                        'U' => [ 'U'                     ],
                        'T' => [ 'T'                     ],
                        'M' => [ 'A', 'C'                ],
                        'R' => [ 'A', 'G'                ],
                        'S' => [ 'C', 'G'                ],
                        'W' => [ 'A', 'U', 'T'           ],
                        'Y' => [ 'C', 'U', 'T'           ],
                        'K' => [ 'G', 'U', 'T'           ],
                        'V' => [ 'A', 'C', 'G'           ],
                        'H' => [ 'A', 'C', 'U', 'T'      ],
                        'D' => [ 'A', 'G', 'U', 'T'      ],
                        'B' => [ 'C', 'G', 'U', 'T'      ],
                        'X' => [ 'G', 'A', 'U', 'T', 'C' ],
                        'N' => [ 'G', 'A', 'U', 'T', 'C' ],
                    },
                ],
            },
        ],
    ],
 );
 
 # prints 'mixed(Dna:1-10, Standard:11-20, Rna:21-30)'
 print $mixed_matrix->get_type;

=head1 DESCRIPTION

This module defines a container object that holds
L<Bio::Phylo::Matrices::Datum> objects. The matrix
object inherits from L<Bio::Phylo::MatrixRole>, so the
methods defined there apply here.

=head1 METHODS

=head2 MUTATORS

=over

=item set_statelabels()

Sets argument state labels.

 Type    : Mutator
 Title   : set_statelabels
 Usage   : $matrix->set_statelabels( [ [ 'state1', 'state2' ] ] );
 Function: Assigns state labels.
 Returns : $self
 Args    : ARRAY, or nothing (to reset);
           The array is two-dimensional, 
           the first index is to indicate
           the column the labels apply to,
           the second dimension the states
           (sorted numerically or alphabetically,
           depending on what's appropriate)

=cut

    sub set_statelabels : Clonable {
        my ( $self, $statelabels ) = @_;

        # it's an array ref, but what about its contents?
        if ( looks_like_instance( $statelabels, 'ARRAY' ) ) {
            for my $col ( @{$statelabels} ) {
                if ( not looks_like_instance( $col, 'ARRAY' ) ) {
                    throw 'BadArgs' =>
                      "statelabels must be a two dimensional array ref";
                }
            }
        }

        # it's defined but not an array ref
        elsif ( defined $statelabels
            && !looks_like_instance( $statelabels, 'ARRAY' ) )
        {
            throw 'BadArgs' =>
              "statelabels must be a two dimensional array ref";
        }

        # it's either a valid array ref, or nothing, i.e. a reset
        $statelabels{ $self->get_id } = $statelabels || [];
        return $self;
    }

=item set_characters()

Sets the character set manager object Bio::Phylo::Matrices::Characters.
Normally you never have to use this.

 Type    : Mutator
 Title   : set_characters
 Usage   : $matrix->set_characters( $characters );
 Function: Assigns Bio::Phylo::Matrices::Characters object
 Returns : $self
 Args    : Bio::Phylo::Matrices::Characters

=cut

    sub set_characters : Clonable DeepClonable {
        my ( $self, $characters ) = @_;
        if ( looks_like_object $characters, _CHARACTERS_ ) {
            $characters{ $self->get_id } = $characters;
        }
        return $self;
    }

=item set_gapmode()

Defines matrix gapmode.

 Type    : Mutator
 Title   : set_gapmode
 Usage   : $matrix->set_gapmode( 1 );
 Function: Defines matrix gapmode ( false = missing, true = fifth state )
 Returns : $self
 Args    : boolean

=cut

    sub set_gapmode : Clonable {
        my ( $self, $gapmode ) = @_;
        $gapmode{ $self->get_id } = $gapmode;
        return $self;
    }

=item set_matchchar()

Assigns match symbol.

 Type    : Mutator
 Title   : set_matchchar
 Usage   : $matrix->set_matchchar( $match );
 Function: Assigns match symbol (default is '.').
 Returns : $self
 Args    : ARRAY

=cut

    sub set_matchchar : Clonable {
        my ( $self, $match ) = @_;
	if ( $match ) {
	    my $missing = $self->get_missing;
	    my $gap     = $self->get_gap;
	    if ( $match eq $missing ) {
		throw 'BadArgs' =>
		  "Match character '$match' already in use as missing character";
	    }
	    elsif ( $match eq $gap ) {
		throw 'BadArgs' =>
		  "Match character '$match' already in use as gap character";
	    }
	    else {
		$matchchar{ $self->get_id } = $match;
	    }
	}
	else {
	    $matchchar{ $self->get_id } = undef;
	}
        return $self;
    }

=item set_polymorphism()

Defines matrix 'polymorphism' interpretation.

 Type    : Mutator
 Title   : set_polymorphism
 Usage   : $matrix->set_polymorphism( 1 );
 Function: Defines matrix 'polymorphism' interpretation
           ( false = uncertainty, true = polymorphism )
 Returns : $self
 Args    : boolean

=cut

    sub set_polymorphism : Clonable {
        my ( $self, $poly ) = @_;
        if ( defined $poly ) {
            $polymorphism{ $self->get_id } = $poly;
        }
        else {
            delete $polymorphism{ $self->get_id };
        }
        return $self;
    }

=item set_respectcase()

Defines matrix case sensitivity interpretation.

 Type    : Mutator
 Title   : set_respectcase
 Usage   : $matrix->set_respectcase( 1 );
 Function: Defines matrix case sensitivity interpretation
           ( false = disregarded, true = "respectcase" )
 Returns : $self
 Args    : boolean

=cut

    sub set_respectcase : Clonable {
        my ( $self, $case_sensitivity ) = @_;
        if ( defined $case_sensitivity ) {
            $case_sensitivity{ $self->get_id } = $case_sensitivity;
        }
        else {
            delete $case_sensitivity{ $self->get_id };
        }
        return $self;
    }

=back

=head2 ACCESSORS

=over

=item get_characters()

Retrieves characters object.

 Type    : Accessor
 Title   : get_characters
 Usage   : my $characters = $matrix->get_characters
 Function: Retrieves characters object.
 Returns : Bio::Phylo::Matrices::Characters
 Args    : None.

=cut

    sub get_characters {
        my $self = shift;
        return $characters{ $self->get_id };
    }

=item get_statelabels()

Retrieves state labels.

 Type    : Accessor
 Title   : get_statelabels
 Usage   : my @statelabels = @{ $matrix->get_statelabels };
 Function: Retrieves state labels.
 Returns : ARRAY
 Args    : None.

=cut

    sub get_statelabels { $statelabels{ $_[0]->get_id } || [] }

=item get_gapmode()

Returns matrix gapmode.

 Type    : Accessor
 Title   : get_gapmode
 Usage   : do_something() if $matrix->get_gapmode;
 Function: Returns matrix gapmode ( false = missing, true = fifth state )
 Returns : boolean
 Args    : none

=cut

    sub get_gapmode { $gapmode{ $_[0]->get_id } }

=item get_matchchar()

Returns matrix match character.

 Type    : Accessor
 Title   : get_matchchar
 Usage   : my $char = $matrix->get_matchchar;
 Function: Returns matrix match character (default is '.')
 Returns : SCALAR
 Args    : none

=cut

    sub get_matchchar { $matchchar{ $_[0]->get_id } }

=item get_polymorphism()

Returns matrix 'polymorphism' interpretation.

 Type    : Accessor
 Title   : get_polymorphism
 Usage   : do_something() if $matrix->get_polymorphism;
 Function: Returns matrix 'polymorphism' interpretation
           ( false = uncertainty, true = polymorphism )
 Returns : boolean
 Args    : none

=cut

    sub get_polymorphism { $polymorphism{ shift->get_id } }

=item get_respectcase()

Returns matrix case sensitivity interpretation.

 Type    : Accessor
 Title   : get_respectcase
 Usage   : do_something() if $matrix->get_respectcase;
 Function: Returns matrix case sensitivity interpretation
           ( false = disregarded, true = "respectcase" )
 Returns : boolean
 Args    : none

=cut

    sub get_respectcase { $case_sensitivity{ shift->get_id } }

    sub _cleanup : Destructor {
        my $self = shift;
        my $id = $self->get_id;
        for (@inside_out_arrays) {
            delete $_->{$id} if defined $id and exists $_->{$id};
        }
    }

=back

=cut

    # podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::Taxa::TaxaLinker>

This object inherits from L<Bio::Phylo::Taxa::TaxaLinker>, so the
methods defined therein are also applicable to L<Bio::Phylo::Matrices::Matrix>
objects.

=item L<Bio::Phylo::Matrices::TypeSafeData>

This object inherits from L<Bio::Phylo::Matrices::TypeSafeData>, so the
methods defined therein are also applicable to L<Bio::Phylo::Matrices::Matrix>
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

}
1;
