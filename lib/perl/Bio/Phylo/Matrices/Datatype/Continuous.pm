package Bio::Phylo::Matrices::Datatype::Continuous;
use strict;
use warnings;
use base 'Bio::Phylo::Matrices::Datatype';
use Bio::Phylo::Util::CONSTANT
  qw(looks_like_number looks_like_implementor looks_like_instance);
our ( $LOOKUP, $MISSING, $GAP );
{
    my $logger = __PACKAGE__->get_logger;

=head1 NAME

Bio::Phylo::Matrices::Datatype::Continuous - Validator subclass,
no serviceable parts inside

=head1 DESCRIPTION

The Bio::Phylo::Matrices::Datatype::* classes are used to validated data
contained by L<Bio::Phylo::Matrices::Matrix> and L<Bio::Phylo::Matrices::Datum>
objects.

=head1 METHODS

=head2 MUTATORS

=over

=item set_lookup()

Sets the lookup table (no-op for continuous data!).

 Type    : Mutator
 Title   : set_lookup
 Usage   : $obj->set_gap($hashref);
 Function: Sets the symbol for gaps
 Returns : Modified object.
 Args    : Argument must be a hash
           reference that maps allowed
           single character symbols
           (including ambiguity symbols)
           onto the equivalent set of
           non-ambiguous symbols

=cut

    sub set_lookup {
        $logger->info("Can't set lookup table for continuous characters");
        return;
    }

=back

=head2 ACCESSORS

=over

=item get_lookup()

Gets the lookup table (no-op for continuous data!).

 Type    : Accessor
 Title   : get_lookup
 Usage   : my $lookup = $obj->get_lookup;
 Function: Returns the object's lookup hash
 Returns : A hash reference
 Args    : None

=cut

    sub get_lookup {
        $logger->info("Can't get lookup table for continuous characters");
        return;
    }

=back

=head2 TESTS

=over

=item is_valid()

Validates arguments for data validity.

 Type    : Test
 Title   : is_valid
 Usage   : if ( $obj->is_valid($datum) ) {
              # do something
           }
 Function: Returns true if $datum only contains valid characters
 Returns : BOOLEAN
 Args    : A list of Bio::Phylo::Matrices::Datum object, and/or
           character array references, and/or character strings,
           and/or single characters

=cut

    sub is_valid {
        my $self = shift;
        my @data;
        for my $arg (@_) {
            if ( looks_like_implementor $arg, 'get_char' ) {
                push @data, $arg->get_char;
            }
            elsif ( looks_like_instance $arg, 'ARRAY' ) {
                push @data, @{$arg};
            }
            else {
                push @data, @{ $self->split($arg) };
            }
        }
        my $missing = $self->get_missing;
      CHAR_CHECK: for my $char (@data) {
            if ( looks_like_number $char || $char eq $missing ) {
                next CHAR_CHECK;
            }
            else {
                return 0;
            }
        }
        return 1;
    }

=back

=head2 UTILITY METHODS

=over

=item split()

Splits string of characters on whitespaces.

 Type    : Utility method
 Title   : split
 Usage   : $obj->split($string)
 Function: Splits $string into characters
 Returns : An array reference of characters
 Args    : A string

=cut

    sub split {
        my ( $self, $string ) = @_;
        my @array = CORE::split( /\s+/, $string );
        return \@array;
    }

=item join()

Joins array ref of characters to a space-separated string.

 Type    : Utility method
 Title   : join
 Usage   : $obj->join($arrayref)
 Function: Joins $arrayref into a string
 Returns : A string
 Args    : An array reference

=cut

    sub join {
        my ( $self, $array ) = @_;
        return CORE::join ' ', @{$array};
    }
    $MISSING = '?';

=back

=cut

    # podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::Matrices::Datatype>

This object inherits from L<Bio::Phylo::Matrices::Datatype>, so the methods defined
therein are also applicable to L<Bio::Phylo::Matrices::Datatype::Continuous>
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
