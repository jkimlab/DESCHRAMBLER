package Bio::Phylo::Identifiable;
use Bio::Phylo::Util::IDPool;
use Bio::Phylo::Util::Exceptions 'throw';

use strict;
use warnings;

=head1 NAME

Bio::Phylo::Identifiable - Objects with unique identifiers

=head1 SYNOPSIS

 # Actually, you would almost never use this module directly. This is 
 # the base class for other modules.
 use Bio::Phylo::Identifiable;
 
 my $obj = Bio::Phylo::Identifiable->new;
 print $obj->get_id;


=head1 DESCRIPTION

This is the base class for objects in the Bio::Phylo package 
that need unique identifiers.

=head1 METHODS

=head2 CONSTRUCTOR

=over

=item new()

 Type    : Constructor
 Title   : new
 Usage   : my $phylo = Bio::Phylo::Identifiable->new;
 Function: Instantiates Bio::Phylo::Identifiable object
 Returns : a Bio::Phylo::Identifiable object 
 Args    : NONE

=cut

sub new {
    my $class = shift;

    # happens only and exactly once because this
    # root class is visited from every constructor
    my $self = Bio::Phylo::Util::IDPool->_initialize();

    # bless in child class, not __PACKAGE__
    bless $self, $class;
    return $self;
}

=item get_id()

Gets invocant's UID.

 Type    : Accessor
 Title   : get_id
 Usage   : my $id = $obj->get_id;
 Function: Returns the object's unique ID
 Returns : INT
 Args    : None

=cut

sub get_id {
    my ($self) = @_;
    if ( UNIVERSAL::isa( $self, 'SCALAR' ) ) {
        return $$self;
    }
    else {
        throw 'API' => "Not a SCALAR reference";
    }
}

=item is_equal()

Compares invocant's UID with argument's UID

 Type    : Test
 Title   : is_equal
 Usage   : do_something() if $obj->is_equal($other);
 Function: Compares objects by UID
 Returns : BOOLEAN
 Args    : Another object to compare with

=cut

sub is_equal {
	my ($self,$other) = @_;
	return $self->get_id == $other->get_id;
}

=back

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

Also see the manual: L<Bio::Phylo::Manual> and L<http://rutgervos.blogspot.com>

=head1 CITATION

If you use Bio::Phylo in published research, please cite it:

B<Rutger A Vos>, B<Jason Caravas>, B<Klaas Hartmann>, B<Mark A Jensen>
and B<Chase Miller>, 2011. Bio::Phylo - phyloinformatic analysis using Perl.
I<BMC Bioinformatics> B<12>:63.
L<http://dx.doi.org/10.1186/1471-2105-12-63>

=cut

1;
