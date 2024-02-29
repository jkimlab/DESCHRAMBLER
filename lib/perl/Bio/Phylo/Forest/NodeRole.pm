package Bio::Phylo::Forest::NodeRole;
use strict;
use warnings;
use Bio::Phylo::Util::MOP;
use base qw'Bio::Phylo::Taxa::TaxonLinker Bio::Phylo::Listable';
use Bio::Phylo::Util::OptionalInterface 'Bio::Tree::NodeI';
use Bio::Phylo::Util::CONSTANT qw':objecttypes /looks_like/';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::Math ':all';
use Bio::Phylo::NeXML::Writable;
use Bio::Phylo::Factory;
use Scalar::Util 'weaken';
use List::Util qw[sum min max];
no warnings 'recursion';

my $LOADED_WRAPPERS = 0;

# store type constant
my ( $TYPE_CONSTANT, $CONTAINER_CONSTANT ) = ( _NODE_, _TREE_ );

# logger singleton
my $logger = __PACKAGE__->get_logger;

# factory object
my $fac = Bio::Phylo::Factory->new;

=head1 NAME

Bio::Phylo::Forest::NodeRole - Extra behaviours for a node in a phylogenetic tree

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

This module defines a node object and its methods. The node is fairly
syntactically rich in terms of navigation, and additional getters are provided to
further ease navigation from node to node. Typical first daughter -> next sister
traversal and recursion is possible, but there are also shrinkwrapped methods
that return for example all terminal descendants of the focal node, or all
internals, etc.

Node objects are inserted into tree objects, although technically the tree
object is only a container holding all the nodes together. Unless there are
orphans all nodes can be reached without recourse to the tree object.

=head1 METHODS

=over

=item new()

Node constructor.

 Type    : Constructor
 Title   : new
 Usage   : my $node = Bio::Phylo::Forest::Node->new;
 Function: Instantiates a Bio::Phylo::Forest::Node object
 Returns : Bio::Phylo::Forest::Node
 Args    : All optional:
           -parent          => $parent,
           -taxon           => $taxon,
           -branch_length   => 0.423e+2,
           -first_daughter  => $f_daughter,
           -last_daughter   => $l_daughter,
           -next_sister     => $n_sister,
           -previous_sister => $p_sister,
           -name            => 'node_name',
           -desc            => 'this is a node',
           -score           => 0.98,
           -generic         => {
                -posterior => 0.98,
                -bootstrap => 0.80
           }

=cut

    sub new : Constructor {

        # could be child class
        my $class = shift;

        # process bioperl args
        my %args = looks_like_hash @_;
        if ( exists $args{'-leaf'} ) {
            delete $args{'-leaf'};
        }
        if ( exists $args{'-id'} ) {
            my $name = $args{'-id'};
            delete $args{'-id'};
            $args{'-name'} = $name;
        }
        if ( exists $args{'-nhx'} ) {
            my $hash = $args{'-nhx'};
            delete $args{'-nhx'};
            $args{'-generic'} = $hash;
        }

        # 		if ( not exists $args{'-tag'} ) {
        # 			$args{'-tag'} = __PACKAGE__->_tag;
        # 		}
        # go up inheritance tree, eventually get an ID
        my $self = $class->SUPER::new(%args);
        if ( not $LOADED_WRAPPERS ) {
            eval do { local $/; <DATA> };
            $LOADED_WRAPPERS++;
        }
        return $self;
    }

=item new_from_bioperl()

Node constructor from bioperl L<Bio::Tree::NodeI> argument.

 Type    : Constructor
 Title   : new_from_bioperl
 Usage   : my $node =
           Bio::Phylo::Forest::Node->new_from_bioperl(
               $bpnode
           );
 Function: Instantiates a Bio::Phylo::Forest::Node object
           from a bioperl node object.
 Returns : Bio::Phylo::Forest::Node
 Args    : An objects that implements Bio::Tree::NodeI
 Notes   : The following BioPerl properties are copied:
           BioPerl output:        Bio::Phylo output:
           ------------------------------------------------
           id                     get_name
           branch_length          get_branch_length
           description            get_desc
           bootstrap              get_generic('bootstrap')
           
           In addition all BioPerl tags and values are copied
           to set_generic( 'tag' => 'value' );

=cut

    sub new_from_bioperl {
        my ( $class, $bpnode ) = @_;
        my $node = $class->new;

        # copy name
        my $name = $bpnode->id;
        $node->set_name($name) if defined $name;

        # copy branch length
        my $branch_length = $bpnode->branch_length;
        $node->set_branch_length($branch_length) if defined $branch_length;

        # copy description
        my $desc = $bpnode->description;
        $node->set_desc($desc) if defined $desc;

        # copy bootstrap
        my $bootstrap = $bpnode->bootstrap;
        $node->set_score($bootstrap)
          if defined $bootstrap and looks_like_number $bootstrap;

        # copy other tags
        for my $tag ( $bpnode->get_all_tags ) {
            my @values = $bpnode->get_tag_values($tag);
            $node->set_generic( $tag => \@values );
        }
        return $node;
    }

=item prune_child()

Removes argument child node (and its descendants) from invocants children.

 Type    : Mutator
 Title   : prune_child
 Usage   : $parent->prune_child($child);
 Function: Removes $child (and its descendants) from $parent's children
 Returns : Modified object.
 Args    : A valid argument is Bio::Phylo::Forest::Node object.

=cut

    sub prune_child {
        my ( $self, $child ) = @_;
        $self->delete($child);
        return $self;
    }

=item collapse()

Collapse node.

 Type    : Mutator
 Title   : collapse
 Usage   : $node->collapse;
 Function: Attaches invocant's children to invocant's parent.
 Returns : Modified object.
 Args    : NONE
 Comments: If defined, adds invocant's branch 
           length to that of its children. If
           $node is in a tree, removes itself
           from that tree.

=cut

    sub collapse {
        my $self = shift;

        # can't collapse root
        if ( my $parent = $self->get_parent ) {

            # can't collapse terminal nodes
            if ( my @children = @{ $self->get_children } ) {

                # add node's branch length to that of children
                my $length = $self->get_branch_length;
                for my $child (@children) {
                    if ( defined $length ) {
                        my $child_length = $child->get_branch_length || 0;
                        $child->set_branch_length( $length + $child_length );
                    }

                    # attach children to node's parent
                    $child->set_parent($parent);
                }

                # prune node from parent
                $parent->prune_child($self);

                # delete node from tree
                if ( my $tree = $self->get_tree ) {
                    $tree->delete($self);
                }
            }
            else {
                return $self;
            }
        }
        else {
            return $self;
        }
    }

=item set_first_daughter()

Sets argument as invocant's first daughter.

 Type    : Mutator
 Title   : set_first_daughter
 Usage   : $node->set_first_daughter($f_daughter);
 Function: Assigns a node's leftmost daughter.
 Returns : Modified object.
 Args    : Undefines the first daughter if no
           argument given. A valid argument is
           a Bio::Phylo::Forest::Node object.

=cut

    sub set_first_daughter {
        my ( $self, $fd ) = @_;
        $self->set_child( $fd, 0 );
        return $self;
    }

=item set_last_daughter()

Sets argument as invocant's last daughter.

 Type    : Mutator
 Title   : set_last_daughter
 Usage   : $node->set_last_daughter($l_daughter);
 Function: Assigns a node's rightmost daughter.
 Returns : Modified object.
 Args    : A valid argument consists of a
           Bio::Phylo::Forest::Node object. If
           no argument is given, the value is
           set to undefined.

=cut

    sub set_last_daughter {
        my ( $self, $ld ) = @_;
        $self->set_child( $ld, scalar @{ $self->get_children } );
        return $self;
    }

=item set_previous_sister()

Sets argument as invocant's previous sister.

 Type    : Mutator
 Title   : set_previous_sister
 Usage   : $node->set_previous_sister($p_sister);
 Function: Assigns a node's previous sister (to the left).
 Returns : Modified object.
 Args    : A valid argument consists of
           a Bio::Phylo::Forest::Node object.
           If no argument is given, the value
           is set to undefined.

=cut

    sub set_previous_sister {
        my ( $self, $ps ) = @_;
        if ( $ps and looks_like_object $ps, $TYPE_CONSTANT ) {
            if ( my $parent = $self->get_parent ) {
                my $children = $parent->get_children;
                my $j        = 0;
              FINDSELF: for ( my $i = $#{$children} ; $i >= 0 ; $i-- ) {
                    if ( $children->[$i] == $self ) {
                        $j = $i - 1;
                        last FINDSELF;
                    }
                }
                $j = 0 if $j == -1;
                $parent->set_child( $ps, $j );
            }
        }
        return $self;
    }

=item set_next_sister()

