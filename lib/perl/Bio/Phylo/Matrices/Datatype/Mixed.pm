package Bio::Phylo::Matrices::Datatype::Mixed;
use strict;
use warnings;
use base 'Bio::Phylo::Matrices::Datatype';
use Bio::Phylo::Util::CONSTANT '/looks_like/';
use Bio::Phylo::Util::Exceptions 'throw';
{

=head1 NAME

Bio::Phylo::Matrices::Datatype::Mixed - Validator subclass,
no serviceable parts inside

=head1 DESCRIPTION

The Bio::Phylo::Matrices::Datatype::* classes are used to validate data
contained by L<Bio::Phylo::Matrices::Matrix> and L<Bio::Phylo::Matrices::Datum>
objects.

=cut

    my @fields = \( my ( %range, %missing, %gap ) );

    sub _new {
        my ( $package, $self, $ranges ) = @_;
        if ( not looks_like_instance $ranges, 'ARRAY' ) {
            throw 'BadArgs' =>
              "No type ranges specified for 'mixed' data type!";
        }
        my $id = $self->get_id;
        $range{$id}   = [];
        $missing{$id} = '?';
        $gap{$id}     = '-';
        my $start = 0;
        for ( my $i = 0 ; $i <= ( $#{$ranges} - 1 ) ; $i += 2 ) {
            my $type = $ranges->[$i];
            my $arg  = $ranges->[ $i + 1 ];
            my ( @args, $length );
            if ( looks_like_instance $arg, 'HASH' ) {
                $length = $arg->{'-length'};
                @args   = @{ $arg->{'-args'} };
            }
            else {
                $length = $arg;
            }
            my $end = $length + $start - 1;
            my $obj = Bio::Phylo::Matrices::Datatype->new( $type, @args );
            $range{$id}->[$_] = $obj for ( $start .. $end );
            $start = ++$end;
        }
        return bless $self, $package;
    }

=head1 METHODS

=head2 MUTATORS

=over

=item set_missing()

Sets the symbol for missing data.

 Type    : Mutator
 Title   : set_missing
 Usage   : $obj->set_missing('?');
 Function: Sets the symbol for missing data
 Returns : Modified object.
 Args    : Argument must be a single
           character, default is '?'

=cut

    sub set_missing {
        my ( $self, $missing ) = @_;
        if ( not $missing eq $self->get_gap ) {
            $missing{ $self->get_id } = $missing;
        }
        else {
            throw 'BadArgs' =>
              "Missing character '$missing' already in use as gap character";
        }
        return $self;
    }

=item set_gap()

Sets the symbol for gaps.

 Type    : Mutator
 Title   : set_gap
 Usage   : $obj->set_gap('-');
 Function: Sets the symbol for gaps
 Returns : Modified object.
 Args    : Argument must be a single
           character, default is '-'

=cut

    sub set_gap {
        my ( $self, $gap ) = @_;
        if ( not $gap eq $self->get_missing ) {
            $gap{ $self->get_id } = $gap;
        }
        else {
            throw 'BadArgs' =>
              "Gap character '$gap' already in use as missing character";
        }
        return $self;
    }

=back

=head2 ACCESSORS

=over

=item get_missing()

Returns the object's missing data symbol.

 Type    : Accessor
 Title   : get_missing
 Usage   : my $missing = $obj->get_missing;
 Function: Returns the object's missing data symbol
 Returns : A string
 Args    : None

=cut

    sub get_missing { return $missing{ shift->get_id } }

=item get_gap()

Returns the object's gap symbol.

 Type    : Accessor
 Title   : get_gap
 Usage   : my $gap = $obj->get_gap;
 Function: Returns the object's gap symbol
 Returns : A string
 Args    : None

=cut

    sub get_gap { return $gap{ shift->get_id } }
    my $get_ranges = sub { $range{ shift->get_id } };

=item get_type()

Returns the object's datatype as string.

 Type    : Accessor
 Title   : get_type
 Usage   : my $type = $obj->get_type;
 Function: Returns the object's datatype
 Returns : A string
 Args    : None

=cut

    sub get_type {
        my $self   = shift;
        my $string = 'mixed(';
        my $last;
        my $range = $self->$get_ranges;
      MODEL_RANGE_CHECK: for my $i ( 0 .. $#{$range} ) {
            if ( $i == 0 ) {
                $string .= $range->[$i]->get_type . ":1-";
                $last = $range->[$i];
            }
            elsif ( $range->[$i] != $last ) {
                $last = $range->[$i];
                $string .= "$i, " . $last->get_type . ":" . ( $i + 1 ) . "-";
            }
            else {
                next MODEL_RANGE_CHECK;
            }
        }
        $string .= scalar( @{$range} ) . ")";
        return $string;
    }

=item get_type_for_site()

Returns type object for site number.

 Type    : Accessor
 Title   : get_type_for_site
 Usage   : my $type = $obj->get_type_for_site(1);
 Function: Returns data type object for site
 Returns : A Bio::Phylo::Matrices::Datatype object
 Args    : None

=cut

    sub get_type_for_site {
        my ( $self, $i ) = @_;
        if ( exists $range{ $self->get_id }->[$i] ) {
            return $range{ $self->get_id }->[$i];
        }
        else {
            return $range{ $self->get_id }->[-1];
        }
    }

=back

=head2 TESTS

=over

=item is_same()

Compares data type objects.

 Type    : Test
 Title   : is_same
 Usage   : if ( $obj->is_same($obj1) ) {
              # do something
           }
 Function: Returns true if $obj1 contains the same validation rules
 Returns : BOOLEAN
 Args    : A Bio::Phylo::Matrices::Datatype::* object

=cut

    sub is_same {
        my ( $self, $obj ) = @_;
        my $id = $self->get_id;
        return 1 if $id == $obj->get_id;
        return 0 if $self->get_type ne $obj->get_type;
        return 0 if $self->get_gap ne $obj->get_gap;
        return 0 if $self->get_missing ne $obj->get_missing;
        for my $i ( 0 .. $#{ $range{ $self->get_id } } ) {
            if ( my $subtype = $range{ $self->get_id }->[$i] ) {
                return 0
                  if not $subtype->is_same( $obj->get_type_for_site($i) );
            }
        }
        return 1;
    }

=item is_valid()

Returns true if argument only contains valid characters

 Type    : Test
 Title   : is_valid
 Usage   : if ( $obj->is_valid($datum) ) {
              # do something
           }
 Function: Returns true if $datum only contains valid characters
 Returns : BOOLEAN
 Args    : A Bio::Phylo::Matrices::Datum object

=cut

    sub is_valid {
        my $self  = shift;
        my $datum = $_[0];
        my $is_datum_object;
        my ( $start, $end );
        if (
            looks_like_implementor $datum,
            'get_position' and looks_like_implementor $datum,
            'get_length'
          )
        {
            ( $start, $end ) =
              ( $datum->get_position - 1, $datum->get_length - 1 );
            $is_datum_object = 1;
        }
        else {
            $start = 0;
            $end   = $#_;
        }
        my $ranges = $self->$get_ranges;
        my $type;
      MODEL_RANGE_CHECK: for my $i ( $start .. $end ) {
            if ( not $type ) {
                $type = $ranges->[$i];
            }
            elsif ( $type != $ranges->[$i] ) {

                #die; # needs to slice
                return 1;    # TODO
            }
            else {
                next MODEL_RANGE_CHECK;
            }
        }
        if ($is_datum_object) {
            return $type->is_valid($datum);
        }
        else {
            return 1;        # FIXME
        }
    }

    sub DESTROY {
        my $self = shift;
        my $id   = $self->get_id;
        for my $field (@fields) {
            delete $field->{$id};
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

=item L<Bio::Phylo::Matrices::Datatype>

This object inherits from L<Bio::Phylo::Matrices::Datatype>, so the methods defined
therein are also applicable to L<Bio::Phylo::Matrices::Datatype::Mixed>
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
