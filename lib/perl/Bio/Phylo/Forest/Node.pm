package Bio::Phylo::Forest::Node;
use strict;
use warnings;
use Bio::Phylo::Forest::DrawNodeRole;
use base qw'Bio::Phylo::Forest::DrawNodeRole';
use Bio::Phylo::Util::CONSTANT qw':objecttypes /looks_like/';
use Bio::Phylo::Util::Exceptions 'throw';
use Scalar::Util 'weaken';

# store type constant
my ( $TYPE_CONSTANT, $CONTAINER_CONSTANT ) = ( _NODE_, _TREE_ );

{    

    # @fields array necessary for object destruction
    my @fields = \( my ( %branch_length, %parent, %tree, %rank ) );

=head1 NAME

Bio::Phylo::Forest::Node - Node in a phylogenetic tree

=head1 SYNOPSIS

 # some way to get nodes:
 use Bio::Phylo::IO;
 my $string = '((A,B),C);';
 my $forest = Bio::Phylo::IO->parse(
    -format => 'newick',
    -string => $string
 );

 # prints 'Bio::Phylo::Forest'
 print ref $forest;

 foreach my $tree ( @{ $forest->get_entities } ) {

    # prints 'Bio::Phylo::Forest::Tree'
    print ref $tree;

    foreach my $node ( @{ $tree->get_entities } ) {

       # prints 'Bio::Phylo::Forest::Node'
       print ref $node;

       # node has a parent, i.e. is not root
       if ( $node->get_parent ) {
          $node->set_branch_length(1);
       }

       # node is root
       else {
          $node->set_branch_length(0);
       }
    }
 }

=head1 DESCRIPTION

This module has the getters and setters that alter the state of a 
node object. Useful behaviours (which are also available) are defined
in the L<Bio::Phylo::Forest::NodeRole> package.

=head1 METHODS

=cut

    my $set_raw_parent = sub {
        my ( $self, $parent ) = @_;
        my $id = $self->get_id;
        $parent{$id} = $parent;    # XXX here we modify parent
        weaken $parent{$id} if $parent;
    };
    my $get_parent = sub {
        my $self = shift;
        return $parent{ $self->get_id };
    };
    my $get_children = sub { shift->get_entities };
    my $get_branch_length = sub {
        my $self = shift;
        return $branch_length{ $self->get_id };
    };
    my $set_raw_child = sub {
        my ( $self, $child, $i ) = @_;
        $i = $self->last_index + 1 if not defined $i or $i == -1;
        $self->insert_at_index( $child, $i );    # XXX here we modify children
    };    

=over

=item set_parent()

Sets argument as invocant's parent.

 Type    : Mutator
 Title   : set_parent
 Usage   : $node->set_parent($parent);
 Function: Assigns a node's parent.
 Returns : Modified object.
 Args    : If no argument is given, the current
           parent is set to undefined. A valid
           argument is Bio::Phylo::Forest::Node
           object.

=cut

    sub set_parent : Clonable {
        my ( $self, $parent ) = @_;
        if ( $parent and looks_like_object $parent, $TYPE_CONSTANT ) {
            $parent->set_child($self);
        }
        elsif ( not $parent ) {
            $self->set_raw_parent;
        }
        return $self;
    }

=item set_raw_parent()

Sets argument as invocant's parent. This method does NO 
sanity checks on the rest of the topology. Use with caution.

 Type    : Mutator
 Title   : set_raw_parent
 Usage   : $node->set_raw_parent($parent);
 Function: Assigns a node's parent.
 Returns : Modified object.
 Args    : If no argument is given, the current
           parent is set to undefined. A valid
           argument is Bio::Phylo::Forest::Node
           object.

=cut

	sub set_raw_parent {
		$set_raw_parent->(@_)
	}

=item set_child()

Sets argument as invocant's child.

 Type    : Mutator
 Title   : set_child
 Usage   : $node->set_child($child);
 Function: Assigns a new child to $node
 Returns : Modified object.
 Args    : A valid argument consists of a
           Bio::Phylo::Forest::Node object.

=cut

    sub set_child {
        my ( $self, $child, $i ) = @_;

        # bad args?
        if ( not $child or not looks_like_object $child, $TYPE_CONSTANT ) {
            return;
        }

        # maybe nothing to do?
        if (   not $child
            or $child->get_id == $self->get_id
            or $child->is_child_of($self) )
        {
            return $self;
        }

        # $child_parent is NEVER $self, see above
        my $child_parent = $child->get_parent;

        # child is ancestor: this is obviously problematic, because
        # now we're trying to set a node nearer to the root on the
        # same lineage as the CHILD of a descendant. Because they're
        # on the same lineage it's hard to see how this can be done
        # sensibly. The decision here is to do:
        # 	1. we prune what is to become the parent (now the descendant)
        #	   from its current parent
        #	2. we set this pruned node (and its descendants) as a sibling
        #	   of what is to become the child
        #	3. we prune what is to become the child from its parent
        #	4. we set that pruned child as the child of $self
        if ( $child->is_ancestor_of($self) ) {

            # step 1.
            my $parent_parent = $self->get_parent;
            $parent_parent->prune_child($self);

            # step 2.
            $self->set_raw_parent( $child_parent );    # XXX could be undef
            if ($child_parent) {
                $child_parent->set_raw_child( $self );
            }
        }

        # step 3.
        if ($child_parent) {
            $child_parent->prune_child($child);
        }
        $child->set_raw_parent( $self );

        # now do the insert, first make room by shifting later siblings right
        my $children = $self->get_children;
        if ( defined $i ) {
            for ( my $j = $#{$children} ; $j >= 0 ; $j-- ) {
                my $sibling = $children->[$j];
                $self->set_raw_child( $sibling, $j + 1 );
            }
        }

        # no index was supplied, child becomes last daughter
        else {
            $i = scalar @{$children};
        }

        # step 4.
        $self->set_raw_child( $child, $i );
        return $self;
    }

=item set_raw_child()

Sets argument as invocant's child. This method does NO 
sanity checks on the rest of the topology. Use with caution.

 Type    : Mutator
 Title   : set_raw_child
 Usage   : $node->set_raw_child($child);
 Function: Assigns a new child to $node
 Returns : Modified object.
 Args    : A valid argument consists of a
           Bio::Phylo::Forest::Node object.

=cut

	sub set_raw_child {
		$set_raw_child->(@_);
	}
    
=item set_branch_length()

Sets argument as invocant's branch length.

 Type    : Mutator
 Title   : set_branch_length
 Usage   : $node->set_branch_length(0.423e+2);
 Function: Assigns a node's branch length.
 Returns : Modified object.
 Args    : If no argument is given, the
           current branch length is set
           to undefined. A valid argument
           is a number in any of Perl's formats.

=cut

    sub set_branch_length : Clonable {
        my ( $self, $bl ) = @_;
        my $id = $self->get_id;
        if ( defined $bl && looks_like_number $bl && !ref $bl ) {
            $branch_length{$id} = $bl;
			if ( $bl < 0 ) {
				$self->get_logger->warn("Setting length < 0: $bl");
			}
        }
        elsif ( defined $bl && ( !looks_like_number $bl || ref $bl ) ) {
            throw 'BadNumber' => "Branch length \"$bl\" is a bad number";
        }
        elsif ( !defined $bl ) {
            $branch_length{$id} = undef;
        }
        return $self;
    }

=item set_tree()

Sets what tree invocant belongs to

 Type    : Mutator
 Title   : set_tree
 Usage   : $node->set_tree($tree);
 Function: Sets what tree invocant belongs to
 Returns : Invocant
 Args    : Bio::Phylo::Forest::Tree
 Comments: This method is called automatically 
           when inserting or deleting nodes in
           trees.

=cut

    sub set_tree : Clonable {
        my ( $self, $tree ) = @_;
        my $id = $self->get_id;
        if ($tree) {
            if ( looks_like_object $tree, $CONTAINER_CONSTANT ) {
                $tree{$id} = $tree;
                weaken $tree{$id};
            }
            else {
                throw 'ObjectMismatch' => "$tree is not a tree";
            }
        }
        else {
            $tree{$id} = undef;
        }
        return $self;
    }

=item set_rank()

Sets the taxonomic rank of the node

 Type    : Mutator
 Title   : set_rank
 Usage   : $node->set_rank('genus');
 Function: Sets the taxonomic rank of the node
 Returns : Invocant
 Args    : String
 Comments: Free-form, but highly recommended to use same rank names as in Bio::Taxon

=cut

    
    sub set_rank : Clonable {
    	my ( $self, $rank ) = @_;
    	$rank{$self->get_id} = $rank;
    	return $self;
    }

=item get_parent()

Gets invocant's parent.

 Type    : Accessor
 Title   : get_parent
 Usage   : my $parent = $node->get_parent;
 Function: Retrieves a node's parent.
 Returns : Bio::Phylo::Forest::Node
 Args    : NONE

=cut

    sub get_parent { return $get_parent->(shift) }    

=item get_branch_length()

Gets invocant's branch length.

 Type    : Accessor
 Title   : get_branch_length
 Usage   : my $branch_length = $node->get_branch_length;
 Function: Retrieves a node's branch length.
 Returns : FLOAT
 Args    : NONE
 Comments: Test for "defined($node->get_branch_length)"
           for zero-length (but defined) branches. Testing
           "if ( $node->get_branch_length ) { ... }"
           yields false for zero-but-defined branches!

=cut

    sub get_branch_length { return $get_branch_length->(shift) }

=item get_children()

Gets invocant's immediate children.

 Type    : Query
 Title   : get_children
 Usage   : my @children = @{ $node->get_children };
 Function: Returns an array reference of immediate
           descendants, ordered from left to right.
 Returns : Array reference of
           Bio::Phylo::Forest::Node objects.
 Args    : NONE

=cut

    sub get_children { return $get_children->(shift) }
    
=item get_tree()

Returns the tree invocant belongs to

 Type    : Query
 Title   : get_tree
 Usage   : my $tree = $node->get_tree;
 Function: Returns the tree $node belongs to
 Returns : Bio::Phylo::Forest::Tree
 Args    : NONE

=cut

    sub get_tree {
        my $self = shift;
        my $id   = $self->get_id;
        return $tree{$id};
    }

=item get_rank()

Gets the taxonomic rank of the node

 Type    : Mutator
 Title   : get_rank
 Usage   : my $rank = $node->get_rank;
 Function: Gets the taxonomic rank of the node
 Returns : String
 Args    : NONE
 Comments: 

=cut
    
    sub get_rank { $rank{shift->get_id} }

=begin comment

 Type    : Internal method
 Title   : _json_data
 Usage   : $node->_json_data;
 Function: Populates a data structure to be serialized as JSON
 Returns : 
 Args    :

=end comment

=cut
    
    sub _json_data {
    	my $self = shift;
    	my %result = %{ $self->SUPER::_json_data };
    	$result{'length'}   = $self->get_branch_length if defined $self->get_branch_length;
    	$result{'rank'}     = $self->get_rank if $self->get_rank;
    	$result{'children'} = [ map { $_->_json_data } @{ $self->get_children } ];
    	return \%result;
    }

=begin comment

 Type    : Internal method
 Title   : _cleanup
 Usage   : $trees->_cleanup;
 Function: Called during object destruction, for cleanup of instance data
 Returns : 
 Args    :

=end comment

=cut

    sub _cleanup : Destructor {
        my $self = shift;
        my $id   = $self->get_id;
        for my $field (@fields) {
            delete $field->{$id};
        }
    }
    
}

=back

    # podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::Forest::NodeRole>

This object inherits from L<Bio::Phylo::Forest::NodeRole>, so methods
defined there are also applicable here.

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