Sets argument as invocant's next sister.

 Type    : Mutator
 Title   : set_next_sister
 Usage   : $node->set_next_sister($n_sister);
 Function: Assigns or retrieves a node's
           next sister (to the right).
 Returns : Modified object.
 Args    : A valid argument consists of a
           Bio::Phylo::Forest::Node object.
           If no argument is given, the
           value is set to undefined.

=cut

    sub set_next_sister {
        my ( $self, $ns ) = @_;
        if ( $ns and looks_like_object $ns, $TYPE_CONSTANT ) {
            if ( my $parent = $self->get_parent ) {
                my $children = $parent->get_children;
                my $last     = scalar @{$children};
                my $j        = $last;
              FINDSELF: for my $i ( 0 .. $#{$children} ) {
                    if ( $children->[$i] == $self ) {
                        $j = $i + 1;
                        last FINDSELF;
                    }
                }
                $parent->set_child( $ns, $j );
            }
        }
        return $self;
    }

=item set_node_below()

Sets new (unbranched) node below invocant.

 Type    : Mutator
 Title   : set_node_below
 Usage   : my $new_node = $node->set_node_below;
 Function: Creates a new node below $node
 Returns : New node if tree was modified, undef otherwise
 Args    : NONE

=cut 

    sub set_node_below {
        my $self = shift;

        # can't set node below root
        if ( $self->is_root ) {
            return;
        }

        # instantiate new node from $self's class
        my $new_node = ( ref $self )->new(@_);

        # attach new node to $child's parent
        my $parent = $self->get_parent;
        $parent->set_child($new_node);

        # insert new node in tree
        # 		if ( my $tree = $self->_get_container ) {
        # 			$tree->insert( $new_node );
        # 		}
        # attach $self to new node
        $new_node->set_child($self);

        # done
        return $new_node;
    }

=item set_root_below()

Reroots below invocant.

 Type    : Mutator
 Title   : set_root_below
 Usage   : $node->set_root_below;
 Function: Creates a new tree root below $node
 Returns : New root if tree was modified, undef otherwise
 Args    : NONE
 Comments: This implementation is a port of @lh3's kn_reroot algorithm
           found here: http://lh3lh3.users.sourceforge.net/knhx.js

=cut    

	sub set_root_below {
		my $node  = shift;
		my $dist  = shift || 0;
		my $force = shift || 0;
		my $tree  = $node->get_tree;		
		my $root  = $tree->get_root;
		
		# do nothing if the focal node already is the root, 
		# or already has the root below it
		return if $node->get_id == $root->get_id;
		return if $node->get_parent and $node->get_parent->get_id == $root->get_id and not $force;
	
		# p: the central multi-parent node
		# q: the new parent, previous a child of p
		# r: old parent
		# i: previous position of q in p
		# d: previous distance p->d	
		my ( $q, $s, $new_root );
		my $p = $node->get_parent;
		my $i = $p->get_index_of( $node );
		my $r = $p->get_parent;
		my $d = $p->get_branch_length;		
		my $tmp = $node->get_branch_length || 0;
		
		# adjust $dist to a useable value			
		$dist = $tmp / 2 if ($dist < 0.0 || $dist > $tmp);

		# instantiate new root, add $node as first child with new length
		$q = $new_root = $fac->create_node( '-name' => 'root' );	
		$q->set_raw_child( $node => 0 );
		$node->set_raw_parent( $q );
		$node->set_branch_length( $dist );
	
		# add $node's parent as child with new length
		$q->set_raw_child( $p => 1 );
		$p->set_raw_parent( $q );
		$p->set_branch_length( $tmp - $dist );
	
		# traverse along previous ancestors, swap them 
		# and update the branch lengths				
		while ( $r ) {
			$s = $r->get_parent; # store r's parent
			$p->set_raw_child( $r => $i ); # change r to p's child
			$i = $r->get_index_of( $p ); # update $i
			$r->set_raw_parent( $p ); # update r's parent
		
			# swap r->d and d, i.e. update r->d
			$tmp = $r->get_branch_length;
			$r->set_branch_length( $d );
			$d = $tmp;
		
			# update p, q and r
			$q = $p; $p = $r; $r = $s;
		}
		
		# now $p is the root node
		my @children = @{ $p->get_children };
		if ( scalar(@children) == 2 ) { # remove p and link the other child of p to q
			$r = $children[1 - $i]; # get the other child
			$i = $q->get_index_of( $p ); # the position of p in q
			my $bl = ( $r->get_branch_length || 0 ) + ( $p->get_branch_length || 0 );
			$r->set_branch_length( $bl );
			
			# link r to q
			$q->set_raw_child( $r => $i );
			$r->set_raw_parent( $q );
		} 
		
		# remove one child in p
		else {
			my $k = 0;
			for my $j ( 0 .. $#children ) {
				$children[$k] = $children[$j];
				$k++ if $j != $i;
			}
			pop @children;
			$p->clear();
			$p->insert( @children ) if @children;
		}
		$tree->insert($new_root);
		return $new_root;
	}


=back

=head2 ACCESSORS

=over

=item get_first_daughter()

Gets invocant's first daughter.

 Type    : Accessor
 Title   : get_first_daughter
 Usage   : my $f_daughter = $node->get_first_daughter;
 Function: Retrieves a node's leftmost daughter.
 Returns : Bio::Phylo::Forest::Node
 Args    : NONE

=cut

    sub get_first_daughter {
        return $_[0]->get_child(0);
    }

=item get_last_daughter()

Gets invocant's last daughter.

 Type    : Accessor
 Title   : get_last_daughter
 Usage   : my $l_daughter = $node->get_last_daughter;
 Function: Retrieves a node's rightmost daughter.
 Returns : Bio::Phylo::Forest::Node
 Args    : NONE

=cut

    sub get_last_daughter {
        return $_[0]->get_child(-1);
    }

=item get_previous_sister()

Gets invocant's previous sister.

 Type    : Accessor
 Title   : get_previous_sister
 Usage   : my $p_sister = $node->get_previous_sister;
 Function: Retrieves a node's previous sister (to the left).
 Returns : Bio::Phylo::Forest::Node
 Args    : NONE

=cut

    sub get_previous_sister {
        my $self = shift;
        my $id = $self->get_id;
        if ( my $parent = $self->get_parent ) {
            my $children = $parent->get_children;
            for ( my $i = $#{$children} ; $i >= 1 ; $i-- ) {
                if ( $children->[$i]->get_id == $id ) {
                    return $children->[ $i - 1 ];
                }
            }
        }
        return;
    }

=item get_next_sister()

Gets invocant's next sister.

 Type    : Accessor
 Title   : get_next_sister
 Usage   : my $n_sister = $node->get_next_sister;
 Function: Retrieves a node's next sister (to the right).
 Returns : Bio::Phylo::Forest::Node
 Args    : NONE

=cut

    sub get_next_sister {
        my $self = shift;
        my $id = $self->get_id;
        if ( my $parent = $self->get_parent ) {
            my $children = $parent->get_children;
            for my $i ( 0 .. $#{$children} ) {
                if ( $children->[$i]->get_id == $id ) {
                    return $children->[ $i + 1 ];
                }
            }
        }
        return;
    }

=item get_ancestors()

Gets invocant's ancestors.

 Type    : Query
 Title   : get_ancestors
 Usage   : my @ancestors = @{ $node->get_ancestors };
 Function: Returns an array reference of ancestral nodes,
           ordered from young to old (i.e. $ancestors[-1] is root).
 Returns : Array reference of Bio::Phylo::Forest::Node
           objects.
 Args    : NONE

=cut

    sub get_ancestors {
        my $self = shift;
        my @ancestors;
        my $node = $self;
        if ( $node = $node->get_parent ) {
            while ($node) {
                push @ancestors, $node;
                $node = $node->get_parent;
            }
            return \@ancestors;
        }
        else {
            return;
        }
    }

=item get_root()

Gets root relative to the invocant, i.e. by walking up the path of ancestors

 Type    : Query
 Title   : get_root
 Usage   : my $root = $node->get_root;
 Function: Gets root relative to the invocant
 Returns : Bio::Phylo::Forest::Node           
 Args    : NONE

=cut

    sub get_root {
        my $self = shift;
        if ( my $anc = $self->get_ancestors ) {
            return $anc->[-1];
        }
        else {
            return $self;
        }
    }

=item get_farthest_node()

Gets node farthest away from the invocant. By default this is nodal distance,
but when supplied an optional true argument it is based on patristic distance
instead.

 Type    : Query
 Title   : get_farthest_node
 Usage   : my $farthest = $node->get_farthest_node;
 Function: Gets node farthest away from the invocant.
 Returns : Bio::Phylo::Forest::Node           
 Args    : Optional, TRUE value to use patristic instead of nodal distance

