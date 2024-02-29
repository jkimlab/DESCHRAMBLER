package Bio::Phylo::Set;
use strict;
use warnings;
use base 'Bio::Phylo::Listable';
use Bio::Phylo::Util::CONSTANT qw'_NONE_ _SET_';

=head1 NAME

Bio::Phylo::Set - Subset of the parts inside a container 

=head1 SYNOPSIS

 use Bio::Phylo::Factory;
 my $fac = Bio::Phylo::Factory->new;
 
 my $forest = $fac->create_forest;
 my $tree = $fac->create_tree;
 $forest->insert($tree);
 
 my $set = $fac->create_set( -name => 'TreeSet1' );
 $forest->add_set($set);
 $forest->add_to_set($tree,$set); # $tree is now part of TreeSet1

=head1 DESCRIPTION

Many Bio::Phylo objects are segmented: they contain one or more subparts 
of the same type. For example, a matrix contains multiple rows; each row 
contains multiple cells; a tree contains nodes, and so on. Segmented objects
all inherit from L<Bio::Phylo::Listable>. In many cases it is useful to be
able to define subsets of the contents of segmented objects, for example
sets of taxon objects inside a taxa block. The Bio::Phylo::Listable object
allows this through a number of methods (add_set, remove_set, add_to_set,
remove_from_set and so on). Those methods delegate the actual management of the set
contents to the Bio::Phylo::Set object, the class whose documentation you're
reading now. Consult the documentation for L<Bio::Phylo::Listable/SETS MANAGEMENT> 
for more information on how to use this feature.

=head1 METHODS

=head2 CONSTRUCTOR

=over

=item new()

 Type    : Constructor
 Title   : new
 Usage   : my $anno = Bio::Phylo::Set->new;
 Function: Initializes a Bio::Phylo::Set object.
 Returns : A Bio::Phylo::Set object.
 Args    : optional constructor arguments are key/value
 		   pairs where the key corresponds with any of
 		   the methods that starts with set_ (i.e. mutators) 
 		   and the value is the permitted argument for such 
 		   a method. The method name is changed such that,
 		   in order to access the set_value($val) method
 		   in the constructor, you would pass -value => $val

=cut

{
    my $NONE = _NONE_;
    my $TYPE = _SET_;

    #     sub new {
    #         return shift->SUPER::new( '-tag' => 'class', @_ );
    #     }

=back

=head2 TESTS

=over

=item can_contain()

Tests if argument can be inserted in invocant.

 Type    : Test
 Title   : can_contain
 Usage   : &do_something if $listable->can_contain( $obj );
 Function: Tests if $obj can be inserted in $listable
 Returns : BOOL
 Args    : An $obj to test

=cut

    sub can_contain {
        my ( $self, @obj ) = @_;
        for my $obj (@obj) {
            return 0 if ref $obj;
        }
        return 1;
    }
    sub _container { $NONE }
    sub _type      { $TYPE }
    sub _tag       { 'set' }
}

=back

=cut

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

Also see the manual: L<Bio::Phylo::Manual> and L<http://rutgervos.blogspot.com>.

Consult the documentation for L<Bio::Phylo::Listable/SETS MANAGEMENT> for more info 
on how to define subsets of the contents of segmented objects.

=head2 Superclasses

=over

=item L<Bio::Phylo::Listable>

This object inherits from L<Bio::Phylo::Listable>, so methods
defined there are also applicable here.

=back

=head1 CITATION

If you use Bio::Phylo in published research, please cite it:

B<Rutger A Vos>, B<Jason Caravas>, B<Klaas Hartmann>, B<Mark A Jensen>
and B<Chase Miller>, 2011. Bio::Phylo - phyloinformatic analysis using Perl.
I<BMC Bioinformatics> B<12>:63.
L<http://dx.doi.org/10.1186/1471-2105-12-63>

=cut

1;
