package Bio::Phylo::Matrices::TypeSafeData;
use strict;
use warnings;
use base 'Bio::Phylo::Listable';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw'_MATRIX_ /looks_like/';
use Bio::Phylo::Matrices::Datatype;
{
    my $logger = __PACKAGE__->get_logger;
    my %type;
    my $MATRIX_CONSTANT = _MATRIX_;

=head1 NAME

Bio::Phylo::Matrices::TypeSafeData - Superclass for objects that contain
character data

=head1 SYNOPSIS

 # No direct usage

=head1 DESCRIPTION

This is a superclass for objects holding character data. Objects that inherit
from this class (typically matrices and datum objects) yield functionality to
handle datatype objects and use them to validate data such as DNA sequences,
continuous data etc.

=head1 METHODS

=head2 CONSTRUCTOR

=over

=item new()

TypeSafeData constructor.

 Type    : Constructor
 Title   : new
 Usage   : No direct usage, is called by child class;
 Function: Instantiates a Bio::Phylo::Matrices::TypeSafeData
 Returns : a Bio::Phylo::Matrices::TypeSafeData child class
 Args    : -type        => (data type - required)
           Optional:
           -missing     => (the symbol for missing data)
           -gap         => (the symbol for gaps)
           -lookup      => (a character state lookup hash)
           -type_object => (a datatype object)

=cut    

    sub new : Constructor {

        # is child class
        my $class = shift;

        # process args
        my %args = looks_like_hash @_;

        # notify user
        if ( not $args{'-type'} and not $args{'-type_object'} ) {
            $logger->info("No data type provided, will use 'standard'");
            unshift @_, '-type', 'standard';
        }
        if ( $args{'-characters'} ) {
            if ( $args{'-type'} ) {
                $args{'-characters'}->set_type( $args{'-type'} );
            }
            elsif ( $args{'-type_object'} ) {
                $args{'-characters'}->set_type_object( $args{'-type_object'} );
            }
        }

        # notify user
        $logger->debug("constructor called for '$class'");

        # go up inheritance tree, eventually get an ID
        return $class->SUPER::new(@_);
    }

=back

=head2 MUTATORS

=over

=item set_type()

Set data type.

 Type    : Mutator
 Title   : set_type
 Usage   : $obj->set_type($type);
 Function: Sets the object's datatype.
 Returns : Modified object.
 Args    : Argument must be a string, one of
           continuous, custom, dna, mixed,
           protein, restriction, rna, standard

=cut

    sub set_type {
        my $self = shift;
        my $arg  = shift;
        my ( $type, @args );
        if ( looks_like_instance( $arg, 'ARRAY' ) ) {
            @args = @{$arg};
            $type = shift @args;
        }
        else {
            @args = @_;
            $type = $arg;
        }
        $logger->info("setting type '$type'");
        my $obj = Bio::Phylo::Matrices::Datatype->new( $type, @args );
        $self->set_type_object($obj);
        if ( UNIVERSAL::can($self,'_type') and $self->_type == $MATRIX_CONSTANT ) {
            for my $row ( @{ $self->get_entities } ) {
                $row->set_type_object($obj);
            }
        }
        return $self;
    }

=item set_missing()

Set missing data symbol.

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
        if ( $self->can('get_matchchar') and $self->get_matchchar and $missing eq $self->get_matchchar )
        {
            throw 'BadArgs' =>
              "Missing character '$missing' already in use as match character";
        }
        $logger->info("setting missing '$missing'");
        $self->get_type_object->set_missing($missing);
        $self->validate;
        return $self;
    }

=item set_gap()

Set gap data symbol.

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
        if ( $self->can('get_matchchar') and $self->get_matchchar and $self->get_matchchar eq $gap ) {
            throw 'BadArgs' =>
              "Gap character '$gap' already in use as match character";
        }
        $logger->info("setting gap '$gap'");
        $self->get_type_object->set_gap($gap);
        $self->validate;
        return $self;
    }

=item set_lookup()

Set ambiguity lookup table.

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
        my ( $self, $lookup ) = @_;
        $logger->info("setting character state lookup hash");
        $self->get_type_object->set_lookup($lookup);
        $self->validate;
        return $self;
    }

=item set_type_object()

Set data type object.

 Type    : Mutator
 Title   : set_type_object
 Usage   : $obj->set_gap($obj);
 Function: Sets the datatype object
 Returns : Modified object.
 Args    : Argument must be a subclass
           of Bio::Phylo::Matrices::Datatype

=cut

    sub set_type_object : Clonable DeepClonable {
        my ( $self, $obj ) = @_;
        $logger->info("setting character type object");
        $type{ $self->get_id } = $obj;
        eval { $self->validate };
        if ($@) {
            undef($@);
            if ( my @char = $self->get_char ) {
                $self->clear;
                $logger->warn(
"Data contents of $self were invalidated by new type object."
                );
            }
        }
        return $self;
    }

=back

=head2 ACCESSORS

=over

=item get_type()

Get data type.

 Type    : Accessor
 Title   : get_type
 Usage   : my $type = $obj->get_type;
 Function: Returns the object's datatype
 Returns : A string
 Args    : None

=cut

    sub get_type {
        my $to = shift->get_type_object;
        if ($to) {
            return $to->get_type;
        }
        else {
            throw 'API' => "Missing data type object!";
        }
    }

=item get_missing()

Get missing data symbol.

 Type    : Accessor
 Title   : get_missing
 Usage   : my $missing = $obj->get_missing;
 Function: Returns the object's missing data symbol
 Returns : A string
 Args    : None

=cut

    sub get_missing {
        my $to = shift->get_type_object;
        if ($to) {
            return $to->get_missing;
        }
        else {
            throw 'API' => "Missing data type object!";
        }
    }

=item get_gap()

Get gap symbol.

 Type    : Accessor
 Title   : get_gap
 Usage   : my $gap = $obj->get_gap;
 Function: Returns the object's gap symbol
 Returns : A string
 Args    : None

=cut

    sub get_gap { shift->get_type_object->get_gap }

=item get_lookup()

Get ambiguity lookup table.

 Type    : Accessor
 Title   : get_lookup
 Usage   : my $lookup = $obj->get_lookup;
 Function: Returns the object's lookup hash
 Returns : A hash reference
 Args    : None

=cut

    sub get_lookup { shift->get_type_object->get_lookup }

=item get_type_object()

Get data type object.

 Type    : Accessor
 Title   : get_type_object
 Usage   : my $obj = $obj->get_type_object;
 Function: Returns the object's linked datatype object
 Returns : A subclass of Bio::Phylo::Matrices::Datatype
 Args    : None

=cut

    sub get_type_object { $type{ $_[0]->get_id } }

=back

=head2 INTERFACE METHODS

=over

=item validate()

Validates the object's contents

 Type    : Interface method
 Title   : validate
 Usage   : $obj->validate
 Function: Validates the object's contents
 Returns : True or throws Bio::Phylo::Util::Exceptions::InvalidData
 Args    : None
 Comments: This is an abstract method, i.e. this class doesn't
           implement the method, child classes have to

=cut

    sub validate {
        shift->_validate;
    }

    sub _validate {
        throw 'NotImplemented' => 'Not implemented!';
    }

    sub _cleanup {
        my $self = shift;
        if ( $self and defined( my $id = $self->get_id ) ) {
            delete $type{ $self->get_id };
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

=item L<Bio::Phylo::Listable>

This object inherits from L<Bio::Phylo::Listable>, so the methods defined 
therein are also applicable to L<Bio::Phylo::Matrices::TypeSafeData> objects.

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