=cut

    sub get_farthest_node {
        my ( $self, $patristic ) = @_;
        my $criterion = $patristic ? 'patristic' : 'nodal';
        my $method = sprintf 'calc_%s_distance', $criterion;
        my $root = $self->get_root;
        if ( my $terminals = $root->get_terminals ) {
            my ( $furthest_distance, $furthest_node ) = (0);
            for my $tip ( @{$terminals} ) {
                my $distance = $self->$method($tip);
                if ( $distance > $furthest_distance ) {
                    $furthest_distance = $distance;
                    $furthest_node     = $tip;
                }
            }
            return $furthest_node;
        }
        else {
        	$logger->error("no terminals!");
        }
    }

=item get_sisters()

Gets invocant's sisters.

 Type    : Query
 Title   : get_sisters
 Usage   : my @sisters = @{ $node->get_sisters };
 Function: Returns an array reference of sisters,
           ordered from left to right.
 Returns : Array reference of
           Bio::Phylo::Forest::Node objects.
 Args    : NONE

=cut

    sub get_sisters {
        my $self = shift;
        my $sisters;
        if ( my $parent = $self->get_parent ) {
            $sisters = $parent->get_children;
        }
        return $sisters;
    }

=item get_child()

Gets invocant's i'th child.

 Type    : Query
 Title   : get_child
 Usage   : my $child = $node->get_child($i);
 Function: Returns the child at index $i
 Returns : A Bio::Phylo::Forest::Node object.
 Args    : An index (integer) $i
 Comments: if no index is specified, first
           child is returned

=cut

    sub get_child {
        my ( $self, $i ) = @_;
        $i = 0 if not defined $i;
        my $children = $self->get_children;
        return $children->[$i];
    }

=item get_descendants()

Gets invocant's descendants.

 Type    : Query
 Title   : get_descendants
 Usage   : my @descendants = @{ $node->get_descendants };
 Function: Returns an array reference of
           descendants, recursively ordered
           breadth first.
 Returns : Array reference of
           Bio::Phylo::Forest::Node objects.
 Args    : none.

=cut

    sub get_descendants {
        my $self    = shift;
        my @current = ($self);
        my @desc;
        while ( $self->_desc(@current) ) {
            @current = $self->_desc(@current);
            push @desc, @current;
        }
        return \@desc;
    }

=begin comment

 Type    : Internal method
 Title   : _desc
 Usage   : $node->_desc(\@nodes);
 Function: Performs recursion for Bio::Phylo::Forest::Node::get_descendants()
 Returns : A Bio::Phylo::Forest::Node object.
 Args    : A Bio::Phylo::Forest::Node object.
 Comments: This method works in conjunction with
           Bio::Phylo::Forest::Node::get_descendants() - the latter simply calls
           the former with a set of nodes, and the former returns their
           children. Bio::Phylo::Forest::Node::get_descendants() then calls
           Bio::Phylo::Forest::Node::_desc with this set of children, and so on
           until all nodes are terminals. A first_daughter ->
           next_sister postorder traversal in a single method would
           have been more elegant - though not more efficient, in
           terms of visited nodes.

=end comment

=cut

    sub _desc {
        my $self    = shift;
        my @current = @_;
        my @return;
        foreach (@current) {
            my $children = $_->get_children;
            if ($children) {
                push @return, @{$children};
            }
        }
        return @return;
    }

=item get_terminals()

Gets invocant's terminal descendants.

 Type    : Query
 Title   : get_terminals
 Usage   : my @terminals = @{ $node->get_terminals };
 Function: Returns an array reference
           of terminal descendants.
 Returns : Array reference of
           Bio::Phylo::Forest::Node objects.
 Args    : NONE

=cut

    sub get_terminals {
        my $self = shift;
        if ( $self->is_terminal ) {
        	return [$self];
        }
        else {
        	return [ grep { $_->is_terminal } @{ $self->get_descendants } ];
        }
    }

=item get_internals()

Gets invocant's internal descendants.

 Type    : Query
 Title   : get_internals
 Usage   : my @internals = @{ $node->get_internals };
 Function: Returns an array reference
           of internal descendants.
 Returns : Array reference of
           Bio::Phylo::Forest::Node objects.
 Args    : NONE

=cut

    sub get_internals {
        my $self = shift;
        my @internals;
        my $desc = $self->get_descendants;
        if ( @{$desc} ) {
            foreach ( @{$desc} ) {
                if ( $_->is_internal ) {
                    push @internals, $_;
                }
            }
        }
        return \@internals;
    }

=item get_mrca()

Gets invocant's most recent common ancestor shared with argument.

 Type    : Query
 Title   : get_mrca
 Usage   : my $mrca = $node->get_mrca($other_node);
 Function: Returns the most recent common ancestor
           of $node and $other_node.
 Returns : Bio::Phylo::Forest::Node
 Args    : A Bio::Phylo::Forest::Node
           object in the same tree.

=cut

    sub get_mrca {
        my ( $self, $other_node ) = @_;
        if ( $self->get_id == $other_node->get_id ) {
            return $self;
        }
        my $self_anc  = $self->get_ancestors       || [$self];
        my $other_anc = $other_node->get_ancestors || [$other_node];
        for my $i ( 0 .. $#{$self_anc} ) {
            my $self_anc_id = $self_anc->[$i]->get_id;
            for my $j ( 0 .. $#{$other_anc} ) {
                if ( $self_anc_id == $other_anc->[$j]->get_id ) {
                    return $self_anc->[$i];
                }
            }
        }
        return $self_anc->[-1];
    }

=item get_leftmost_terminal()

Gets invocant's leftmost terminal descendant.

 Type    : Query
 Title   : get_leftmost_terminal
 Usage   : my $leftmost_terminal =
           $node->get_leftmost_terminal;
 Function: Returns the leftmost
           terminal descendant of $node.
 Returns : Bio::Phylo::Forest::Node
 Args    : NONE

=cut

    sub get_leftmost_terminal {
        my $self     = shift;
        my $daughter = $self;
      FIRST_DAUGHTER: while ($daughter) {
            if ( my $grand_daughter = $daughter->get_first_daughter ) {
                $daughter = $grand_daughter;
                next FIRST_DAUGHTER;
            }
            else {
                last FIRST_DAUGHTER;
            }
        }
        return $daughter;
    }

=item get_rightmost_terminal()

Gets invocant's rightmost terminal descendant

 Type    : Query
 Title   : get_rightmost_terminal
 Usage   : my $rightmost_terminal =
           $node->get_rightmost_terminal;
 Function: Returns the rightmost
           terminal descendant of $node.
 Returns : Bio::Phylo::Forest::Node
 Args    : NONE

=cut

    sub get_rightmost_terminal {
        my $self     = shift;
        my $daughter = $self;
      LAST_DAUGHTER: while ($daughter) {
            if ( my $grand_daughter = $daughter->get_last_daughter ) {
                $daughter = $grand_daughter;
                next LAST_DAUGHTER;
            }
            else {
                last LAST_DAUGHTER;
            }
        }
        return $daughter;
    }

=item get_subtree()

Returns the tree subtended by the invocant

 Type    : Query
 Title   : get_subtree
 Usage   : my $tree = $node->get_subtree;
 Function: Returns the tree subtended by the invocant
 Returns : Bio::Phylo::Forest::Tree
 Args    : NONE

=cut

    sub get_subtree {
        my $self = shift;
        my $tree = $fac->create_tree;
        $self->visit_depth_first(
            '-pre' => sub {
                my $node  = shift;
                my $clone = $node->clone;
                $node->set_generic( 'clone' => $clone );
                $tree->insert($clone);
                if ( my $parent = $node->get_parent ) {
                    if ( my $pclone = $parent->get_generic('clone') ) {
                        $clone->set_parent($pclone);
                    }
                    else {
                        $clone->set_parent;
                    }
                }
            },
            '-post' => sub {
                my $node = shift;
                my $gen  = $node->get_generic;
                delete $gen->{'clone'};
            }
        );
        return $tree->_analyze;
    }

=item get_subtrees()

Returns the subtree rooted at the common ancestor of u and v, and the respective
subtrees that contain u and v

 Type    : Query
 Title   : get_subtrees
 Usage   : my ( $found_u, $found_v, $subtree, $subtree_u, $subtree_v ) = $root->get_subtrees($u,$v);
 Function: Returns the tree subtended by the invocant
 Returns : A list containing the following variables:
           - boolean: did we find u
           - boolean: did we find v
           - Bio::Phylo::Forest::Node - the root node of the connecting subtree
           - Bio::Phylo::Forest::Node - the root node of the subtree for $u
           - Bio::Phylo::Forest::Node - the root node of the subtree for $v           
 Args    : Two nodes, $u and $v
 Comments: This is a recursive method that is used by the RANKPROB calculations (see 
           below). Typically you would invoke this method on the root node of the tree 
           containing $u and $v, and the method then recurses up the tree. The tree must 
           be bifurcating, or an exception is thrown.

