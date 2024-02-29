package Bio::Phylo::Forest::Tree;
use strict;
use warnings;
use Bio::Phylo::Forest::DrawTreeRole;
use base qw'Bio::Phylo::Forest::DrawTreeRole';
{
    my @fields = \( my ( %default, %rooted ) );

=head1 NAME

Bio::Phylo::Forest::Tree - Phylogenetic tree

=head1 SYNOPSIS

 # some way to get a tree
 use Bio::Phylo::IO;
 my $string = '((A,B),C);';
 my $forest = Bio::Phylo::IO->parse(
    -format => 'newick',
    -string => $string
 );
 my $tree = $forest->first;

 # do something:
 print $tree->calc_imbalance;

 # prints "1"

=head1 DESCRIPTION

The package has the getters and setters that alter the
internal state of a tree object. Additional tree-related
behaviours (which are available also) are defined in the
package L<Bio::Phylo::Forest::TreeRole>.

=head1 METHODS

=head2 MUTATORS

=over

=item set_as_unrooted()

Sets tree to be interpreted as unrooted.

 Type    : Mutator
 Title   : set_as_unrooted
 Usage   : $tree->set_as_unrooted;
 Function: Sets tree to be interpreted as unrooted.
 Returns : $tree
 Args    : NONE
 Comments: This is a flag to indicate that the invocant
           is interpreted to be unrooted (regardless of
           topology). The object is otherwise unaltered,
           this method is only here to capture things such
           as the [&U] token in nexus files.

=cut

    sub set_as_unrooted {
        my $self = shift;
        $rooted{ $self->get_id } = 1;
        return $self;
    }

=item set_as_default()

Sets tree to be the default tree in a forest

 Type    : Mutator
 Title   : set_as_default
 Usage   : $tree->set_as_default;
 Function: Sets tree to be default tree in forest
 Returns : $tree
 Args    : NONE
 Comments: This is a flag to indicate that the invocant
           is the default tree in a forest, i.e. to
           capture the '*' token in nexus files.

=cut

    sub set_as_default {
        my $self = shift;
        if ( my $forest = $self->_get_container ) {
            if ( my $tree = $forest->get_default_tree ) {
                $tree->set_not_default;
            }
        }
        $default{ $self->get_id } = 1;
        return $self;
    }

=item set_not_default()

Sets tree to NOT be the default tree in a forest

 Type    : Mutator
 Title   : set_not_default
 Usage   : $tree->set_not_default;
 Function: Sets tree to not be default tree in forest
 Returns : $tree
 Args    : NONE
 Comments: This is a flag to indicate that the invocant
           is the default tree in a forest, i.e. to
           capture the '*' token in nexus files.

=cut

    sub set_not_default {
        my $self = shift;
        $default{ $self->get_id } = 0;
        return $self;
    }

=back

=head2 TESTS

=over

=item is_default()

Test if tree is default tree.

 Type    : Test
 Title   : is_default
 Usage   : if ( $tree->is_default ) {
              # do something
           }
 Function: Tests whether the invocant 
           object is the default tree in the forest.
 Returns : BOOLEAN
 Args    : NONE

=cut

    sub is_default {
        my $self = shift;
        return !!$default{ $self->get_id };
    }

=item is_rooted()

Test if tree is rooted.

 Type    : Test
 Title   : is_rooted
 Usage   : if ( $tree->is_rooted ) {
              # do something
           }
 Function: Tests whether the invocant 
           object is rooted.
 Returns : BOOLEAN
 Args    : NONE
 Comments: A tree is considered unrooted if:
           - set_as_unrooted has been set, or
           - the basal split is a polytomy

=cut

    sub is_rooted {
        my $self = shift;
        my $id   = $self->get_id;
        if ( defined $rooted{$id} ) {
            return ! $rooted{$id};
        }
        if ( my $root = $self->get_root ) {
            if ( my $children = $root->get_children ) {
                return scalar @{$children} <= 2;
            }
            return 1;
        }
        return 0;
    }

    # the following methods are purely for internal consumption
    sub _cleanup : Destructor {
        my $self = shift;
        if ( defined( my $id = $self->get_id ) ) {
            for my $field (@fields) {
                delete $field->{$id};
            }
        }
    }
    
    sub _set_rooted : Clonable {
        my ( $self, $r ) = @_;
        $rooted{$self->get_id} = $r;
        return $self;
    }
    
    sub _get_rooted { $rooted{shift->get_id} }
    
    sub _set_default : Clonable {
        my ( $self, $d ) = @_;
        $default{$self->get_id} = $d;
        return $self;
    }
    
    sub _get_default { $default{shift->get_id} }

=back

=cut

    # podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::Forest::TreeRole>

The L<Bio::Phylo::Forest::Tree> package inherits from
the L<Bio::Phylo::Forest::TreeRole> package, so the methods defined
therein also apply to trees.

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