=cut

    sub get_subtrees {
		my ($node,$u,$v) = @_;
	
		# node is terminal
		my @child = @{ $node->get_children };
		if ( not @child ) {
			return undef, undef, undef, undef, undef;
		}
		elsif ( @child != 2 ) {
			throw 'BadArgs' => "Tree must be bifurcating";
		}
	
		# recurse left and right
		my ( $found_ul, $found_vl, $subtree_l, $subtree_ul, $subtree_vl ) = $child[0]->get_subtrees( $u, $v );
		my ( $found_ur, $found_vr, $subtree_r, $subtree_ur, $subtree_vr ) = $child[1]->get_subtrees( $u, $v );
	
		# both were left descendants of focal node, return result
		if ( $found_ul and $found_vl ) {
			return $found_ul, $found_vl, $subtree_l, $subtree_ul, $subtree_vl;
		}
	
		# both were right descendants of focal node, return result
		if ( $found_ur and $found_vr ) {
			return $found_ur, $found_vr, $subtree_r, $subtree_ur, $subtree_vr;
		}
	
		# have we found either?
		my $found_u = ( $found_ul or $found_ur or $node->is_equal($u) );
		my $found_v = ( $found_vl or $found_vr or $node->is_equal($v) );
	
		# initialize and assign subtrees
		my ( $subtree_u, $subtree_v );		
		$subtree_u = $subtree_ul if $found_ul;
		$subtree_v = $subtree_vl if $found_vl;
		$subtree_u = $subtree_ur if $found_ur;
		$subtree_v = $subtree_vr if $found_vr;
		if ( $found_u and (not $found_v) ) {
			$subtree_u = $node;
		}
		elsif ( $found_v and (not $found_u) ) {
			$subtree_v = $node;
		}
		$subtree_u = $node if $node->is_equal($u);
		$subtree_v = $node if $node->is_equal($v);
	
		# return results
		return $found_u, $found_v, $node, $subtree_u, $subtree_v;
	}

=back

=head2 TESTS

=over

=item is_terminal()

Tests if invocant is a terminal node.

 Type    : Test
 Title   : is_terminal
 Usage   : if ( $node->is_terminal ) {
              # do something
           }
 Function: Returns true if node has
           no children (i.e. is terminal).
 Returns : BOOLEAN
 Args    : NONE

=cut

    sub is_terminal {
        return !shift->get_first_daughter;
    }

=item is_internal()

Tests if invocant is an internal node.

 Type    : Test
 Title   : is_internal
 Usage   : if ( $node->is_internal ) {
              # do something
           }
 Function: Returns true if node
           has children (i.e. is internal).
 Returns : BOOLEAN
 Args    : NONE

=cut

    sub is_internal {
        return !!shift->get_first_daughter;
    }

=item is_preterminal()

Tests if all direct descendents are terminal

 Type    : Test
 Title   : is_preterminal
 Usage   : if ( $node->is_preterminal ) {
              # do something
           }
 Function: Returns true if all direct descendents are terminal
 Returns : BOOLEAN
 Args    : NONE

=cut

    sub is_preterminal {
        my $self     = shift;
        my $children = $self->get_children;
        for my $child ( @{$children} ) {
            return 0 if $child->is_internal;
        }
        return !!scalar @{$children};
    }

=item is_first()

Tests if invocant is first sibling in left-to-right order.

 Type    : Test
 Title   : is_first
 Usage   : if ( $node->is_first ) {
              # do something
           }
 Function: Returns true if first sibling 
           in left-to-right order.
 Returns : BOOLEAN
 Args    : NONE

=cut

    sub is_first {
        return !shift->get_previous_sister;
    }

=item is_last()

Tests if invocant is last sibling in left-to-right order.

 Type    : Test
 Title   : is_last
 Usage   : if ( $node->is_last ) {
              # do something
           }
 Function: Returns true if last sibling 
           in left-to-right order.
 Returns : BOOLEAN
 Args    : NONE

=cut

    sub is_last {
        return !shift->get_next_sister;
    }

=item is_root()

Tests if invocant is a root.

 Type    : Test
 Title   : is_root
 Usage   : if ( $node->is_root ) {
              # do something
           }
 Function: Returns true if node is a root       
 Returns : BOOLEAN
 Args    : NONE

=cut

    sub is_root {
        return !shift->get_parent;
    }

=item is_descendant_of()

Tests if invocant is descendant of argument.

 Type    : Test
 Title   : is_descendant_of
 Usage   : if ( $node->is_descendant_of($grandparent) ) {
              # do something
           }
 Function: Returns true if the node is
           a descendant of the argument.
 Returns : BOOLEAN
 Args    : putative ancestor - a
           Bio::Phylo::Forest::Node object.

=cut

    sub is_descendant_of {
        my ( $self, $ancestor ) = @_;
        my $ancestor_id = $ancestor->get_id;
        while ($self) {
            if ( my $parent = $self->get_parent ) {
                $self = $parent;
            }
            else {
                return;
            }
            if ( $self->get_id == $ancestor_id ) {
                return 1;
            }
        }
    }

=item is_ancestor_of()

Tests if invocant is ancestor of argument.

 Type    : Test
 Title   : is_ancestor_of
 Usage   : if ( $node->is_ancestor_of($grandchild) ) {
              # do something
           }
 Function: Returns true if the node
           is an ancestor of the argument.
 Returns : BOOLEAN
 Args    : putative descendant - a
           Bio::Phylo::Forest::Node object.

=cut

    sub is_ancestor_of {
        my ( $self, $child ) = @_;
        if ( $child->is_descendant_of($self) ) {
            return 1;
        }
        else {
            return;
        }
    }

=item is_sister_of()

Tests if invocant is sister of argument.

 Type    : Test
 Title   : is_sister_of
 Usage   : if ( $node->is_sister_of($sister) ) {
              # do something
           }
 Function: Returns true if the node is
           a sister of the argument.
 Returns : BOOLEAN
 Args    : putative sister - a
           Bio::Phylo::Forest::Node object.

=cut

    sub is_sister_of {
        my ( $self, $sister ) = @_;
        my ( $self_parent, $sister_parent ) =
          ( $self->get_parent, $sister->get_parent );
        if (   $self_parent
            && $sister_parent
            && $self_parent->get_id == $sister_parent->get_id )
        {
            return 1;
        }
        else {
            return;
        }
    }

=item is_child_of()

Tests if invocant is child of argument.

 Type    : Test
 Title   : is_child_of
 Usage   : if ( $node->is_child_of($parent) ) {
              # do something
           }
 Function: Returns true if the node is
           a child of the argument.
 Returns : BOOLEAN
 Args    : putative parent - a
           Bio::Phylo::Forest::Node object.

=cut

    sub is_child_of {
        my ( $self, $node ) = @_;
        if ( my $parent = $self->get_parent ) {
            return $parent->get_id == $node->get_id;
        }
        return 0;
    }

=item is_outgroup_of()

Test if invocant is outgroup of argument nodes.

 Type    : Test
 Title   : is_outgroup_of
 Usage   : if ( $node->is_outgroup_of(\@ingroup) ) {
              # do something
           }
 Function: Tests whether the set of
           \@ingroup is monophyletic
           with respect to the $node.
 Returns : BOOLEAN
 Args    : A reference to an array of
           Bio::Phylo::Forest::Node objects;
 Comments: This method is essentially the same as
           &Bio::Phylo::Forest::Tree::is_monophyletic.

=cut

    sub is_outgroup_of {
        my ( $outgroup, $nodes ) = @_;
        for my $i ( 0 .. $#{$nodes} ) {
            for my $j ( ( $i + 1 ) .. $#{$nodes} ) {
                my $mrca = $nodes->[$i]->get_mrca( $nodes->[$j] );
                return if $mrca->is_ancestor_of($outgroup);
            }
        }
        return 1;
    }

=item can_contain()

Test if argument(s) can be a child/children of invocant.

 Type    : Test
 Title   : can_contain
 Usage   : if ( $parent->can_contain(@children) ) {
              # do something
           }
 Function: Test if arguments can be children of invocant.
 Returns : BOOLEAN
 Args    : An array of Bio::Phylo::Forest::Node objects;
 Comments: This method is an override of 
           Bio::Phylo::Listable::can_contain. Since node
           objects hold a list of their children, they
           inherit from the listable class and so they
           need to be able to validate the contents
           of that list before they are inserted.

=cut

    sub can_contain {
        my $self = shift;
        my $type = $self->_type;
        for (@_) {
            return 0 if $type != $_->_type;
        }
        return 1;
    }

=back

=head2 CALCULATIONS

=over

=item calc_path_to_root()

Calculates path to root.

 Type    : Calculation
 Title   : calc_path_to_root
 Usage   : my $path_to_root =
           $node->calc_path_to_root;
 Function: Returns the sum of branch
           lengths from $node to the root.
 Returns : FLOAT
 Args    : NONE

=cut

    sub calc_path_to_root {
        my $self = shift;
        my $node = $self;
        my $path = 0;
        while ($node) {
            my $branch_length = $node->get_branch_length;
            if ( defined $branch_length ) {
                $path += $branch_length;
            }
            if ( my $parent = $node->get_parent ) {
                $node = $parent;
            }
            else {
                last;
            }
        }
        return $path;
    }

=item calc_nodes_to_root()

Calculates number of nodes to root.

 Type    : Calculation
 Title   : calc_nodes_to_root
 Usage   : my $nodes_to_root =
           $node->calc_nodes_to_root;
 Function: Returns the number of nodes
           from $node to the root.
 Returns : INT
 Args    : NONE

=cut

    sub calc_nodes_to_root {
        my $self = shift;
        my ( $nodes, $parent ) = ( 0, $self );
        while ($parent) {
            $nodes++;
            $parent = $parent->get_parent;
            if ($parent) {
                if ( my $cntr = $parent->calc_nodes_to_root ) {
                    $nodes += $cntr;
                    last;
                }
            }
        }
        return $nodes;
    }

=item calc_max_nodes_to_tips()

Calculates maximum number of nodes to tips.

 Type    : Calculation
 Title   : calc_max_nodes_to_tips
 Usage   : my $max_nodes_to_tips =
           $node->calc_max_nodes_to_tips;
 Function: Returns the maximum number
           of nodes from $node to tips.
 Returns : INT
 Args    : NONE

=cut

    sub calc_max_nodes_to_tips {
        my $self    = shift;
        my $self_id = $self->get_id;
        my ( $nodes, $maxnodes ) = ( 0, 0 );
        foreach my $child ( @{ $self->get_terminals } ) {
            $nodes = 0;
            while ( $child && $child->get_id != $self_id ) {
                $nodes++;
                $child = $child->get_parent;
            }
            if ( $nodes > $maxnodes ) {
                $maxnodes = $nodes;
            }
        }
        return $maxnodes;
    }

=item calc_min_nodes_to_tips()

Calculates minimum number of nodes to tips.

 Type    : Calculation
 Title   : calc_min_nodes_to_tips
 Usage   : my $min_nodes_to_tips =
           $node->calc_min_nodes_to_tips;
 Function: Returns the minimum number of
           nodes from $node to tips.
 Returns : INT
 Args    : NONE

=cut

    sub calc_min_nodes_to_tips {
        my $self    = shift;
        my $self_id = $self->get_id;
        my ( $nodes, $minnodes );
        foreach my $child ( @{ $self->get_terminals } ) {
            $nodes = 0;
            while ( $child && $child->get_id != $self_id ) {
                $nodes++;
                $child = $child->get_parent;
            }
            if ( !$minnodes || $nodes < $minnodes ) {
                $minnodes = $nodes;
            }
        }
        return $minnodes;
    }

=item calc_max_path_to_tips()

Calculates longest path to tips.

 Type    : Calculation
 Title   : calc_max_path_to_tips
 Usage   : my $max_path_to_tips =
           $node->calc_max_path_to_tips;
 Function: Returns the path length from
           $node to the tallest tip.
 Returns : FLOAT
 Args    : NONE

=cut

    sub calc_max_path_to_tips {
        my $self = shift;
        my $id   = $self->get_id;
        my ( $length, $maxlength ) = ( 0, 0 );
        foreach my $child ( @{ $self->get_terminals } ) {
            $length = 0;
            while ( $child && $child->get_id != $id ) {
                my $branch_length = $child->get_branch_length;
                if ( defined $branch_length ) {
                    $length += $branch_length;
                }
                $child = $child->get_parent;
            }
            if ( $length > $maxlength ) {
                $maxlength = $length;
            }
        }
        return $maxlength;
    }

=item calc_min_path_to_tips()

Calculates shortest path to tips.

 Type    : Calculation
 Title   : calc_min_path_to_tips
 Usage   : my $min_path_to_tips =
           $node->calc_min_path_to_tips;
 Function: Returns the path length from
           $node to the shortest tip.
 Returns : FLOAT
 Args    : NONE

=cut

    sub calc_min_path_to_tips {
        my $self = shift;
        my $id   = $self->get_id;
        my ( $length, $minlength );
        foreach my $child ( @{ $self->get_terminals } ) {
            $length = 0;
            while ( $child && $child->get_id != $id ) {
                my $branch_length = $child->get_branch_length;
                if ( defined $branch_length ) {
                    $length += $branch_length;
                }
                $child = $child->get_parent;
            }
            if ( !$minlength ) {
                $minlength = $length;
            }
            if ( $length < $minlength ) {
                $minlength = $length;
            }
        }
        return $minlength;
    }

=item calc_patristic_distance()

Calculates patristic distance between invocant and argument.

 Type    : Calculation
 Title   : calc_patristic_distance
 Usage   : my $patristic_distance =
           $node->calc_patristic_distance($other_node);
 Function: Returns the patristic distance
           between $node and $other_node.
 Returns : FLOAT
 Args    : Bio::Phylo::Forest::Node

=cut

    sub calc_patristic_distance {
        my ( $self, $other_node ) = @_;
        my $patristic_distance = 0;
        my $mrca    = $self->get_mrca($other_node);
        my $mrca_id = $mrca->get_id;
        while ( $self->get_id != $mrca_id ) {
            my $branch_length = $self->get_branch_length;
            if ( defined $branch_length ) {
                $patristic_distance += $branch_length;
            }
            $self = $self->get_parent;
        }
        while ( $other_node and $other_node->get_id != $mrca_id ) {
            my $branch_length = $other_node->get_branch_length;
            if ( defined $branch_length ) {
                $patristic_distance += $branch_length;
            }
            $other_node = $other_node->get_parent;
        }
        return $patristic_distance;
    }

=item calc_nodal_distance()

Calculates node distance between invocant and argument.

 Type    : Calculation
 Title   : calc_nodal_distance
 Usage   : my $nodal_distance =
           $node->calc_nodal_distance($other_node);
 Function: Returns the number of nodes
           between $node and $other_node.
 Returns : INT
 Args    : Bio::Phylo::Forest::Node

=cut	

    sub calc_nodal_distance {
        my ( $self, $other_node ) = @_;
        my $nodal_distance = 0;
        my $mrca    = $self->get_mrca($other_node);
        my $mrca_id = $mrca->get_id;
        while ( $self and $self->get_id != $mrca_id ) {
            $nodal_distance++;
            $self = $self->get_parent;
        }
        while ( $other_node and $other_node->get_id != $mrca_id ) {
            $nodal_distance++;
            $other_node = $other_node->get_parent;
        }
        return $nodal_distance;
    }

=item calc_terminals()

Calculates number of terminals subtended by the invocant

 Type    : Calculation
 Title   : calc_terminals
 Usage   : my $ntips = $node->calc_terminals;
 Function: Returns the number of terminals subtended by the invocant
 Returns : INT
 Args    : None

=cut
    
    sub calc_terminals {
    	my $self = shift;
    	my $tips = 0;
    	$self->visit_level_order( sub { $tips++ if shift->is_terminal } );
    	return $tips;
    }

=item calc_rankprob_tipcounts()

Recurses from the root to the tips, returns an array reference at every step whose
first element is a boolean set to true once the query node has been seen. The second
element is an array that contains the number of subtended leaves - 1 for the query
node and for all sisters of the nodes on the path from the query to the root. This 
method is used by the RANKPROB calculations (see below)

 Type    : Calculation
 Title   : calc_rankprob_tipcounts
 Usage   : my @rp = @{ $root->calc_rankprob_tipcounts($node) };
 Function: Returns tip counts for RANKPROB
 Returns : ARRAY
 Args    : NONE

=cut 

sub calc_rankprob_tipcounts {
	my ($node,$u) = @_;
	
	# focal node (subtree) is empty, i.e. a leaf 
	my @child = @{ $node->get_children };
	return [undef,undef] if not @child;
	return [ 1, [ $node->calc_terminals - 1 ] ] if $node->is_equal($u);
	
	# recurse left
	my $x = $child[0]->calc_rankprob_tipcounts( $u );
	if ( $x->[0] ) {
		my $n;
		
		# focal node has no sibling
		if ( not $child[1] ) {
			$n = 0;
		}
		else {
			$n = $child[1]->calc_terminals - 1;
		}
		return [ 1, [ @{ $x->[1] }, $n ] ];
	}

	# recurse right
	my $y = $child[1]->calc_rankprob_tipcounts( $u );
	if ( $y->[0] ) {
		my $n;
		
		# focal node has no sibling
		if ( not $child[0] ) {
			$n = 0;
		}
		else {
			$n = $child[0]->calc_terminals - 1;
		}
		return [ 1, [ @{ $y->[1] }, $n ] ];
	}
	
	# $u is neither left or right from here
	else {
		return [undef,undef];
	}
}

=item calc_rankprob()

Calculates the probabilities for all rank orderings that the invocant node can
occupy among all possible labeled histories. Uses Stadler's RANKPROB algorithm as 
described in: 

B<Gernhard, T.> et al., 2006. Estimating the relative order of speciation 
or coalescence events on a given phylogeny. I<Evolutionary Bioinformatics Online>. 
B<2>:285. L<http://www.ncbi.nlm.nih.gov/pmc/articles/PMC2674681/>.

 Type    : Calculation
 Title   : calc_rankprob
 Usage   : my @rp = @{ $root->calc_rankprob($node) };
 Function: Returns the rank probabilities of the invocant node
 Returns : ARRAY, indices are ranks, values are probabilities
 Args    : NONE

=cut  

sub calc_rankprob {
	my ($t,$u) = @_;
	my $x = $t->calc_rankprob_tipcounts($u);
	$x = $x->[1];
	my $lhsm = $x->[0];
	my $k = scalar(@$x);
	my $start = 1;
	my $end = 1;
	my $rp = [0,1];
	my $step = 1;
	while ( $step < $k ) {
		my $rhsm = $x->[$step];
		my $newstart = $start+1;
		my $newend = $end + $rhsm + 1;
		my $rp2 = [];
		for my $i ( 0 .. $newend ) {
			push @$rp2, 0;
		}
		for my $i ( $newstart .. $newend ) {
			my $q = max( 0, $i - 1 - $end );
			for my $j ( $q .. min( $rhsm, $i - 2 ) ) {
				my $a = $rp->[$i-$j-1] * nchoose($lhsm + $rhsm - ($i-1),$rhsm-$j) * nchoose($i-2,$j);
				$rp2->[$i]+=$a;
			}
		}
		$rp = $rp2;
		$start = $newstart;
		$end = $newend;
		$lhsm = $lhsm+$rhsm+1;
		$step += 1;
	}
	my $tot = sum( @{ $rp } );
	for my $i ( 0..$#{ $rp } ) {
		$rp->[$i] = $rp->[$i] / $tot;
	}
	return $rp;
}

=item calc_expected_rank()

Calculates the expected rank and variance that the invocant node occupies among all 
possible labeled histories. Uses Stadler's RANKPROB algorithm as described in: 

B<Gernhard, T.> et al., 2006. Estimating the relative order of speciation 
or coalescence events on a given phylogeny. I<Evolutionary Bioinformatics Online>. 
B<2>:285. L<http://www.ncbi.nlm.nih.gov/pmc/articles/PMC2674681/>.

 Type    : Calculation
 Title   : calc_expected_rank
 Usage   : my ( $rank, $variance ) = $root->calc_expected_rank($node);
 Function: Calculates expected rank and variance
 Returns : Two numbers: rank and variance
 Args    : NONE

=cut

sub calc_expected_rank {
	my ( $t, $u ) = @_;
	my $rp = $t->calc_rankprob( $u );
	my $mu = 0;
	my $sigma = 0;
	for my $i ( 0 .. $#{ $rp } ) {
		$mu += $i * $rp->[$i];
		$sigma += $i * $i * $rp->[$i];
	}
	return $mu, $sigma - $mu * $mu;
}

=item calc_rankprob_compare()

Calculates the probability that the argument node is below the invocant node over all 
possible labeled histories. Uses Stadler's COMPARE algorithm as described in: 

B<Gernhard, T.> et al., 2006. Estimating the relative order of speciation 
or coalescence events on a given phylogeny. I<Evolutionary Bioinformatics Online>. 
B<2>:285. L<http://www.ncbi.nlm.nih.gov/pmc/articles/PMC2674681/>.

 Type    : Calculation
 Title   : calc_rankprob_compare
 Usage   : my $prob = $root->calc_rankprob_compare($u,$v);
 Function: Compares rankings of nodes
 Returns : A number (probability)
 Args    : Bio::Phylo::Forest::Node

=cut

sub calc_rankprob_compare {
	my ($t,$u,$v) = @_;
	my ($found_u,$found_v,$root,$root_u,$root_v) = $t->get_subtrees($u,$v);
	
	# both vertices need to occur in the same tree, of course
	if ( not ($found_u and $found_v) ) {
		print "This tree does not have those vertices!";
		return 0;
	}
	
	# If either one is the root node of the
	# subtree that connects them then their
	# relative rankings are certain.
	return 1.0 if $root->is_equal($u);
	return 0.0 if $root->is_equal($v);

	# calculate rank probabilities in
	# respective subtrees
	my $x = $root_u->calc_rankprob($u);
	my $y = $root_v->calc_rankprob($v);
	my $usize = $root_u->calc_terminals - 1;
	my $vsize = $root_v->calc_terminals - 1;	
	
	for my $i ( scalar(@$x) .. $usize + 1 ) {
		push @$x, 0;
	}
	my $xcumulative = [0];
	for my $i ( 1 .. $#{ $x } ) {
		push @$xcumulative, $xcumulative->[$i-1] + $x->[$i];
	}
	my $rp = [0];
	for my $i ( 1 .. $#{ $y } ) {
		push @$rp, 0;
		for my $j ( 1 .. $usize) {
			my $a = $y->[$i] * nchoose($i-1+$j,$j) * nchoose($vsize-$i+$usize-$j, $usize-$j) * $xcumulative->[$j];
			$rp->[$i] += $a;
		}
	}
	my $tot = nchoose($usize+$vsize,$vsize);
	return sum(@$rp)/$tot;	
}

=back

=head2 VISITOR METHODS

The methods below are similar in spirit to those by the same name in L<Bio::Phylo::Forest::Tree>,
except those in the tree class operate from the tree root, and those in this node class operate
on an invocant node, and so these process a subtree.

=over

=item visit_depth_first()

Visits nodes depth first

 Type    : Visitor method
 Title   : visit_depth_first
 Usage   : $tree->visit_depth_first( -pre => sub{ ... }, -post => sub { ... } );
 Function: Visits nodes in a depth first traversal, executes subs
 Returns : $tree
 Args    : Optional:
            # first event handler, is executed when node is reached in recursion
            -pre            => sub { print "pre: ",            shift->get_name, "\n" },
                        
            # is executed if node has a daughter, but before that daughter is processed
            -pre_daughter   => sub { print "pre_daughter: ",   shift->get_name, "\n" },
            
            # is executed if node has a daughter, after daughter has been processed 
            -post_daughter  => sub { print "post_daughter: ",  shift->get_name, "\n" },
            
            # is executed if node has no daughter
            -no_daughter    => sub { print "no_daughter: ",    shift->get_name, "\n" },                         

            # is executed whether or not node has sisters, if it does have sisters
            # they're processed first   
            -in             => sub { print "in: ",             shift->get_name, "\n" },

            # is executed if node has a sister, before sister is processed
            -pre_sister     => sub { print "pre_sister: ",     shift->get_name, "\n" }, 
            
            # is executed if node has a sister, after sister is processed
            -post_sister    => sub { print "post_sister: ",    shift->get_name, "\n" },         
            
            # is executed if node has no sister
            -no_sister      => sub { print "no_sister: ",      shift->get_name, "\n" }, 
            
            # is executed last          
            -post           => sub { print "post: ",           shift->get_name, "\n" },
            
            # specifies traversal order, default 'ltr' means first_daugher -> next_sister
            # traversal, alternate value 'rtl' means last_daughter -> previous_sister traversal
            -order          => 'ltr', # ltr = left-to-right, 'rtl' = right-to-left
            
            # passes sister node as second argument to pre_sister and post_sister subs,
            # and daughter node as second argument to pre_daughter and post_daughter subs
            -with_relatives => 1 # or any other true value
 Comments: 

=cut

 #$tree->visit_depth_first(
 #	'-pre'            => sub { print "pre: ",            shift->get_name, "\n" },
 #	'-pre_daughter'   => sub { print "pre_daughter: ",   shift->get_name, "\n" },
 #	'-post_daughter'  => sub { print "post_daughter: ",  shift->get_name, "\n" },
 #	'-in'             => sub { print "in: ",             shift->get_name, "\n" },
 #	'-pre_sister'     => sub { print "pre_sister: ",     shift->get_name, "\n" },
 #	'-post_sister'    => sub { print "post_sister: ",    shift->get_name, "\n" },
 #	'-post'           => sub { print "post: ",           shift->get_name, "\n" },
 #	'-order'          => 'ltr',
 #);
    sub visit_depth_first {
        my $self = shift;
        my %args = looks_like_hash @_;

# 		my @keys = qw(pre pre_daughter post_daughter in pre_sister post_sister post order with_relatives);
# 		my %permitted_keys = map { "-${_}" => 1 } @keys;
# 		for my $key ( keys %args ) {
# 			if ( not exists $permitted_keys{$key} ) {
# 				throw 'BadArgs' => "Can't use argument $key";
# 			}
# 			if ( $key ne "-with_relatives" or $key ne "-order" ) {
# 				if ( not looks_like_instance $args{$key}, 'CODE' ) {
# 					throw 'BadArgs' => "Argument $key must be a code reference";
# 				}
# 			}
# 		}
        if ( $args{'-order'} and $args{'-order'} =~ /^rtl$/i ) {
            $args{'-sister_method'}   = 'get_previous_sister';
            $args{'-daughter_method'} = 'get_last_daughter';
        }
        else {
            $args{'-sister_method'}   = 'get_next_sister';
            $args{'-daughter_method'} = 'get_first_daughter';
        }
        $self->_visit_depth_first(%args);
        return $self;
    }

    sub _visit_depth_first {
        my ( $node, %args ) = @_;
        my ( $daughter_method, $sister_method ) =
          @args{qw(-daughter_method -sister_method)};
        $args{'-pre'}->($node) if $args{'-pre'};
        if ( my $daughter = $node->$daughter_method ) {
            my @args = ($node);
            push @args, $daughter if $args{'-with_relatives'};
            $args{'-pre_daughter'}->(@args) if $args{'-pre_daughter'};
            $daughter->_visit_depth_first(%args);
            $args{'-post_daughter'}->(@args) if $args{'-post_daughter'};
        }
        else {
            $args{'-no_daughter'}->($node) if $args{'-no_daughter'};
        }
        $args{'-in'}->($node) if $args{'-in'};
        if ( my $sister = $node->$sister_method ) {
            my @args = ($node);
            push @args, $sister if $args{'-with_relatives'};
            $args{'-pre_sister'}->(@args) if $args{'-pre_sister'};
            $sister->_visit_depth_first(%args);
            $args{'-post_sister'}->(@args) if $args{'-post_sister'};
        }
        else {
            $args{'-no_sister'}->($node) if $args{'-no_sister'};
        }
        $args{'-post'}->($node) if $args{'-post'};
    }

=item visit_breadth_first()

Visits nodes breadth first

 Type    : Visitor method
 Title   : visit_breadth_first
 Usage   : $tree->visit_breadth_first( -pre => sub{ ... }, -post => sub { ... } );
 Function: Visits nodes in a breadth first traversal, executes handlers
 Returns : $tree
 Args    : Optional handlers in the order in which they would be executed on an internal node:
			
            # first event handler, is executed when node is reached in recursion
            -pre            => sub { print "pre: ",            shift->get_name, "\n" },
            
            # is executed if node has a sister, before sister is processed
            -pre_sister     => sub { print "pre_sister: ",     shift->get_name, "\n" }, 
            
            # is executed if node has a sister, after sister is processed
            -post_sister    => sub { print "post_sister: ",    shift->get_name, "\n" },         
            
            # is executed if node has no sister
            -no_sister      => sub { print "no_sister: ",      shift->get_name, "\n" },             
            
            # is executed whether or not node has sisters, if it does have sisters
            # they're processed first   
            -in             => sub { print "in: ",             shift->get_name, "\n" },         
            
            # is executed if node has a daughter, but before that daughter is processed
            -pre_daughter   => sub { print "pre_daughter: ",   shift->get_name, "\n" },
            
            # is executed if node has a daughter, after daughter has been processed 
            -post_daughter  => sub { print "post_daughter: ",  shift->get_name, "\n" },
            
            # is executed if node has no daughter
            -no_daughter    => sub { print "no_daughter: ",    shift->get_name, "\n" },                         
            
            # is executed last          
            -post           => sub { print "post: ",           shift->get_name, "\n" },
            
            # specifies traversal order, default 'ltr' means first_daugher -> next_sister
            # traversal, alternate value 'rtl' means last_daughter -> previous_sister traversal
            -order          => 'ltr', # ltr = left-to-right, 'rtl' = right-to-left
 Comments: 

=cut

    sub visit_breadth_first {
        my $self = shift;
        my %args = looks_like_hash @_;
        if ( $args{'-order'} and $args{'-order'} =~ /rtl/i ) {
            $args{'-sister_method'}   = 'get_previous_sister';
            $args{'-daughter_method'} = 'get_last_daughter';
        }
        else {
            $args{'-sister_method'}   = 'get_next_sister';
            $args{'-daughter_method'} = 'get_first_daughter';
        }
        $self->_visit_breadth_first(%args);
        return $self;
    }

    sub _visit_breadth_first {
        my ( $node, %args ) = @_;
        my ( $daughter_method, $sister_method ) =
          @args{qw(-daughter_method -sister_method)};
        $args{'-pre'}->($node) if $args{'-pre'};
        if ( my $sister = $node->$sister_method ) {
            $args{'-pre_sister'}->($node) if $args{'-pre_sister'};
            $sister->_visit_breadth_first(%args);
            $args{'-post_sister'}->($node) if $args{'-post_sister'};
        }
        else {
            $args{'-no_sister'}->($node) if $args{'-no_sister'};
        }
        $args{'-in'}->($node) if $args{'-in'};
        if ( my $daughter = $node->$daughter_method ) {
            $args{'-pre_daughter'}->($node) if $args{'-pre_daughter'};
            $daughter->_visit_breadth_first(%args);
            $args{'-post_daughter'}->($node) if $args{'-post_daughter'};
        }
        else {
            $args{'-no_daughter'}->($node) if $args{'-no_daughter'};
        }
        $args{'-post'}->($node) if $args{'-post'};
    }

=item visit_level_order()

Visits nodes in a level order traversal.

 Type    : Visitor method
 Title   : visit_level_order
 Usage   : $tree->visit_level_order( sub{...} );
 Function: Visits nodes in a level order traversal, executes sub
 Returns : $tree
 Args    : A subroutine reference that operates on visited nodes.
 Comments:

=cut	

    sub visit_level_order {
        my ( $self, $sub ) = @_;
        if ( looks_like_instance $sub, 'CODE' ) {
            my @queue = ($self);
            while (@queue) {
                my $node = shift @queue;
                $sub->($node);
                if ( my $children = $node->get_children ) {
                    push @queue, @{$children};
                }
            }
        }
        else {
            throw 'BadArgs' => "'$sub' not a CODE reference";
        }
        return $self;
    }

=back

=head2 SERIALIZERS

=over

=item to_xml()

Serializes invocant to xml.

 Type    : Serializer
 Title   : to_xml
 Usage   : my $xml = $obj->to_xml;
 Function: Turns the invocant object (and its descendants )into an XML string.
 Returns : SCALAR
 Args    : NONE

=cut

    sub to_xml {
        my $self  = shift;
        my @nodes = ( $self, @{ $self->get_descendants } );
        my $xml   = '';

        # first write out the node elements
        for my $node (@nodes) {
            if ( my $taxon = $node->get_taxon ) {
                $node->set_attributes( 'otu' => $taxon->get_xml_id );
            }
            if ( $node->is_root ) {
                $node->set_attributes( 'root' => 'true' );
            }
            $xml .= "\n" . $node->get_xml_tag(1);
        }

        # then the rootedge?
        if ( my $length = shift(@nodes)->get_branch_length ) {
            my $edge = $fac->create_xmlwritable(
                '-tag'        => 'rootedge',
                '-attributes' => {
                    'target' => $self->get_xml_id,
                    'id'     => "edge" . $self->get_id,
                    'length' => $length
                }
            );
            $xml .= "\n" . $edge->get_xml_tag(1);
        }

        # then the subtended edges
        for my $node (@nodes) {
            my $length = $node->get_branch_length;
            my $edge   = $fac->create_xmlwritable(
                '-tag'        => 'edge',
                '-attributes' => {
                    'source' => $node->get_parent->get_xml_id,
                    'target' => $node->get_xml_id,
                    'id'     => "edge" . $node->get_id
                }
            );
            $edge->set_attributes( 'length' => $length ) if defined $length;
            $xml .= "\n" . $edge->get_xml_tag(1);
        }
        return $xml;
    }

=item to_newick()

Serializes subtree subtended by invocant to newick string.

 Type    : Serializer
 Title   : to_newick
 Usage   : my $newick = $obj->to_newick;
 Function: Turns the invocant object into a newick string.
 Returns : SCALAR
 Args    : takes same arguments as Bio::Phylo::Unparsers::Newick
 Comments: takes same arguments as Bio::Phylo::Unparsers::Newick

=cut

    {
        my ( $root_id, $string );

        #no warnings 'uninitialized';
        sub to_newick {
            my $node = shift;
            my %args = @_;
            $root_id = $node->get_id if not $root_id;
            my $blformat = '%f';

            # first create the name
            my $name;
            if ( $node->is_terminal or $args{'-nodelabels'} ) {
                if ( ref $args{'-nodelabels'} and ref($args{'-nodelabels'}) eq 'CODE' ) {
                    my $id;
                    if ( $node->is_terminal ) {
                        $id = $args{'-translate'}->{$node->get_nexus_name};
                    }
                    else {
                        $id = $node->get_name;
                    }
                    $name = $args{'-nodelabels'}->($node,$id);
                }
                elsif ( not $args{'-tipnames'} ) {
                    $name = $node->get_nexus_name(1);
                }
                elsif ( $args{'-tipnames'} =~ /^internal$/i ) {
                    $name = $node->get_nexus_name(1);
                }
                elsif ( $args{'-tipnames'} =~ /^taxon/i and $node->get_taxon ) {
                    if ( $args{'-tipnames'} =~ /^taxon_internal$/i ) {
                        $name = $node->get_taxon->get_nexus_name(1);
                    }
                    elsif ( $args{'-tipnames'} =~ /^taxon$/i ) {
                        $name = $node->get_taxon->get_nexus_name(1);
                    }
                }
                else {
                    $name = $node->get_generic( $args{'-tipnames'} );
                }
                if ( $args{'-translate'}
                    and exists $args{'-translate'}->{$name} )
                {
                    $name = $args{'-translate'}->{$name};
                }
            }

            # now format branch length
            my $branch_length;
            if ( defined( $branch_length = $node->get_branch_length ) ) {
                if ( $args{'-blformat'} ) {
                    $blformat = $args{'-blformat'};
                }
                $branch_length = sprintf $blformat, $branch_length;
            }

            # now format nhx
            my $nhx;
            if ( $args{'-nhxkeys'} ) {
                my ( $sep, $sp );
                if ( $args{'-nhxstyle'} =~ /^mesquite$/i ) {
                    $sep = ',';
                    $nhx = '[%';
                    $sp = ' ';
                }
                else {
                    $sep = ':';
                    $nhx = '[&&NHX:';
                    $sp = '';
                }
                my @nhx;
                for my $i ( 0 .. $#{ $args{'-nhxkeys'} } ) {
                    my $key   = $args{'-nhxkeys'}->[$i];
                    my $value = $node->get_generic($key);
                    push @nhx, "$sp$key$sp=$sp$value$sp" if $value;
                }
                if (@nhx) {
                    $nhx .= join $sep, @nhx;
                    $nhx .= ']';
                }
                else {
                    $nhx = '';
                }
            }

            # recurse further
            if ( my $first_daughter = $node->get_first_daughter ) {
                $string .= '(';
                $first_daughter->to_newick(%args);
            }

            # append to growing newick string
            $string .= ')'                  if $node->get_first_daughter;
            $string .= $name                if defined $name;
            $string .= ':' . $branch_length if defined $branch_length;
            $string .= $nhx                 if $nhx;
            if ( $root_id == $node->get_id ) {
                undef $root_id;
                my $result = $string . ';';
                undef $string;
                return $result;
            }

            # recurse further
            elsif ( my $next_sister = $node->get_next_sister ) {
                $string .= ',';
                $next_sister->to_newick(%args);
            }
            else {
            	#$string .= ')';
            }
        }
    }

=item to_dom()

 Type    : Serializer
 Title   : to_dom
 Usage   : $node->to_dom($dom)
 Function: Generates an array of DOM elements from the invocant's
           descendants
 Returns : an array of Element objects
 Args    : DOM factory object

=cut

    sub to_dom {
        my ( $self, $dom ) = shift;
        $dom ||= $Bio::Phylo::NeXML::DOM::DOM;
        unless ( looks_like_object $dom, _DOMCREATOR_ ) {
            throw 'BadArgs' => 'DOM factory object not provided';
        }
        my @nodes = ( $self, @{ $self->get_descendants } );
        my @elts;

        # first write out the node elements
        for my $node (@nodes) {
            if ( my $taxon = $node->get_taxon ) {
                $node->set_attributes( 'otu' => $taxon->get_xml_id );
            }
            if ( $node->is_root ) {
                $node->set_attributes( 'root' => 'true' );
            }
            push @elts, $node->get_dom_elt($dom);
        }

        # then the rootedge?
        if ( my $length = shift(@nodes)->get_branch_length ) {
            my $target = $self->get_xml_id;
            my $id     = "edge" . $self->get_id;
            my $elt    = $dom->create_element(
                '-tag'        => 'rootedge',
                '-attributes' => {
                    'target' => $target,
                    'id'     => $id,
                    'length' => $length,
                }
            );
            push @elts, $elt;
        }

        # then the subtended edges
        for my $node (@nodes) {
            my $source = $node->get_parent->get_xml_id;
            my $target = $node->get_xml_id;
            my $id     = "edge" . $node->get_id;
            my $length = $node->get_branch_length;
            my $elt    = $dom->create_element(
                '-tag'        => 'edge',
                '-attributes' => {
                    'source' => $source,
                    'target' => $target,
                    'id'     => $id,
                }
            );
            $elt->set_attributes( 'length' => $length ) if ( defined $length );
            push @elts, $elt;
        }
        return @elts;
    }

=begin comment

 Type    : Internal method
 Title   : _type
 Usage   : $node->_type;
 Function:
 Returns : CONSTANT
 Args    :

=end comment

=cut

    sub _type { $TYPE_CONSTANT }
    sub _tag  { 'node' }

=begin comment

 Type    : Internal method
 Title   : _container
 Usage   : $node->_container;
 Function:
 Returns : CONSTANT
 Args    :

=end comment

=cut

    sub _container { $CONTAINER_CONSTANT }

=back

=cut

    # podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::Taxa::TaxonLinker>

This object inherits from L<Bio::Phylo::Taxa::TaxonLinker>, so methods
defined there are also applicable here.

=item L<Bio::Phylo::Listable>

This object inherits from L<Bio::Phylo::Listable>, so methods
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
__DATA__

sub add_Descendent{
   my ( $self,$child ) = @_;
   $self->set_child( $child );
   return scalar @{ $self->get_children };
}

sub each_Descendent{
	my $self = shift;
	if ( my $children = $self->get_children ) {
		return @{ $children };
   	}
   	return;
}

sub get_all_Descendents{
	my $self = shift;
	if ( my $desc = $self->get_descendants ) {
		return @{ $desc };
	}
	return;
}

*get_Descendents = \&get_all_Descendents;

*is_Leaf = \&is_terminal;
*is_otu = \&is_terminal;

sub descendent_count{
	my $self = shift;
	my $count = 0;
	if ( my $desc = get_descendants ) {
		$count = scalar @{ $desc };
	}
	return $count;
}

sub height{ shift->calc_max_path_to_tips }

sub depth{ shift->calc_path_to_root }

sub branch_length{
	my $self = shift;
	if ( @_ ) {
		$self->set_branch_length(shift);
	}
	return $self->get_branch_length;
}

sub id {
    my $self = shift;
    if ( @_ ) {
    	$self->set_name(shift);
    }
    return $self->get_name;
}

sub internal_id { shift->get_id }

sub description {
	my $self = shift;
	if ( @_ ) {
		$self->set_desc(shift);
	}
	return $self->get_desc;
}

sub bootstrap {
	my ( $self, $bs ) = @_;
	if ( defined $bs && looks_like_number $bs ) {
		$self->set_score($bs);
	}
	return $self->get_score;
}

sub ancestor {
	my $self = shift;
	if ( @_ ) {
		$self->set_parent(shift);
	}
	return $self->get_parent;
}

sub invalidate_height { }

sub add_tag_value{
	my $self = shift;
	if ( @_ ) {
		my ( $key, $value ) = @_;
		$self->set_generic( $key, $value );
	}
	return 1;
}

sub remove_tag {
	my ( $self, $tag ) = @_;
	my %hash = %{ $self->get_generic };
	my $exists = exists $hash{$tag};
	delete $hash{$tag};
	$self->set_generic();
	$self->set_generic(%hash);
	return !!$exists;
}

sub remove_all_tags{ shift->set_generic() }

sub get_all_tags {
	my $self = shift;
	my %hash = %{ $self->get_generic };
	return keys %hash;
}

sub get_tag_values{
	my ( $self, $tag ) = @_;
	my $values = $self->get_generic($tag);
	return ref $values ? @{ $values } : $values;
}

sub has_tag{
	my ( $self, $tag ) = @_;
	my %hash = %{ $self->get_generic };
	return exists $hash{$tag};
}

sub id_output { shift->get_internal_name }
