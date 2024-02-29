package Bio::Phylo::Forest::TreeRole;
use strict;
use warnings;
use Bio::Phylo::Util::MOP;
use base 'Bio::Phylo::Listable';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw'/looks_like/ :objecttypes';
use Bio::Phylo::Util::OptionalInterface 'Bio::Tree::TreeI';
use Bio::Phylo::Forest::Node;
use Bio::Phylo::IO 'unparse';
use Bio::Phylo::Factory;
use Scalar::Util 'blessed';
use List::Util qw'sum shuffle';
my $LOADED_WRAPPERS = 0;
{
    my $logger = __PACKAGE__->get_logger;
    my ( $TYPE_CONSTANT, $CONTAINER_CONSTANT ) = ( _TREE_, _FOREST_ );
    my $fac                      = Bio::Phylo::Factory->new;
    my %default_constructor_args = (
        '-listener' => sub {
            my ( $self, $method, @args ) = @_;
            for my $node (@args) {
                if ( $method eq 'insert' ) {
                    $node->set_tree($self);
                }
                elsif ( $method eq 'delete' ) {
                    $node->set_tree();
                }
                elsif ( $method eq '_set_things' ) {
                    $_->set_tree($self) for @{ $node };
                }
            }
        },
    );

=head1 NAME

Bio::Phylo::Forest::TreeRole - Extra behaviours for a phylogenetic tree

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

The object models a phylogenetic tree, a container of
L<Bio::Phylo::Forest::Node> objects. The tree object
inherits from L<Bio::Phylo::Listable>, so look there
for more methods.

=head1 METHODS

=head2 CONSTRUCTORS

=over

=item new()

Tree constructor.

 Type    : Constructor
 Title   : new
 Usage   : my $tree = Bio::Phylo::Forest::Tree->new;
 Function: Instantiates a Bio::Phylo::Forest::Tree object.
 Returns : A Bio::Phylo::Forest::Tree object.
 Args    : No required arguments.

=cut

    sub new : Constructor {

        # could be child class
        my $class = shift;

        # notify user
        $logger->info("constructor called for '$class'");
        if ( not $LOADED_WRAPPERS ) {
            eval do { local $/; <DATA> };
            $LOADED_WRAPPERS++;
        }

        # go up inheritance tree, eventually get an ID
        my $self = $class->SUPER::new( %default_constructor_args, @_ );
        return $self;
    }

=item new_from_bioperl()

Tree constructor from Bio::Tree::TreeI argument.

 Type    : Constructor
 Title   : new_from_bioperl
 Usage   : my $tree = 
           Bio::Phylo::Forest::Tree->new_from_bioperl(
               $bptree           
           );
 Function: Instantiates a 
           Bio::Phylo::Forest::Tree object.
 Returns : A Bio::Phylo::Forest::Tree object.
 Args    : A tree that implements Bio::Tree::TreeI

=cut

    sub new_from_bioperl {
        my ( $class, $bptree ) = @_;
        my $self;
        if ( blessed $bptree && $bptree->isa('Bio::Tree::TreeI') ) {
            $self = $fac->create_tree;
#            bless $self, $class;
            $self = $self->_recurse( $bptree->get_root_node );

            # copy name
            my $name = $bptree->id;
            $self->set_name($name) if defined $name;

            # copy score
            my $score = $bptree->score;
            $self->set_score($score) if defined $score;
        }
        else {
            throw 'ObjectMismatch' => 'Not a bioperl tree!';
        }
        return $self;
    }

=begin comment

 Type    : Internal method
 Title   : _recurse
 Usage   : $tree->_recurse( $bpnode );
 Function: Traverses a bioperl tree, instantiates a Bio::Phylo::Forest::Node
           object for every Bio::Tree::NodeI object it encounters, copying
           the parent, sibling and child relationships.
 Returns : None (modifies invocant).
 Args    : A Bio::Tree::NodeI object.

=end comment

=cut    

    sub _recurse {
        my ( $self, $bpnode, $parent ) = @_;
        my $node = Bio::Phylo::Forest::Node->new_from_bioperl($bpnode);
        if ($parent) {
            $parent->set_child($node);
        }
        $self->insert($node);
        foreach my $bpchild ( $bpnode->each_Descendent ) {
            $self->_recurse( $bpchild, $node );
        }
        return $self;
    }

=begin comment

 Type    : Internal method
 Title   : _analyze
 Usage   : $tree->_analyze;
 Function: Traverses the tree, creates references to first_daughter,
           last_daughter, next_sister and previous_sister.
 Returns : A Bio::Phylo::Forest::Tree object.
 Args    : none.
 Comments: This method only looks at the parent, so theoretically
           one could mess around with the
           Bio::Phylo::Forest::Node::set_parent(Bio::Phylo::Forest::Node) method and
           subsequently call Bio::Phylo::Forest::Tree::_analyze to overwrite old
           (and wrong) child and sister references with new (and correct) ones.

=end comment

=cut

    sub _analyze {
        my $tree  = $_[0];
        my $nodes = $tree->get_entities;
        foreach ( @{$nodes} ) {
            $_->set_next_sister();
            $_->set_previous_sister();
            $_->set_first_daughter();
            $_->set_last_daughter();
        }
        my ( $first, $next );

        # mmmm... O(N^2)
      NODE: for my $i ( 0 .. $#{$nodes} ) {
            $first = $nodes->[$i];
            for my $j ( ( $i + 1 ) .. $#{$nodes} ) {
                $next = $nodes->[$j];
                my ( $firstp, $nextp ) =
                  ( $first->get_parent, $next->get_parent );
                if ( $firstp && $nextp && $firstp == $nextp ) {
                    if ( !$first->get_next_sister ) {
                        $first->set_next_sister($next);
                    }
                    if ( !$next->get_previous_sister ) {
                        $next->set_previous_sister($first);
                    }
                    next NODE;
                }
            }
        }

        # O(N)
        foreach ( @{$nodes} ) {
            my $p = $_->get_parent;
            if ($p) {
                if ( !$_->get_next_sister ) {
                    $p->set_last_daughter($_);
                    next;
                }
                if ( !$_->get_previous_sister ) {
                    $p->set_first_daughter($_);
                }
            }
        }
        return $tree;
    }

=back 

=head2 QUERIES

=over

=item get_midpoint()

Gets node that divides tree into two distance-balanced partitions.

 Type    : Query
 Title   : get_midpoint
 Usage   : my $midpoint = $tree->get_midpoint;
 Function: Gets node nearest to the middle of the longest path
 Returns : A Bio::Phylo::Forest::Node object.
 Args    : NONE
 Comments: This algorithm was ported from ETE. 
           It assumes the tree has branch lengths.

=cut

    sub get_midpoint {
        my $self     = shift;
        my $root     = $self->get_root;
        my $nA       = $self->get_tallest_tip;
        my $nB       = $nA->get_farthest_node(1);
        $logger->error("no farthest node!") unless $nB; 
        my $A2B_dist = $nA->calc_path_to_root + $nB->calc_path_to_root;
        my $outgroup = $nA;
        my $middist  = $A2B_dist / 2;
        my $cdist    = 0;
        my $current  = $nA;
        while ($current) {

            if ( $cdist > $middist ) {
                last;
            }
            else {
                if ( my $parent = $current->get_parent ) {
                    $cdist += $current->get_branch_length;
                    $current = $parent;
                }
                else {
                    last;
                }
            }
        }
        return $current;
    }

=item get_terminals()

Get terminal nodes.

 Type    : Query
 Title   : get_terminals
 Usage   : my @terminals = @{ $tree->get_terminals };
 Function: Retrieves all terminal nodes in
           the Bio::Phylo::Forest::Tree object.
 Returns : An array reference of 
           Bio::Phylo::Forest::Node objects.
 Args    : NONE
 Comments: If the tree is valid, this method 
           retrieves the same set of nodes as 
           $node->get_terminals($root). However, 
           because there is no recursion it may 
           be faster. Also, the node method by 
           the same name does not see orphans.

=cut

    sub get_terminals {
        my $self = shift;
        my @terminals;
        if ( my $root = $self->get_root ) {
            $root->visit_level_order(
                sub {
                    my $node = shift;
                    if ( $node->is_terminal ) {
                        push @terminals, $node;
                    }
                }
            );
        }
        else {
            $self->visit(
                sub {
                    my $n = shift;
                    if ( $n->is_terminal ) {
                        push @terminals, $n;
                    }
                }
            );
        }
        return \@terminals;
    }

=item get_internals()

Get internal nodes.

 Type    : Query
 Title   : get_internals
 Usage   : my @internals = @{ $tree->get_internals };
 Function: Retrieves all internal nodes 
           in the Bio::Phylo::Forest::Tree object.
 Returns : An array reference of 
           Bio::Phylo::Forest::Node objects.
 Args    : NONE
 Comments: If the tree is valid, this method 
           retrieves the same set of nodes as 
           $node->get_internals($root). However, 
           because there is no recursion it may 
           be faster. Also, the node method by 
           the same name does not see orphans.

=cut

    sub get_internals {
        my $self = shift;
        my @internals = grep { scalar @{ $_->get_children } } @{ $self->get_entities };
        return \@internals;
    }

=item get_cherries()

Get all cherries, i.e. nodes that have two terminal children

 Type    : Query
 Title   : get_cherries
 Usage   : my @cherries = @{ $tree->get_cherries };
 Function: Returns an array ref of cherries
 Returns : ARRAY
 Args    : NONE

=cut

    sub get_cherries {
        my $self = shift;
        my @cherries;
        for my $node ( @{ $self->get_entities } ) {
            my @children = @{ $node->get_children };
            
            # node has to be bifurcating
            if ( scalar(@children) == 2 ) {
                
                # both children need to be tips
                if ( not @{ $children[0]->get_children } and not @{ $children[1]->get_children } ) {
                    push @cherries, $node;
                }
            }
        }        
        return \@cherries;
    }

=item get_all_rootings()

Gets a forest of all rooted versions of the invocant tree.

 Type    : Query
 Title   : get_all_rootings
 Usage   : my $forest = $tree->get_all_rootings;
 Function: Returns an array ref of cherries
 Returns : Bio::Phylo::Forest object
 Args    : NONE
 Comments: This method assumes the invocant tree has a basal trichotomy.
           "Rooted" trees with a basal bifurcation will give strange
           results.

=cut    

    sub get_all_rootings {
        my $self = shift;
        my $forest = $fac->create_forest;
        
        # iterate over all nodes
        my $i = 0;
        $self->visit(sub{
           
            # clone the tree
            my $clone = $self->clone;
            my $node  = $clone->get_by_index($i++);
            my $anc   = $node->get_ancestors;
            
            # create the new root if node isn't already root
            if ( $anc->[0] ) {
                my $nroot = $fac->create_node;
                $nroot->set_child($node);
                $clone->insert($nroot);
                $anc->[0]->delete($node) if $anc->[0];
                
                # flip the nodes on the path to the root
                for my $j ( 0 .. $#{ $anc } ) {
                    $nroot->set_child($anc->[$j]);                
                    $nroot = $anc->[$j];
                }
                $forest->insert($clone);
            }
        });
        return $forest;
    }

    
=item get_root()

Get root node.

 Type    : Query
 Title   : get_root
 Usage   : my $root = $tree->get_root;
 Function: Returns the root node.
 Returns : Bio::Phylo::Forest::Node
 Args    : NONE

=cut

    sub get_root {
        my $self = shift;
        
        # the simplest approach: look for nodes without parents
        my ($root) = grep { ! $_->get_parent } @{ $self->get_entities };
        if ( $root ) {
            return $root;
        }
        
        else {
            my ( %children_of, %node_by_id );
            for my $node ( @{ $self->get_entities } ) {
                $node_by_id{ $node->get_id } = $node;
                if ( my $parent = $node->get_parent ) {
                    my $parent_id = $parent->get_id;
                    $children_of{$parent_id} = [] if not $children_of{$parent_id};
                    push @{ $children_of{$parent_id} }, $node;
                }
                else {
                    return $node;
                }
            }
            for my $parent ( keys %children_of ) {
                if ( not exists $node_by_id{$parent} ) {
                    my @children = @{ $children_of{$parent} };
                    if ( scalar @children > 1 ) {
                        $logger->warn("Tree has multiple roots");
                    }
                    return shift @children;
                }
            }
            return;
        }
    }

=item get_ntax()

Gets number of tips

 Type    : Query
 Title   : get_ntax
 Usage   : my $ntax = $tree->get_ntax;
 Function: Calculates the number of terminal nodes
 Returns : Int
 Args    : NONE

=cut
    
    sub get_ntax { scalar(@{ shift->get_terminals } ) }

=item get_tallest_tip()

Retrieves the node furthest from the root. 

 Type    : Query
 Title   : get_tallest_tip
 Usage   : my $tip = $tree->get_tallest_tip;
 Function: Retrieves the node furthest from the
           root in the current Bio::Phylo::Forest::Tree
           object.
 Returns : Bio::Phylo::Forest::Node
 Args    : NONE
 Comments: If the tree has branch lengths, the tallest tip is
           based on root-to-tip path length, else it is based
           on number of nodes to root

=cut

    sub get_tallest_tip {
        my $self = shift;
        my $criterion;

        # has (at least some) branch lengths
        if ( $self->calc_tree_length ) {
            $criterion = 'calc_path_to_root';
        }
        else {
            $criterion = 'calc_nodes_to_root';
        }
        my $tallest;
        my $height = 0;
        for my $tip ( @{ $self->get_terminals } ) {
            if ( my $path = $tip->$criterion ) {
                if ( $path > $height ) {
                    $tallest = $tip;
                    $height  = $path;
                }
            }
        }
        return $tallest;
    }

=item get_nodes_for_taxa()

Gets node objects for the supplied taxon objects

 Type    : Query
 Title   : get_nodes_for_taxa
 Usage   : my @nodes = @{ $tree->get_nodes_for_taxa(\@taxa) };
 Function: Gets node objects for the supplied taxon objects
 Returns : array ref of Bio::Phylo::Forest::Node objects
 Args    : A reference to an array of Bio::Phylo::Taxa::Taxon objects
           or a Bio::Phylo::Taxa object

=cut

    sub get_nodes_for_taxa {
        my ( $self, $taxa ) = @_;
        my ( $is_taxa, $taxa_objs );
        eval { $is_taxa = looks_like_object $taxa, _TAXA_ };
        if ( $is_taxa and not $@ ) {
            $taxa_objs = $taxa->get_entities;
        }
        else {
            $taxa_objs = $taxa;
        }
        my %ids = map { $_->get_id => 1 } @{$taxa_objs};
        my @nodes;
        for my $node ( @{ $self->get_entities } ) {
            if ( my $taxon = $node->get_taxon ) {
                push @nodes, $node if $ids{ $taxon->get_id };
            }
        }
        return \@nodes;
    }

=item get_mrca()

Get most recent common ancestor of argument nodes.

 Type    : Query
 Title   : get_mrca
 Usage   : my $mrca = $tree->get_mrca(\@nodes);
 Function: Retrieves the most recent 
           common ancestor of \@nodes
 Returns : Bio::Phylo::Forest::Node
 Args    : A reference to an array of 
           Bio::Phylo::Forest::Node objects 
           in $tree.

=cut

    sub get_mrca {
        my ( $tree, $nodes ) = @_;
        if ( not $nodes or not @{$nodes} ) {
            return;
        }
        elsif ( scalar @{$nodes} == 1 ) {
            return $nodes->[0];
        }
        else {
            my $node1 = shift @{$nodes};
            my $node2 = shift @{$nodes};
            my $anc1  = $node1->get_ancestors;
            my $anc2  = $node2->get_ancestors;
            unshift @{$anc1}, $node1;
            unshift @{$anc2}, $node2;
          TRAVERSAL: for my $i ( 0 .. $#{$anc1} ) {
                for my $j ( 0 .. $#{$anc2} ) {
                    if ( $anc1->[$i]->get_id == $anc2->[$j]->get_id ) {
                        unshift @{$nodes}, $anc1->[$i];
                        last TRAVERSAL;
                    }
                }
            }
            return $tree->get_mrca($nodes);
        }
    }

=back

=head2 TESTS

=over

=item is_binary()

Test if tree is bifurcating.

 Type    : Test
 Title   : is_binary
 Usage   : if ( $tree->is_binary ) {
              # do something
           }
 Function: Tests whether the invocant 
           object is bifurcating.
 Returns : BOOLEAN
 Args    : NONE

=cut

    sub is_binary {
        my $self = shift;
        my $return = 1;
        $self->visit(sub{
        	my $count = scalar(@{ shift->get_children });
        	$return = 0 if $count != 0 && $count != 2;
        });
        $return;
    }

=item is_ultrametric()

Test if tree is ultrametric.

 Type    : Test
 Title   : is_ultrametric
 Usage   : if ( $tree->is_ultrametric(0.01) ) {
              # do something
           }
 Function: Tests whether the invocant is 
           ultrametric.
 Returns : BOOLEAN
 Args    : Optional margin between pairwise 
           comparisons (default = 0).
 Comments: The test is done by performing 
           all pairwise comparisons for
           root-to-tip path lengths. Since many 
           programs introduce rounding errors 
           in branch lengths the optional argument is
           available to test TRUE for nearly 
           ultrametric trees. For example, a value 
           of 0.01 indicates that no pairwise
           comparison may differ by more than 1%. 
           Note: behaviour is undefined for 
           negative branch lengths.

=cut

    sub is_ultrametric {
        my $tree = shift;
        my $margin = shift || 0;
        my ( @tips, %path );
        $tree->visit_depth_first(
            '-pre' => sub {
                my $node = shift;
                if ( my $parent = $node->get_parent ) {
                    $path{ $node->get_id } =
                      $path{ $parent->get_id } +
                      ( $node->get_branch_length || 0 );
                }
                else {
                    $path{ $node->get_id } = $node->get_branch_length || 0;
                }
                push @tips, $node if $node->is_terminal;
            }
        );
        for my $i ( 0 .. ( $#tips - 1 ) ) {
            my $id1 = $tips[$i]->get_id;
          PATH: for my $j ( $i + 1 .. $#tips ) {
                my $id2 = $tips[$j]->get_id;
                next PATH unless $path{$id2};
                return 0 if abs( 1 - $path{$id1} / $path{$id2} ) > $margin;
            }
        }
        return 1;
    }

=item is_monophyletic()

Tests if first argument (node array ref) is monophyletic with respect
to second argument.

 Type    : Test
 Title   : is_monophyletic
 Usage   : if ( $tree->is_monophyletic(\@tips, $node) ) {
              # do something
           }
 Function: Tests whether the set of \@tips is
           monophyletic w.r.t. $outgroup.
 Returns : BOOLEAN
 Args    : A reference to a list of nodes, and a node.
 Comments: This method is essentially the
           same as 
           &Bio::Phylo::Forest::Node::is_outgroup_of.

=cut

    sub is_monophyletic {
        my $tree = shift;
        my ( $nodes, $outgroup );
        if ( @_ == 2 ) {
            ( $nodes, $outgroup ) = @_;
        }
        elsif ( @_ == 4 ) {
            my %args = @_;
            $nodes    = $args{'-nodes'};
            $outgroup = $args{'-outgroup'};
        }
        for my $i ( 0 .. $#{$nodes} ) {
            for my $j ( ( $i + 1 ) .. $#{$nodes} ) {
                my $mrca = $nodes->[$i]->get_mrca( $nodes->[$j] );
                return if $mrca->is_ancestor_of($outgroup);
            }
        }
        return 1;
    }

=item is_paraphyletic()

 Type    : Test
 Title   : is_paraphyletic
 Usage   : if ( $tree->is_paraphyletic(\@nodes,$node) ){ }
 Function: Tests whether or not a given set of nodes are paraphyletic
           (representing the full clade) given an outgroup
 Returns : [-1,0,1] , -1 if the group is not monophyletic
                       0 if the group is not paraphyletic
                       1 if the group is paraphyletic
 Args    : Array ref of node objects which are in the tree,
           Outgroup to compare the nodes to

=cut

    sub is_paraphyletic {
        my $tree = shift;
        my ( $nodes, $outgroup );
        if ( @_ == 2 ) {
            ( $nodes, $outgroup ) = @_;
        }
        elsif ( @_ == 4 ) {
            my %args = @_;
            $nodes    = $args{'-nodes'};
            $outgroup = $args{'-outgroup'};
        }
        return -1 if !$tree->is_monophyletic( $nodes, $outgroup );
        my @all  = ( @{$nodes}, $outgroup );
        my $mrca = $tree->get_mrca( \@all );
        my $tips = $mrca->get_terminals;
        return scalar @{$tips} == scalar @all ? 0 : 1;
    }

=item is_clade()

Tests if argument (node array ref) forms a clade.

 Type    : Test
 Title   : is_clade
 Usage   : if ( $tree->is_clade(\@tips) ) {
              # do something
           }
 Function: Tests whether the set of 
           \@tips forms a clade
 Returns : BOOLEAN
 Args    : A reference to an array of Bio::Phylo::Forest::Node objects, or a
           reference to an array of Bio::Phylo::Taxa::Taxon objects, or a
	   Bio::Phylo::Taxa object
 Comments:

=cut

    sub is_clade {
        my ( $tree, $arg ) = @_;
        my ( $is_taxa, $is_node_array, $tips );

        # check if arg is a Taxa object
        eval { $is_taxa = looks_like_object $arg, _TAXA_ };
        if ( $is_taxa and not $@ ) {
            $tips = $tree->get_nodes_for_taxa($arg);
        }

        # check if arg is an array of Taxon object
        eval { $is_node_array = looks_like_object $arg->[0], _TAXON_ };
        if ( $is_node_array and not $@ ) {
            $tips = $tree->get_nodes_for_taxa($arg);
        }
        else {
            $tips = $arg;    # arg is an array of Node objects
        }
        my $mrca;
        for my $i ( 1 .. $#{$tips} ) {
            $mrca ? $mrca = $mrca->get_mrca( $tips->[$i] ) : $mrca =
              $tips->[0]->get_mrca( $tips->[$i] );
        }
        scalar @{ $mrca->get_terminals } == scalar @{$tips} ? return 1 : return;
    }

=item is_cladogram()

Tests if tree is a cladogram (i.e. no branch lengths)

 Type    : Test
 Title   : is_cladogram
 Usage   : if ( $tree->is_cladogram() ) {
              # do something
           }
 Function: Tests whether the tree is a 
           cladogram (i.e. no branch lengths)
 Returns : BOOLEAN
 Args    : NONE
 Comments:

=cut

    sub is_cladogram {
        my $tree = shift;
        for my $node ( @{ $tree->get_entities } ) {
            return 0 if defined $node->get_branch_length;
        }
        return 1;
    }

=back

=head2 CALCULATIONS

=over

=item calc_branch_length_distance()

Calculates the Euclidean branch length distance between two trees. See
Kuhner & Felsenstein (1994). A simulation comparison of phylogeny algorithms
under equal and unequal evolutionary rates. MBE 11(3):459-468.

 Type    : Calculation
 Title   : calc_branch_length_distance
 Usage   : my $distance = 
           $tree1->calc_branch_length_distance($tree2);
 Function: Calculates the Euclidean branch length distance between two trees
 Returns : SCALAR, number
 Args    : NONE

=cut

    #=item calc_robinson_foulds_distance()
    #
    #Calculates the Robinson and Foulds distance between two trees.
    #
    # Type    : Calculation
    # Title   : calc_robinson_foulds_distance
    # Usage   : my $distance =
    #           $tree1->calc_robinson_foulds_distance($tree2);
    # Function: Calculates the Robinson and Foulds distance between two trees
    # Returns : SCALAR, number
    # Args    : NONE
    #
    #=cut
    #
    #	sub calc_robinson_foulds_distance {
    #		my ( $self, $other ) = @_;
    #		my $tuples = $self->_calc_branch_diffs($other);
    #		my $sum = 0;
    #		for my $tuple ( @{ $tuples } ) {
    #			my $diff = $tuple->[0] - $tuple->[1];
    #			$sum += abs $diff;
    #		}
    #		return $sum;
    #	}
    sub calc_branch_length_distance {
        my ( $self, $other ) = @_;
        my $squared = $self->calc_branch_length_score($other);
        return sqrt($squared);
    }

=item calc_branch_length_score()

Calculates the squared Euclidean branch length distance between two trees.

 Type    : Calculation
 Title   : calc_branch_length_score
 Usage   : my $score = 
           $tree1->calc_branch_length_score($tree2);
 Function: Calculates the squared Euclidean branch
           length distance between two trees
 Returns : SCALAR, number
 Args    : A Bio::Phylo::Forest::Tree object,           
           Optional second argument flags that results should be normalized
=cut

    sub calc_branch_length_score {
        my ( $self, $other, $normalize ) = @_;
        my $tuples = $self->_calc_branch_diffs($other);
        my $sum    = 0;
        for my $tuple ( @{$tuples} ) {
            my $diff = ( $tuple->[0] || 0 ) - ( $tuple->[1] || 0 );
            $sum += $diff**2;
        }
        return $normalize ? $sum / scalar(@{$tuples}) : $sum;
    }


=begin comment

Returns an array ref containing array references, with the first element of 
each nested array ref representing the length of the branch subtending a 
particular split on the invocant (or 0), the second element the length of the 
same branch on argument (or 0), the third element a boolean to indicate whether 
the split was present in both trees, and the fourth element a sorted, comma-separated
list of the MD5-hashed names of all tips subtended by that split.

 Type    : Calculation
 Title   : calc_branch_diffs
 Usage   : my $triples = 
           $tree1->calc_branch_diffs($tree2);
 Function: Creates two-dimensional array of equivalent branch lengths
 Returns : Two-dimensional array (triples)
 Args    : NONE

=end comment

=cut

    sub _calc_branch_diffs {
        my ( $self, $other ) = @_;

        # we create an anonymous subroutine which
        # we will apply to $self and $other
        my $length_for_split_creator = sub {

            # so this will be $self and $other
            my $tree = shift;

            # keys will be hashed, comma-separated tip names,
            # values will be branch lengths
            my %length_for_split;

            # this will assemble the comma-separated,
            # hashed tip names
            my %hash_for_node;

            # post-order traversal, so tips are processed first
            $tree->visit_depth_first(
                '-post' => sub {
                    my $node     = shift;
                    my $id       = $node->get_id;
                    my @children = @{ $node->get_children };
                    my $hash;

                    # we only enter into this case AFTER tips
                    # have been processed, so %hash_for_node
                    # values will be assigned for all children
                    if (@children and $node->get_parent) {

                        # these will be growing lists from
                        # tips to root
                        my $unsorted = join ',',
                          map { $hash_for_node{ $_->get_id } } @children;

                        # we need to split, sort and join
                        # so that splits where the subtended,
                        # higher topology is different still
                        # yield the same concatenated hash
                        $hash = join ',', sort { $a cmp $b } split /,/,
                          $unsorted;

                        # coerce to a numeric type
                        $length_for_split{$hash} = $node->get_branch_length || 0;
                    }
                    else {

                        # this is how we ensure that every tip name is a 
                        # single, unique string without unexpected characters
                        # (especially, commas).
                        # Digest::MD5 was in CORE since 5.7
                        require Digest::MD5;
                        $hash = Digest::MD5::md5( $node->get_name );                        
                    }

                    # store for the next recursion
                    $hash_for_node{$id} = $hash;
                }
            );

            # this is the return value for the anonymous sub
            return %length_for_split;
        };

        # here we execute the anonymous sub. twice.
        my %lengths_self  = $length_for_split_creator->($self);
        my %lengths_other = $length_for_split_creator->($other);
        my @tuples;

        # first visit the splits in $self, which will identify
        # those it shares with $other and those missing in $other
        for my $split ( keys %lengths_self ) {
            my $tuple;
            if ( exists $lengths_other{$split} ) {
                $tuple =
                  [ $lengths_self{$split}, $lengths_other{$split} || 0, 1, $split ];
            }
            else {
                $tuple = [ $lengths_self{$split}, 0, 0, $split ];
            }
            push @tuples, $tuple;
        }

        # then check if there are splits in $other but not in $self
        for my $split ( keys %lengths_other ) {
            if ( not exists $lengths_self{$split} ) {
                push @tuples, [ 0, $lengths_other{$split}, 0, $split ];
            }
        }
        return \@tuples;
    }

=item calc_tree_length()

Calculates the sum of all branch lengths.

 Type    : Calculation
 Title   : calc_tree_length
 Usage   : my $tree_length = 
           $tree->calc_tree_length;
 Function: Calculates the sum of all branch 
           lengths (i.e. the tree length).
 Returns : FLOAT
 Args    : NONE

=cut

    sub calc_tree_length {
        my $self = shift;
        my $tl   = 0;
        $self->visit(sub{
        	$tl += shift->get_branch_length || 0;
        });
        return $tl;
    }

=item calc_tree_height()

Calculates the height of the tree.

 Type    : Calculation
 Title   : calc_tree_height
 Usage   : my $tree_height = 
           $tree->calc_tree_height;
 Function: Calculates the height 
           of the tree.
 Returns : FLOAT
 Args    : NONE
 Comments: For ultrametric trees this 
           method returns the height, but 
           this is done by averaging over 
           all root-to-tip path lengths, so 
           for additive trees the result 
           should consequently be interpreted
           differently.

=cut

    sub calc_tree_height {
        my $self = shift;
        my $th   = $self->calc_total_paths / $self->calc_number_of_terminals;
        return $th;
    }

=item calc_number_of_nodes()

Calculates the number of nodes.

 Type    : Calculation
 Title   : calc_number_of_nodes
 Usage   : my $number_of_nodes = 
           $tree->calc_number_of_nodes;
 Function: Calculates the number of 
           nodes (internals AND terminals).
 Returns : INT
 Args    : NONE

=cut

    sub calc_number_of_nodes {
        my $self     = shift;
        my $numnodes = scalar @{ $self->get_entities };
        return $numnodes;
    }

=item calc_number_of_terminals()

Calculates the number of terminal nodes.

 Type    : Calculation
 Title   : calc_number_of_terminals
 Usage   : my $number_of_terminals = 
           $tree->calc_number_of_terminals;
 Function: Calculates the number 
           of terminal nodes.
 Returns : INT
 Args    : NONE

=cut

    sub calc_number_of_terminals {
        my $self    = shift;
        my $numterm = scalar @{ $self->get_terminals };
        return $numterm;
    }

=item calc_number_of_internals()

Calculates the number of internal nodes.

 Type    : Calculation
 Title   : calc_number_of_internals
 Usage   : my $number_of_internals = 
           $tree->calc_number_of_internals;
 Function: Calculates the number 
           of internal nodes.
 Returns : INT
 Args    : NONE

=cut

    sub calc_number_of_internals {
        my $self   = shift;
        my $numint = scalar @{ $self->get_internals };
        return $numint;
    }

=item calc_number_of_cherries()

Calculates the number of cherries, i.e. the number of nodes that subtend
exactly two tips. See for applications of this metric:
L<http://dx.doi.org/10.1016/S0025-5564(99)00060-7>

 Type    : Calculation
 Title   : calc_number_of_cherries
 Usage   : my $number_of_cherries = 
           $tree->calc_number_of_cherries;
 Function: Calculates the number of cherries
 Returns : INT
 Args    : NONE

=cut

    sub calc_number_of_cherries {
        my $self = shift;
        my %cherry;
        for my $tip ( @{ $self->get_terminals } ) {
            if ( my $parent = $tip->get_parent ) {
                if ( $parent->is_preterminal ) {
                    my $children = $parent->get_children;
                    if ( scalar @{$children} == 2 ) {
                        $cherry{ $parent->get_id }++;
                    }
                }
            }
        }
        my @cherry_ids = keys %cherry;
        return scalar @cherry_ids;
    }

=item calc_total_paths()

Calculates the sum of all root-to-tip path lengths.

 Type    : Calculation
 Title   : calc_total_paths
 Usage   : my $total_paths = 
           $tree->calc_total_paths;
 Function: Calculates the sum of all 
           root-to-tip path lengths.
 Returns : FLOAT
 Args    : NONE

=cut

    sub calc_total_paths {
        my $self = shift;
        my $tp   = 0;
        foreach ( @{ $self->get_terminals } ) {
            $tp += $_->calc_path_to_root;
        }
        return $tp;
    }

=item calc_redundancy()

Calculates the amount of shared (redundant) history on the total.

 Type    : Calculation
 Title   : calc_redundancy
 Usage   : my $redundancy = 
           $tree->calc_redundancy;
 Function: Calculates the amount of shared 
           (redundant) history on the total.
 Returns : FLOAT
 Args    : NONE
 Comments: Redundancy is calculated as
 1 / ( treelength - height / ( ntax * height - height ) )

=cut

    sub calc_redundancy {
        my $self = shift;
        my $tl   = $self->calc_tree_length;
        my $th   = $self->calc_tree_height;
        my $ntax = $self->calc_number_of_terminals;
        my $red  = 1 - ( ( $tl - $th ) / ( ( $th * $ntax ) - $th ) );
        return $red;
    }

=item calc_imbalance()

Calculates Colless' coefficient of tree imbalance.

 Type    : Calculation
 Title   : calc_imbalance
 Usage   : my $imbalance = $tree->calc_imbalance;
 Function: Calculates Colless' coefficient 
           of tree imbalance.
 Returns : FLOAT
 Args    : NONE
 Comments: As described in Colless, D.H., 1982. 
           The theory and practice of phylogenetic 
           systematics. Systematic Zoology 31(1): 100-104

=cut

    sub calc_imbalance {
        my $self = shift;
        my %descendants;
        my $n = 0;
        my $sumdiff = 0;
        $self->visit_depth_first(
            '-post' => sub {
                my $node = shift;
                my @children = @{ $node->get_children };
                
                # node is internal, compute n descendants left and right
                if ( @children == 2 ) {
                    my $li = shift @children;
                    my $ri = shift @children;
                    my $li_ndesc = $descendants{$li->get_id};
                    my $ri_ndesc = $descendants{$ri->get_id};
                    $sumdiff += abs($li_ndesc - $ri_ndesc);
                    $descendants{$node->get_id} = $li_ndesc + $ri_ndesc;
                }
                
                # node is terminal, initialize tally of descendants
                elsif ( @children == 0 ) {
                    $n++;
                    $descendants{$node->get_id} = 1;
                }
                
                # node is either a polytomy or an unbranched internal. Can't proceed in either case.
                else {
                    throw 'ObjectMismatch' => "Colless's imbalance only possible for binary trees";
                }
            }
        );
        if ( $n < 3 ) {
        	$logger->error("too few nodes in tree: $n<=2");
        	return undef;
        }
        else {
        	return $sumdiff / ( ($n-1) * ($n-2) / 2 );
        }
    }

=item calc_i2()

Calculates I2 imbalance.

 Type    : Calculation
 Title   : calc_i2
 Usage   : my $ci2 = $tree->calc_i2;
 Function: Calculates I2 imbalance.
 Returns : FLOAT
 Args    : NONE
 Comments:

=cut

    sub calc_i2 {
        my $self = shift;
        my ( $maxic, $sum, $I2 ) = ( 0, 0 );
        if ( !$self->is_binary ) {
            throw 'ObjectMismatch' => 'I2 imbalance only possible for binary trees';
        }
        my $numtips = $self->calc_number_of_terminals;
        $numtips -= 2;
        while ($numtips) {
            $maxic += $numtips;
            $numtips--;
        }
        foreach my $node ( @{ $self->get_internals } ) {
            my ( $fd, $ld, $ftips, $ltips ) =
              ( $node->get_first_daughter, $node->get_last_daughter, 0, 0 );
            if ( $fd->is_internal ) {
                foreach ( @{ $fd->get_descendants } ) {
                    if ( $_->is_terminal ) {
                        $ftips++;
                    }
                    else {
                        next;
                    }
                }
            }
            else {
                $ftips = 1;
            }
            if ( $ld->is_internal ) {
                foreach ( @{ $ld->get_descendants } ) {
                    if ( $_->is_terminal ) {
                        $ltips++;
                    }
                    else {
                        next;
                    }
                }
            }
            else {
                $ltips = 1;
            }
            next unless ( $ftips + $ltips - 2 );
            $sum += abs( $ftips - $ltips ) / abs( $ftips + $ltips - 2 );
        }
        if ( $maxic == 0 ) {
        	$logger->error("too few nodes in tree: $maxic==0");
        	return undef;
        }
        else {
        	$I2 = $sum / $maxic;
        	return $I2;
        }
    }

=item calc_gamma()

Calculates the Pybus & Harvey (2000) gamma statistic.

 Type    : Calculation
 Title   : calc_gamma
 Usage   : my $gamma = $tree->calc_gamma();
 Function: Calculates the Pybus gamma statistic
 Returns : FLOAT
 Args    : NONE
 Comments: As described in Pybus, O.G. and 
           Harvey, P.H., 2000. Testing
           macro-evolutionary models using 
           incomplete molecular phylogenies. 
           Proc. R. Soc. Lond. B 267, 2267-2272

=cut

    # code due to Aki Mimoto
    sub calc_gamma {
        my $self      = shift;
        my $tl        = $self->calc_tree_length;
        my $terminals = $self->get_terminals;
        my $n         = scalar @{$terminals};
        my $height    = $self->calc_tree_height;

      # Calculate the distance of each node to the root
      #        my %soft_refs;
      #        my $root = $self->get_root;
      #        $soft_refs{$root} = 0;
      #        my @nodes = $root;
      #        while (@nodes) {
      #            my $node     = shift @nodes;
      #            my $path_len = $soft_refs{$node} += $node->get_branch_length;
      #            my $children = $node->get_children or next;
      #            for my $child (@$children) {
      #                $soft_refs{$child} = $path_len;
      #            }
      #            push @nodes, @{$children};
      #        }
      # the commented out block is more efficiently implemented like so:
        my %soft_refs =
          map { $_ => $_->calc_path_to_root } @{ $self->get_entities };

        # Then, we know how far each node is from the root. At this point, we
        # can sort through and create the @g array
        my %node_spread =
          map { ( $_ => 1 ) } values %soft_refs;    # remove duplicates
        my @sorted_nodes = sort { $a <=> $b } keys %node_spread;
        my $prev = 0;
        my @g;
        for my $length (@sorted_nodes) {
            push @g, $length - $prev;
            $prev = $length;
        }
        my $sum = 0;
        eval { require Math::BigFloat };
        if ($@) {                                   # BigFloat is not available.
            for ( my $i = 2 ; $i < $n ; $i++ ) {
                for ( my $k = 2 ; $k <= $i ; $k++ ) {
                    $sum += $k * $g[ $k - 1 ];
                }
            }
            my $numerator = ( $sum / ( $n - 2 ) ) - ( $tl / 2 );
            my $denominator = $tl * sqrt( 1 / ( 12 * ( $n - 2 ) ) );
            $self->_store_cache( $numerator / $denominator );
            return $numerator / $denominator;
        }

        # Big Float is available. We'll use it then
        $sum = Math::BigFloat->new(0);
        for ( my $i = 2 ; $i < $n ; $i++ ) {
            for ( my $k = 2 ; $k <= $i ; $k++ ) {
                $sum->badd( $k * $g[ $k - 1 ] );
            }
        }
        $sum->bdiv( $n - 2 );
        $sum->bsub( $tl / 2 );
        my $denominator = Math::BigFloat->new(1);
        $denominator->bdiv( 12 * ( $n - 2 ) );
        $denominator->bsqrt();
        $sum->bdiv( $denominator * $tl );
        
         # R seems to be unhappy about long numbers, so truncating
        $sum->accuracy(10);
        return $sum;
    }

=item calc_fiala_stemminess()

Calculates stemminess measure of Fiala and Sokal (1985).

 Type    : Calculation
 Title   : calc_fiala_stemminess
 Usage   : my $fiala_stemminess = 
           $tree->calc_fiala_stemminess;
 Function: Calculates stemminess measure 
           Fiala and Sokal (1985).
 Returns : FLOAT
 Args    : NONE
 Comments: As described in Fiala, K.L. and 
           R.R. Sokal, 1985. Factors 
           determining the accuracy of 
           cladogram estimation: evaluation 
           using computer simulation. 
           Evolution, 39: 609-622

=cut

    sub calc_fiala_stemminess {
        my $self      = shift;
        my @internals = @{ $self->get_internals };
        my $total     = 0;
        my $nnodes    = ( scalar @internals - 1 );
        foreach my $node (@internals) {
            if ( $node->get_parent ) {
                my $desclengths = $node->get_branch_length;
                my @children    = @{ $node->get_descendants };
                for my $child (@children) {
                    $desclengths += $child->get_branch_length;
                }
                $total += ( $node->get_branch_length / $desclengths );
            }
        }
        if ( $nnodes ) {
        	return $total /= $nnodes;
        }
        else {
        	$logger->error("too few nodes in tree: n-1=$nnodes");
        	return undef;
        }
    }

=item calc_rohlf_stemminess()

Calculates stemminess measure from Rohlf et al. (1990).

 Type    : Calculation
 Title   : calc_rohlf_stemminess
 Usage   : my $rohlf_stemminess = 
           $tree->calc_rohlf_stemminess;
 Function: Calculates stemminess measure 
           from Rohlf et al. (1990).
 Returns : FLOAT
 Args    : NONE
 Comments: As described in Rohlf, F.J., 
           W.S. Chang, R.R. Sokal, J. Kim, 
           1990. Accuracy of estimated 
           phylogenies: effects of tree 
           topology and evolutionary model. 
           Evolution, 44(6): 1671-1684

=cut

    sub calc_rohlf_stemminess {

        # invocant is a tree
        my $self = shift;
        throw ObjectMismatch => "This algorithm isn't generalized to
			deal with multifurcations" if $self->calc_resolution < 1;
        throw ObjectMismatch => "This algorithm requires branch lengths"
          unless $self->calc_tree_length;

        # all internal nodes in the tree
        my @internals = @{ $self->get_internals };

        # all terminal nodes in the tree
        my @terminals = @{ $self->get_terminals };

        # this will become the sum of all STni
        my $total = 0;

        # 1/(t-2), by which we multiply total
        my $one_over_t_minus_two = 1 / ( scalar @terminals - 2 );

        # iterate over all nodes, as per equation (1)
        for my $node (@internals) {

            # only process nodes that aren't the root
            if ( my $parent = $node->get_parent ) {

                # Wj->i is defined as "the length of the edge
                # (in time units) between HTU i (a hypothetical
                # taxonomic unit, i.e. an internal node) and
                # its ancestor j"
                my $Wj_i = $node->get_branch_length;

                # hj is defined as "the 'height' of HTU j (the
                # time of its origin, a known quantity since we
                # know the true tree in these simulations)".
                my $hj = $parent->calc_path_to_root;
                if ( !$hj ) {
                    next;
                }

                # as per equation (2) in Rohlf et al. (1990)
                $total += ( $Wj_i / $hj );
            }
        }

        # multiply by 1/(t-2) as per equation (1)
        return $one_over_t_minus_two * $total;
    }

=item calc_resolution()

Calculates tree resolution.

 Type    : Calculation
 Title   : calc_resolution
 Usage   : my $resolution = 
           $tree->calc_resolution;
 Function: Calculates the number 
           of internal nodes over the
           total number of internal nodes 
           on a fully bifurcating
           tree of the same size.
 Returns : FLOAT
 Args    : NONE

=cut

    sub calc_resolution {
        my $self = shift;
        my $res  = $self->calc_number_of_internals /
          ( $self->calc_number_of_terminals - 1 );
        return $res;
    }

=item calc_branching_times()

Calculates cumulative branching times.

 Type    : Calculation
 Title   : calc_branching_times
 Usage   : my $branching_times = 
           $tree->calc_branching_times;
 Function: Returns a two-dimensional array. 
           The first dimension consists of 
           the "records", so that in the 
           second dimension $AoA[$first][0] 
           contains the internal node references, 
           and $AoA[$first][1] the branching 
           time of the internal node. The 
           records are orderered from root to 
           tips by time from the origin.
 Returns : SCALAR[][] or FALSE
 Args    : NONE

=cut

    sub calc_branching_times {
        my $self = shift;
        my @branching_times;
        if ( !$self->is_ultrametric(0.01) ) {
            throw 'ObjectMismatch' =>
              'tree isn\'t ultrametric, results would be meaningless';
        }
        else {
            my @temp;
            my $seen_tip = 0;
            $self->visit_depth_first(
                '-pre' => sub {
                    my $node = shift;
                    if ( not $seen_tip or $node->is_internal ) {
                        my $bt = $node->get_branch_length;
                        if ( my $parent = $node->get_parent ) {
                            $bt += $parent->get_generic('bt');
                        }
                        $node->set_generic( 'bt' => $bt );
                        push @temp, [ $node, $bt ];
                        if ( $node->is_terminal ) {
                            $seen_tip++;
                        }
                    }
                }
            );
            @branching_times = sort { $a->[1] <=> $b->[1] } @temp;
        }
        return \@branching_times;
    }

=item calc_waiting_times()

Calculates intervals between splits.

 Type    : Calculation
 Title   : calc_waiting_times
 Usage   : my $waitings = 
           $tree->calc_waiting_times;
 Function: Returns a two-dimensional array. 
           The first dimension consists of 
           the "records", so that in the 
           second dimension $AoA[$first][0] 
           contains the internal node references, 
           and $AoA[$first][1] the waiting 
           time of the internal node. The 
           records are orderered from root to 
           tips by time from the origin.
 Returns : SCALAR[][] or FALSE
 Args    : NONE

=cut

    sub calc_waiting_times {
        my $self  = shift;
        my $times = $self->calc_branching_times;
        for ( my $i = $#{$times} ; $i > 0 ; $i-- ) {
            $times->[$i]->[1] -= $times->[ $i - 1 ]->[1];
        }
        return $times;
    }

=item calc_node_ages()

Calculates node ages.

 Type    : Calculation
 Title   : calc_node_ages
 Usage   : $tree->calc_node_ages;
 Function: Calculates the age of all the nodes in the tree (i.e. the distance
           from the tips) and assigns these to the 'age' slot, such that,
	   after calling this method, the age of any one node can be retrieved
	   by calling $node->get_generic('age');
 Returns : The invocant
 Args    : NONE
 Comments: This method computes, in a sense, the opposite of
           calc_branching_times: here, we compute the distance from the tips
	   (i.e. how long ago the split occurred), whereas calc_branching_times
	   calculates the distance from the root.

=cut

    sub calc_node_ages {
        my $self = shift;
        $self->visit_depth_first(
            '-post' => sub {
                my $node = shift;
                my $age  = 0;
                if ( my $child = $node->get_child(0) ) {
                    $age =
                      $child->get_generic('age') + $child->get_branch_length;
                }
                $node->set_generic( 'age' => $age );
            }
        );
        return $self;
    }

=item calc_ltt()

Calculates lineage-through-time data points.

 Type    : Calculation
 Title   : calc_ltt
 Usage   : my $ltt = $tree->calc_ltt;
 Function: Returns a two-dimensional array. 
           The first dimension consists of the 
           "records", so that in the second 
           dimension $AoA[$first][0] contains 
           the internal node references, and
           $AoA[$first][1] the branching time 
           of the internal node, and $AoA[$first][2] 
           the cumulative number of lineages over
           time. The records are orderered from 
           root to tips by time from the origin.
 Returns : SCALAR[][] or FALSE
 Args    : NONE

=cut

    sub calc_ltt {
        my $self = shift;
        if ( !$self->is_ultrametric(0.01) ) {
            throw 'ObjectMismatch' =>
              'tree isn\'t ultrametric, results are meaningless';
        }
        my $ltt      = ( $self->calc_branching_times );
        my $lineages = 1;
        for my $i ( 0 .. $#{$ltt} ) {
            $lineages += ( scalar @{ $ltt->[$i][0]->get_children } - 1 );
            $ltt->[$i][2] = $lineages;
        }
        return $ltt;
    }

=item calc_symdiff()

Calculates the symmetric difference metric between invocant and argument. This
metric is identical to the Robinson-Foulds tree comparison distance. See
L<http://dx.doi.org/10.1016/0025-5564(81)90043-2>

 Type    : Calculation
 Title   : calc_symdiff
 Usage   : my $symdiff = 
           $tree->calc_symdiff($other_tree);
 Function: Returns the symmetric difference 
           metric between $tree and $other_tree, 
           sensu Penny and Hendy, 1985.
 Returns : SCALAR
 Args    : A Bio::Phylo::Forest::Tree object,
           Optional second argument flags that results should be normalized
 Comments: Trees in comparison must span 
           the same set of terminal taxa
           or results are meaningless.

=cut

    sub calc_symdiff {
        my ( $tree, $other_tree, $normalize ) = @_;
        my $tuples  = $tree->_calc_branch_diffs($other_tree);
        my $symdiff = 0;
        #use Data::Dumper;
        #warn Dumper($tuples);
        for my $tuple ( @{$tuples} ) {
            $symdiff++ unless $tuple->[2];
        }
        return $normalize ? $symdiff / scalar(@{$tuples}) : $symdiff;
    }

=item calc_avtd()

Calculates the average taxonomic distinctiveness. See
Clarke KR, Warwick RM (1998) A taxonomic distinctness index and its statistical 
properties. J Appl Ecol 35:523-525
L<http://dx.doi.org/10.1046/j.1365-2664.1998.3540523.x>

 Type    : Calculation
 Title   : calc_avtd
 Usage   : my $avtd = $tree->calc_avtd;
 Function: Returns the average taxonomic distinctiveness
 Returns : SCALAR
 Args    : A Bio::Phylo::Forest::Tree object
 Comments: 

=cut

	sub calc_avtd {
		my $tree = shift;
		my @tips = @{ $tree->get_terminals };
		my $dist = 0;
		for my $i ( 0 .. $#tips - 1 ) {
			for my $j ( $i + 1 .. $#tips ) {
				$dist += $tips[$i]->calc_patristic_distance($tips[$j]);
			}
		}
		return $dist / scalar(@tips);
	}

=item calc_fp() 

Calculates the Fair Proportion value for each terminal.

 Type    : Calculation
 Title   : calc_fp
 Usage   : my $fp = $tree->calc_fp();
 Function: Returns the Fair Proportion 
           value for each terminal
 Returns : HASHREF
 Args    : NONE

=cut

    # code due to Aki Mimoto
    sub calc_fp {
        my $self = shift;

        # First establish how many children sit on each of the nodes
        my %weak_ref;
        my $terminals = $self->get_terminals;
        for my $terminal (@$terminals) {
            my $index = $terminal;
            do { $weak_ref{$index}++ } while ( $index = $index->get_parent );
        }

        # Then, assign each terminal a value
        my $fp = {};
        for my $terminal (@$terminals) {
            my $name = $terminal->get_name;
            my $fpi  = 0;
            do {
                $fpi +=
                  ( $terminal->get_branch_length || 0 ) / $weak_ref{$terminal};
            } while ( $terminal = $terminal->get_parent );
            $fp->{$name} = $fpi;
        }
        return $fp;
    }

=item calc_fp_mean() 

Calculates the mean Fair Proportion value over all terminals.

 Type    : Calculation
 Title   : calc_fp_mean
 Usage   : my $fp = $tree->calc_fp_mean();
 Function: Returns the mean Fair Proportion 
           value over all terminals
 Returns : FLOAT
 Args    : NONE

=cut
    
    sub calc_fp_mean {
    	my $self = shift;
    	my $fp = $self->calc_fp;
    	my @fp = values %{ $fp };
    	return sum(@fp)/scalar(@fp);
    }

=item calc_es() 

Calculates the Equal Splits value for each terminal

 Type    : Calculation
 Title   : calc_es
 Usage   : my $es = $tree->calc_es();
 Function: Returns the Equal Splits value for each terminal
 Returns : HASHREF
 Args    : NONE

=cut

    # code due to Aki Mimoto
    sub calc_es {
        my $self = shift;

        # First establish how many children sit on each of the nodes
        my $terminals = $self->get_terminals;
        my $es        = {};
        for my $terminal ( @{$terminals} ) {
            my $name    = $terminal->get_name;
            my $esi     = 0;
            my $divisor = 1;
            do {
                my $length   = $terminal->get_branch_length || 0;
                my $children = $terminal->get_children      || [];
                $divisor *= @$children || 1;
                $esi += $length / $divisor;
            } while ( $terminal = $terminal->get_parent );
            $es->{$name} = $esi;
        }
        return $es;
    }  

=item calc_es_mean()

Calculates the mean Equal Splits value over all terminals

 Type    : Calculation
 Title   : calc_es_mean
 Usage   : my $es = $tree->calc_es_mean();
 Function: Returns the Equal Splits value over all terminals
 Returns : FLOAT
 Args    : NONE

=cut

	sub calc_es_mean {
		my $self = shift;
		my $es = $self->calc_es;
		my @es = values %{ $es };
		return sum(@es)/scalar(@es);
	}

=item calc_pe()

Calculates the Pendant Edge value for each terminal.

 Type    : Calculation
 Title   : calc_pe
 Usage   : my $es = $tree->calc_pe();
 Function: Returns the Pendant Edge value for each terminal
 Returns : HASHREF
 Args    : NONE

=cut

    # code due to Aki Mimoto
    sub calc_pe {
        my $self = shift;
        my $terminals = $self->get_terminals or return {};
        my $pe =
          { map { $_->get_name => $_->get_branch_length } @{$terminals} };
        return $pe;
    }    

=item calc_pe_mean()

Calculates the mean Pendant Edge value over all terminals

 Type    : Calculation
 Title   : calc_pe_mean
 Usage   : my $es = $tree->calc_pe_mean();
 Function: Returns the mean Pendant Edge value over all terminals
 Returns : FLOAT
 Args    : NONE

=cut

	sub calc_pe_mean {
		my $self = shift;
		my $pe = $self->calc_pe;
		my @pe = values %{ $pe };
		return sum(@pe)/scalar(@pe);
	}

=item calc_shapley()

Calculates the Shapley value for each terminal.

 Type    : Calculation
 Title   : calc_shapley
 Usage   : my $es = $tree->calc_shapley();
 Function: Returns the Shapley value for each terminal
 Returns : HASHREF
 Args    : NONE

=cut

    # code due to Aki Mimoto
    sub calc_shapley {
        my $self = shift;

        # First find out how many tips are at the ends of each edge.
        my $terminals   = $self->get_terminals or return;    # nothing to see!
        my $edge_lookup = {};
        my $index       = $terminals->[0];

        # Iterate through the edges and find out which side each terminal reside
        _calc_shapley_traverse( $index, undef, $edge_lookup, 'root' );

        # At this point, it's possible to create the calculation matrix
        my $n = @$terminals;
        my @m;
        my $edges = [ keys %$edge_lookup ];
        for my $e ( 0 .. $#$edges ) {
            my $edge = $edges->[$e];
            my $el =
              $edge_lookup->{$edge};    # Lookup for terminals on one edge side
            my $v =
              keys %{ $el
                  ->{terminals} };  # Number of elements on one side of the edge
            for my $l ( 0 .. $#$terminals ) {
                my $terminal = $terminals->[$l];
                my $name     = $terminal->get_name;
                if ( $el->{terminals}{$name} ) {
                    $m[$l][$e] = ( $n - $v ) / ( $n * $v );
                }
                else {
                    $m[$l][$e] = $v / ( $n * ( $n - $v ) );
                }
            }
        }

        # Now we can calculate through the matrix
        my $shapley = {};
        for my $l ( 0 .. $#$terminals ) {
            my $terminal = $terminals->[$l];
            my $name     = $terminal->get_name;
            for my $e ( 0 .. $#$edges ) {
                my $edge = $edge_lookup->{ $edges->[$e] };
                $shapley->{$name} += $edge->{branch_length} * $m[$l][$e];
            }
        }
        return $shapley;
    }

    sub _calc_shapley_traverse {

        # This does a depth first traversal to assign the terminals
        # to the outgoing side of each branch.
        my ( $index, $previous, $edge_lookup, $direction ) = @_;
        return unless $index;
        $previous ||= '';

        # Is this element a root?
        my $is_root = !$index->get_parent;

        # Now assemble all the terminal datapoints and use the soft reference
        # to keep track of which end the terminals are attached
        my @core_terminals;
        if ( $previous and $index->is_terminal ) {
            push @core_terminals, $index->get_name;
        }
        my $parent = $index->get_parent || '';
        my @child_terminals;
        my $child_nodes = $index->get_children || [];
        for my $child (@$child_nodes) {
            next unless $child ne $previous;
            push @child_terminals,
              _calc_shapley_traverse( $child, $index, $edge_lookup, 'tip' );
        }
        my @parent_terminals;
        if ( $parent ne $previous ) {
            push @parent_terminals,
              _calc_shapley_traverse( $parent, $index, $edge_lookup, 'root' );
        }

# We're going to toss the root node and we need to merge the root's child branches
        unless ($is_root) {
            $edge_lookup->{$index} = {
                branch_length => $index->get_branch_length,
                terminals     => {
                    map { $_ => 1 } @core_terminals,
                    $direction eq 'root' ? @parent_terminals : @child_terminals
                }
            };
        }
        return ( @core_terminals, @child_terminals, @parent_terminals );
    }
    
=item calc_shapley_mean()

Calculates the mean Shapley value over all terminals

 Type    : Calculation
 Title   : calc_shapley_mean
 Usage   : my $es = $tree->calc_shapley_mean();
 Function: Returns the mean Shapley value over all terminals
 Returns : HASHREF
 Args    : NONE

=cut

	sub calc_shapley_mean {
		my $self = shift;
		my $sv = $self->calc_shapley;
		my @sv = values %{ $sv };
		return sum(@sv)/scalar(@sv);
	}

=back

=head2 VISITOR METHODS

The following methods are a - not entirely true-to-form - implementation of the Visitor
design pattern: the nodes in a tree are visited, and rather than having an object
operate on them, a set of code references is used. This can be used, for example, to
serialize a tree to a string format. To create a newick string without branch lengths
you would use something like this (there is a more powerful 'to_newick' method, so this
is just an example):

 $tree->visit_depth_first(
	'-pre_daughter'   => sub { print '('             },	
	'-post_daughter'  => sub { print ')'             },	
	'-in'             => sub { print shift->get_name },
	'-pre_sister'     => sub { print ','             },	
 );
 print ';';

=over

=item visit_depth_first()

Visits nodes depth first

 Type    : Visitor method
 Title   : visit_depth_first
 Usage   : $tree->visit_depth_first( -pre => sub{ ... }, -post => sub { ... } );
 Function: Visits nodes in a depth first traversal, executes subs
 Returns : $tree
  Args    : Optional handlers in the order in which they would be executed on an internal node:
			
			# first event handler, is executed when node is reached in recursion
			-pre            => sub { print "pre: ",            shift->get_name, "\n" },

			# is executed if node has a daughter, but before that daughter is processed
			-pre_daughter   => sub { print "pre_daughter: ",   shift->get_name, "\n" },
			
			# is executed if node has a daughter, after daughter has been processed	
			-post_daughter  => sub { print "post_daughter: ",  shift->get_name, "\n" },

			# is executed whether or not node has sisters, if it does have sisters
			# they're processed first	
			-in             => sub { print "in: ",             shift->get_name, "\n" },
			
			# is executed if node has a sister, before sister is processed
			-pre_sister     => sub { print "pre_sister: ",     shift->get_name, "\n" },	
			
			# is executed if node has a sister, after sister is processed
			-post_sister    => sub { print "post_sister: ",    shift->get_name, "\n" },							
			
			# is executed last			
			-post           => sub { print "post: ",           shift->get_name, "\n" },
			
			# specifies traversal order, default 'ltr' means first_daugher -> next_sister
			# traversal, alternate value 'rtl' means last_daughter -> previous_sister traversal
			-order          => 'ltr', # ltr = left-to-right, 'rtl' = right-to-left
 Comments: 

=cut

    sub visit_depth_first {
        my $self = shift;
        if ( my $root = $self->get_root ) {
        	$root->visit_depth_first(looks_like_hash @_);
        }
        return $self;
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
			
			# is executed whether or not node has sisters, if it does have sisters
			# they're processed first	
			-in             => sub { print "in: ",             shift->get_name, "\n" },			
			
			# is executed if node has a daughter, but before that daughter is processed
			-pre_daughter   => sub { print "pre_daughter: ",   shift->get_name, "\n" },
			
			# is executed if node has a daughter, after daughter has been processed	
			-post_daughter  => sub { print "post_daughter: ",  shift->get_name, "\n" },				
			
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
        $self->get_root->visit_breadth_first(%args);
        return $self;
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
        my ( $tree, $sub ) = @_;
        if ( my $root = $tree->get_root ) {
            $root->visit_level_order($sub);
        }
        else {
            throw 'BadArgs' => 'Tree has no root';
        }
        return $tree;
    }

=back

=head2 TREE MANIPULATION

=over

=item chronompl()

Modifies branch lengths using the mean path lengths method of
Britton et al. (2002). For more about this method, see:
L<http://dx.doi.org/10.1016/S1055-7903(02)00268-3>

 Type    : Tree manipulator
 Title   : chronompl
 Usage   : $tree->chronompl;
 Function: Makes tree ultrametric using MPL method
 Returns : The modified, now ultrametric invocant.
 Args    : NONE
 Comments: 

=cut

    sub chronompl {
        my $self = shift;
        $self->visit_depth_first(
            '-post' => sub {
                my $node = shift;
                my %paths;
                my $children = $node->get_children;
                for my $child ( @{$children} ) {
                    my $cp = $child->get_generic('paths');
                    my $bl = $child->get_branch_length;
                    for my $id ( keys %{$cp} ) {
                        $paths{$id} = $cp->{$id} + $bl;
                    }
                }
                if ( not scalar @{$children} ) {
                    $paths{ $node->get_id } = 0;
                }
                $node->set_generic( 'paths' => \%paths );
                my $total = 0;
                $total += $_ for values %paths;
                my $mean = $total / scalar keys %paths;
                $node->set_generic( 'age' => $mean );
            }
        );
        return $self->agetobl;
    }

=item grafenbl()

Computes and assigns branch lengths using Grafen's method, which makes
node ages proportional to clade size. For more about this method, see:
L<http://dx.doi.org/10.1098/rstb.1989.0106>

 Type    : Tree manipulator
 Title   : grafenbl
 Usage   : $tree->grafenbl;
 Function: Assigns branch lengths using Grafen's method
 Returns : The modified, now ultrametric invocant.
 Args    : Optional, a power ('rho') to which all node ages are raised
 Comments: 

=cut

    sub grafenbl {
        my ( $self, $rho ) = @_;
        my $total = 0;
        $self->visit_depth_first(
            '-post' => sub {
                my $node = shift;
                if ( $node->is_terminal ) {
                    $node->set_generic( 'adjntips' => 0 );
                    $node->set_generic( 'ntips'    => 1 );
                }
                else {
                    my $children = $node->get_children;
                    my $ntips    = 0;
                    for my $child ( @{$children} ) {
                        $ntips += $child->get_generic('ntips');
                    }
                    $node->set_generic( 'ntips'    => $ntips );
                    $node->set_generic( 'adjntips' => $ntips - 1 );
                    $total = $ntips if $node->is_root;
                }
            }
        );
        $self->visit(
            sub {
                my $node = shift;
                if ($total) {
                    my $age = $node->get_generic('adjntips') / $total;
                    if ($rho) {
                        $age = $age**$rho;
                    }
                    $node->set_generic( 'age' => $age );
                }
            }
        );
        return $self->agetobl;
    }

=item agetobl()

Converts node ages to branch lengths

 Type    : Tree manipulator
 Title   : agetobl
 Usage   : $tree->agetobl;
 Function: Converts node ages to branch lengths
 Returns : The modified invocant.
 Args    : NONE
 Comments: This method uses ages as assigned to the generic 'age' slot
           on the nodes in the trees. I.e. for each node in the tree,
	   $node->get_generic('age') must return a number

=cut

    sub agetobl {
        my $self = shift;
        for my $node ( @{ $self->get_entities } ) {
            if ( my $parent = $node->get_parent ) {
                my $mp = $node->get_generic('age') || 0;
                my $pmp = $parent->get_generic('age');
                $node->set_branch_length( $pmp - $mp );
            }
            else {
                $node->set_branch_length(0);
            }
        }
        return $self;
    }

=item rankprobbl()

Generates branch lengths by calculating the rank probabilities for each node and applying
the expected waiting times under a pure birth process to these ranks. Uses Stadler's 
RANKPROB algorithm as described in: 

B<Gernhard, T.> et al., 2006. Estimating the relative order of speciation 
or coalescence events on a given phylogeny. I<Evolutionary Bioinformatics Online>. 
B<2>:285. L<http://www.ncbi.nlm.nih.gov/pmc/articles/PMC2674681/>.

 Type    : Tree manipulator
 Title   : rankprobbl
 Usage   : $tree->rankprobbl;
 Function: Generates pure birth branch lengths
 Returns : The modified invocant.
 Args    : NONE
 Comments: Tree must be fully bifurcating

=cut

	sub rankprobbl {
		my $self = shift;
		my $root = $self->get_root;
		my $intervals = $root->calc_terminals;
		my @times;
		for my $i ( 1 .. $intervals ) {
			my $previous = $times[-1] || 0;
			push @times, $previous + ( 1 / $i );
		}
		my $total = $times[-1];
		for my $node ( @{ $self->get_internals } ) {
			my $rankprobs = $root->calc_rankprob($node);
			my @weighted_waiting_times;
			for my $i ( 1 .. $#{ $rankprobs } ) {
				push @weighted_waiting_times, $rankprobs->[$i] * $times[$i - 1];
			}
			my $age = $total - sum(@weighted_waiting_times);
			$node->set_generic( 'age' => $age );
		}
		$self->agetobl;
		$root->set_branch_length(1);
		return $self;
	}

=item ultrametricize()

Sets all root-to-tip path lengths equal.

 Type    : Tree manipulator
 Title   : ultrametricize
 Usage   : $tree->ultrametricize;
 Function: Sets all root-to-tip path 
           lengths equal by stretching
           all terminal branches to the 
           height of the tallest node.
 Returns : The modified invocant.
 Args    : NONE
 Comments: This method is analogous to 
           the 'ultrametricize' command
           in Mesquite, i.e. no rate smoothing 
           or anything like that happens, just 
           a lengthening of terminal branches.

=cut

    sub ultrametricize {
        my $tree    = shift;
        my $tallest = 0;
        foreach ( @{ $tree->get_terminals } ) {
            my $path_to_root = $_->calc_path_to_root;
            if ( $path_to_root > $tallest ) {
                $tallest = $path_to_root;
            }
        }
        foreach ( @{ $tree->get_terminals } ) {
            my $newbl =
              $_->get_branch_length + ( $tallest - $_->calc_path_to_root );
            $_->set_branch_length($newbl);
        }
        return $tree;
    }

=item scale()

Scales the tree to the specified height.

 Type    : Tree manipulator
 Title   : scale
 Usage   : $tree->scale($height);
 Function: Scales the tree to the 
           specified height.
 Returns : The modified invocant.
 Args    : $height = a numerical value 
           indicating root-to-tip path length.
 Comments: This method uses the 
           $tree->calc_tree_height method, and 
           so for additive trees the *average* 
           root-to-tip path length is scaled to
           $height (i.e. some nodes might be 
           taller than $height, others shorter).

=cut

    sub scale {
        my ( $tree, $target_height ) = @_;
        my $current_height = $tree->calc_tree_height;
        my $scaling_factor = $target_height / $current_height;
        foreach ( @{ $tree->get_entities } ) {
            my $bl = $_->get_branch_length;
            if ($bl) {
                my $new_branch_length = $bl * $scaling_factor;
                $_->set_branch_length($new_branch_length);
            }
        }
        return $tree;
    }

=item resolve()

Randomly breaks polytomies.

 Type    : Tree manipulator
 Title   : resolve
 Usage   : $tree->resolve;
 Function: Randomly breaks polytomies by inserting 
           additional internal nodes.
 Returns : The modified invocant.
 Args    : Optionally, when passed a true value (e.g. '1'), the newly created nodes
           will be unnamed, otherwise they will be named 'r1', 'r2', 'r3' and so on.
 Comments:

=cut

    sub resolve {
        my ( $tree, $anonymous ) = @_;
        for my $node ( @{ $tree->get_internals } ) {
            my @children = @{ $node->get_children };
            if ( scalar @children > 2 ) {
                my $i = 1;
                while ( scalar @children > 2 ) {
                	my %args = ( '-branch_length' => 0.00 );
                	$args{'-name'} = 'r' . $i++ unless $anonymous;
                    my $newnode = $fac->create_node(%args);
                    $tree->insert($newnode);
                    $newnode->set_parent($node);
                    for ( 1 .. 2 ) {
                        my $i = int( rand( scalar @children ) );
                        $children[$i]->set_parent($newnode);
                        splice @children, $i, 1;
                    }
                    push @children, $newnode;
                }
            }
        }
        return $tree;
    }
    
=item replicate()

Simulates tree(s) whose properties resemble that of the input tree in terms of birth/death
rate, depth, and size/depth distribution of genera. This uses the R environment for 
statistics to get a maximum likelihood estimate of birth/death rates on the source tree
and therefore requires the package L<Statistics::R> to be installed, and the R package
'ape'. The idea is that this is used on a species tree that is ultrametric. To get 
simulated genera whose sizes and root depths approximate those of the source tree, 
annotate genus nodes in the source tree, e.g. using $tree->generize, and provide the 
optional -genera flag of replicate() with a true value.

This method uses the function C<birthdeath> from the R package C<ape>. If you use this
method in a publication, you should therefore B<cite that package> (in addition to 
Bio::Phylo). More information about C<ape> can be found at L<http://ape-package.ird.fr/>.

 Type    : Tree manipulator
 Title   : replicate
 Usage   : my $forest = $tree->replicate;
 Function: Simulates tree(s) whose properties resemble that of the invocant tree
 Returns : Bio::Phylo::Forest
 Args    : Optional: -trees    => number of replicates, default is 1
           Optional: -rootedge => keep the birth/death root branch, then scale the tree(s)
           Optional: -genera   => approximate distribution of source genus sizes and depths 
           (do this by tagging internal nodes: $node->set_rank('genus'))
		   Optional: -seed     => a random integer seed for generating the birth/death tree
 Comments: Requires Statistics::R, and an R environment with 'ape' installed
           Expects to operate on an ultrametric tree

=cut    
    
    sub replicate {
    	my ( $self, %args ) = @_;
    	if ( looks_like_class('Statistics::R') and looks_like_class('Bio::Phylo::Generator') ) {

    		# get birthdeath parameters
    		$logger->info("going to estimate b/d");
    		my $newick = $self->to_newick;
    		my $R = Statistics::R->new;
			if ( my $seed = $args{'-seed'} ) {
				$R->run(qq[set.seed($seed)]);
			}
    		$R->run(q[library("ape")]);
    		$R->run(qq[phylo <- read.tree(text="$newick")]);
    		$R->run(q[bd <- birthdeath(phylo)]);
    		$R->run(q[ratio <- as.double(bd$para[1])]);
    		my $b_over_d = $R->get(q[ratio]);
    		$logger->info("b/d=$b_over_d");
    		
    		# generate the tree
    		$logger->info("going to simulate tree(s)");
    		my $gen = Bio::Phylo::Generator->new;
    		my $forest = $gen->gen_rand_birth_death(
    			'-trees'    => $args{'-trees'} || 1,
    			'-killrate' => $b_over_d,
    			'-tips'     => scalar(@{ $self->get_terminals }),
				);
    		
    		# invent tip labels
    		$forest->visit(sub{
    			my $t = shift;
    			my $n = 0;
    			for my $tip ( @{ $t->get_terminals } ) {
    				my $genus = $self->_make_taxon_name;
    				my $species = $self->_make_taxon_name;
    				if ( $genus =~ /(..)$/ ) {
    					my $suffix = $1;
    					$species =~ s/..$/$suffix/;
    					$tip->set_name( ucfirst($genus) . '_' . $species );
    				}
    			}
    		});
    		
    		# scale the trees
    		my $height = $self->calc_tree_height;
    		$forest->visit(sub{shift->get_root->set_branch_length(0)}) if not $args{'-rootedge'};
    		$forest->visit(sub{shift->scale($height)});
    		$logger->info("tree height is $height");
    		
    		# create similar genera, optionally
    		if ( $args{'-genera'} ) {
    			$logger->info("going to approximate genera");
    		
    			# iterate over trees
    			for my $replicate ( @{ $forest->get_entities } ) {
					
					# get distribution of source genus sizes and depths
					$logger->info("calculating source genus sizes and depths");
					my ( $counter, %genera ) = ( 0 );
					$self->visit(sub{
						my $node = shift;
						my $rank = $node->get_rank;
						if ( $rank ) {
							if ( $rank eq 'genus' ) {
								my $id     = $node->get_id;
								my $height = $height - $node->calc_path_to_root;
								my $size   = scalar(@{ $node->get_terminals });
								my $name   = $node->get_name || 'Genus' . ++$counter;
								$genera{$id} = {
									'name'   => $name,
									'size'   => $size,
									'height' => $height,
									'node'   => $node,
								};
							}
						}
					});
					
					# get distribution of target node sizes and depths
					$logger->info("calculating target genus sizes and depths");					
					my ( %node );
					$replicate->visit(sub{
						my $node   = shift;
						my $id     = $node->get_id;	
						my $height = $height - $node->calc_path_to_root;												
						my $size   = scalar(@{ $node->get_terminals });
						push @{ $node{$size} }, [ $node, $height, $id ];
					});
										
					# keep track of which members from the genera have already been assigned
					my %seen_labels;
					
					# start assigning genera, from big to small
					for my $genus ( sort { $genera{$b}->{'size'} <=> $genera{$a}->{'size'} } keys %genera ) {
						# get key for candidate set of nodes
						my $name = $genera{$genus}->{'name'} || "Genus${genus}";						
						my $size = $genera{$genus}->{'size'};
						my @labels = shuffle map { $_->get_name } @{ $genera{$genus}->{'node'}->get_terminals };
						
						# avoid assigning labels more than once when genera are nested
						@labels = grep { ! $seen_labels{$_} } @labels;
						$seen_labels{$_}++ for @labels;

						$logger->info("processing $name ($size tips)");
						SIZE: while( not $node{$size} ) { last SIZE if --$size <= 1 }
					
						# get target height
						if ( $node{$size} ) {
							$logger->info("found candidate(s) with $size tips");						
							my $h = $genera{$genus}->{'height'};
							my ($node) = map { $_->[0] } 
							            sort { abs($a->[1]-$h) <=> abs($b->[1]-$h) } 
							                @{ $node{$size} };
							
							# assign genus label to node and tips, remove all descendants 
							# (and self!) from list of candidates, as we can't nest genera
							my $sp = 0;							
							$node->set_name($name);
						
							for my $n ( $node, @{ $node->get_descendants } ) {
								$n->set_name($labels[$sp++]) if $n->is_terminal;
								for my $i ( 1 .. $size ) {
									if ( my $array = $node{$i} ) {
										my $id = $n->get_id;
										my @filtered = grep { $id != $_->[2] } @$array;
										@filtered ? $node{$i} = \@filtered : delete $node{$i};
									}
								}
							}
						}
						else {
							$logger->warn("exhausted candidate genera for $genus");
						}
					}
    			}
    		}
    		return $forest;
    	}
    }
    
    sub _make_taxon_name {
    	my %l = (
    		'v' => [ qw(a e i o u) ],
    		'c' => [ qw(qu cr ct p pr ps rs ld ph gl ch l sc v n m) ],
    	);
    	my @suffixes =qw(us os is as es);
    	my $length = 1 + int rand 2;
    	my @order = int rand 2 ? qw(v c) : qw(c v);
    	my ($l1) = shuffle(@{$l{$order[0]}});
    	my ($l2) = shuffle(@{$l{$order[1]}});
		my @name = ( $l1, $l2 );
    	for my $i ( 0 .. $length ) {
	    	($l1) = shuffle(@{$l{$order[0]}});
    		($l2) = shuffle(@{$l{$order[1]}});
    		push @name, $l1, $l2;
    	}
    	my $name = join '', @name;
    	$name =~ s/[aeiou]+$//;
    	my ($suffix) = shuffle(@suffixes);
    	return $name . $suffix;
    }

=item generize()

Identifies monophyletic genera by traversing the tree, taking the first word of the tip
names and finding the MRCA of each word. That MRCA is tagged as rank 'genus' and assigned
the name.

 Type    : Tree manipulator
 Title   : generize
 Usage   : $tree->generize(%args);
 Function: Identifies monophyletic genera
 Returns : Invocant
 Args    : Optional: -delim => the delimiter that separates the genus name from any 
                               following (sub)specific epithets. Default is a space ' '.
           Optional: -monotypic => if true, also tags monotypic genera
           Optional: -polypara  => if true, also tags poly/paraphyletic genera. Any 
                                   putative genera nested within the largest of the 
                                   entangled, poly/paraphyletic genera will be ignored.
 Comments:

=cut
    
    sub generize {
    	my ( $self, %args ) = @_;
    	my $delim = $args{'-delim'} || ' ';
    	
    	# bin by genus name
    	my %genera;
    	for my $tip ( @{ $self->get_terminals } ) {
    		my $binomial = $tip->get_name;
    		my ($genus) = split /$delim/, $binomial;
    		$genera{$genus} = [] if not $genera{$genus};
    		push @{ $genera{$genus} }, $tip;
    	}
    	
    	# identify and tag MRCAs
    	my %skip;
    	for my $genus ( sort { scalar(@{$genera{$b}}) <=> scalar(@{$genera{$a}}) } keys %genera ) {
    		next if $skip{$genus};
    		my $tips = $genera{$genus};
    		
    		# genus is monotypic
    		if ( scalar(@$tips) == 1 ) {
    			$logger->info("$genus is monotypic");
    			$tips->[0]->set_rank('genus') if $args{'-monotypic'};
    		}
    		else {
    		
    			# get the MRCA
				my ( $mrca, %seen );
				my @paths = map { @{ $_->get_ancestors } } @{ $tips };
				$seen{$_->get_id}++ for @paths;
				($mrca) = map { $_->[0] } 
				         sort { $b->[1] <=> $a->[1] } 
				          map { [ $_, $_->calc_path_to_root ] } 
				         grep { $seen{$_->get_id} == @$tips } @paths;
				
				# identify mono/poly/para
				my $clade_size = @{ $mrca->get_terminals };
				my $tip_count  = @{ $tips };
				if ( $clade_size == $tip_count ) {
					$logger->info("$genus is monophyletic");
					$mrca->set_rank('genus');
					$mrca->set_name($genus);
				}
				else {
										
					# we could now have nested, smaller genera inside this one
					$logger->info("$genus is non-monophyletic $clade_size != $tip_count");
					if ( $args{'-polypara'} ) {
						$logger->info("tagging non-monophyletic $genus anyway");
						$mrca->set_rank('genus');
						$mrca->set_name($genus);	
						my @names = map { $_->get_name } @{ $mrca->get_terminals };
						for my $name ( @names ) {
							$name =~ s/^(.+?)${delim}.+$/$1/;
							$skip{$name}++;
						}			
					}
				}
			}
        }
        return $self;
    }

=item prune_tips()

Prunes argument nodes from invocant.

 Type    : Tree manipulator
 Title   : prune_tips
 Usage   : $tree->prune_tips(\@taxa);
 Function: Prunes specified taxa from invocant.
 Returns : A pruned Bio::Phylo::Forest::Tree object.
 Args    : A reference to an array of taxon names, or a taxa block, or a
           reference to an array of taxon objects, or a reference to an
           array of node objects
 Comments:

=cut

    sub prune_tips {
        my ( $self, $tips ) = @_;
        my %prune = map { $_->get_id => 1 } @{ $self->_get_tip_objects($tips) };
        my @keep;
        for my $tip ( @{ $self->get_terminals } ) {
            if ( not $prune{$tip->get_id} ) {
                push @keep, $tip;
            }
        }
        return $self->keep_tips(\@keep);
    }

=item keep_tips()

Keeps argument nodes from invocant (i.e. prunes all others).

 Type    : Tree manipulator
 Title   : keep_tips
 Usage   : $tree->keep_tips(\@taxa);
 Function: Keeps specified taxa from invocant.
 Returns : The pruned Bio::Phylo::Forest::Tree object.
 Args    : Same as prune_tips, but with inverted meaning
 Comments:

=cut

    sub _get_tip_objects {
        my ( $self, $arg ) = @_;
        my @tips;

        # argument is a taxa block
        if ( blessed $arg ) {
            for my $taxon ( @{ $arg->get_entities } ) {
                my @nodes = @{ $taxon->get_nodes };
                for my $node ( @nodes ) {
                    push @tips, $node if $self->contains($node);
                }
            }
        }

        # arg is an array ref
        else {
            my $TAXON = _TAXON_;
            my $NODE  = _NODE_;
            for my $thing ( @{ $arg } ) {

                # thing is a taxon or node object
                if ( blessed $thing ) {
                    if ( $thing->_type == $TAXON ) {
                        my @nodes = @{ $thing->get_nodes };
                        for my $node ( @nodes ) {
                            push @tips, $node if $self->contains($node);
                        }
                    }
                    elsif ( $thing->_type == $NODE ) {
                        push @tips, $thing if $self->contains($thing);
                    }
                }

                # thing is a name
                else {
                    if ( my $tip = $self->get_by_name($thing) ) {
                        push @tips, $tip;
                    }
                }
            }
        }
        return \@tips;
    }

    sub keep_tips {
        my ( $self, $tip_names ) = @_;

        # get node objects for tips
        my @tips = @{ $self->_get_tip_objects($tip_names) };
        
        # identify nodes that are somewhere on the path from tip to root
        my %seen;
        for my $tip ( @tips ) {
            my $node = $tip;
            PARENT: while ( $node ) {
                my $id = $node->get_id;
                if ( not exists $seen{$id} ) {
                    $seen{$id} = 0;
                    $node = $node->get_parent;
                }
                else {
                    last PARENT;
                }
            }
        }

        # now do the pruning
        $self->visit_depth_first(
            '-post' => sub {
                # prune node
                my $n = shift;
                my $nid = $n->get_id;
                my $p = $n->get_parent;
                if ( not exists $seen{$nid} ) {
                    $p->delete($n) if $p;
                    $self->delete($n);
                    # record number of children lost by parent
                    if (defined $p) {
                       my $pid = $p->get_id;
                       if ( exists $seen{$pid} ) {
                          $seen{$pid}++;
                       }
                    }
                    return;
                }
                # remove nodes who lost children and are now down to a single one
                my @children = @{ $n->get_children };
                if ( (scalar @children == 1) && ($seen{$nid} > 0) ) {
                    my ($c) = @children;
                    my $bl  = $n->get_branch_length;
                    my $cbl = $c->get_branch_length;
                    $c->set_branch_length( $bl + $cbl ) if defined $cbl && defined $bl;
                    $self->delete($n);
                    $c->set_parent($p);
                    $p->delete($n) if $p;
                }
            }
        );
        return $self;
    }

=item negative_to_zero()

Converts negative branch lengths to zero.

 Type    : Tree manipulator
 Title   : negative_to_zero
 Usage   : $tree->negative_to_zero;
 Function: Converts negative branch 
           lengths to zero.
 Returns : The modified invocant.
 Args    : NONE
 Comments:

=cut

    sub negative_to_zero {
        my $tree = shift;
        foreach my $node ( @{ $tree->get_entities } ) {
            my $bl = $node->get_branch_length;
            if ( $bl && $bl < 0 ) {
                $node->set_branch_length(0);
            }
        }
        return $tree;
    }

=item ladderize()

Sorts nodes in ascending (or descending) order of number of children. Tips are
sorted alphabetically (ascending or descending) relative to their siblings.

 Type    : Tree manipulator
 Title   : ladderize
 Usage   : $tree->ladderize(1);
 Function: Sorts nodes
 Returns : The modified invocant.
 Args    : Optional, a true value to reverse the sort order

=cut

    sub ladderize {
        my ( $self, $right ) = @_;
        my %child_count;
        $self->visit_depth_first(
            '-post' => sub {
                my $node = shift;
                
                # record the number of descendants for the focal
                # node. because this is a post-order traversal
                # we have already counted the children of the 
                # children, recursively. bin nodes and tips in 
                # separate containers.
                my $id = $node->get_id;
                my @children = @{ $node->get_children };
                my $count = 1;
                my ( @tips, @nodes );
                for my $child (@children) {
                    $count += $child_count{ $child->get_id };
                    if ( $child->is_terminal ) {
                    	push @tips, $child;
                    }
                    else {
                    	push @nodes, $child;
                    }
                }
                $child_count{$id} = $count;
                
                # sort the immediate children. if these are 
                # tips we will sort alphabetically by name (so
                # that cherries are sorted predictably), otherwise
                # sort by descendant count
                my @sorted;
                
				if ($right) {
					@sorted = map { $_->[0] }
					  sort { $b->[1] <=> $a->[1] }
					  map { [ $_, $child_count{ $_->get_id } ] } @nodes;
					push @sorted, sort { $b->get_name cmp $a->get_name } @tips;
				}
				else {					
					@sorted = map { $_->[0] }
					  sort { $a->[1] <=> $b->[1] }
					  map { [ $_, $child_count{ $_->get_id } ] } @nodes;
					unshift @sorted, sort { $a->get_name cmp $b->get_name } @tips;
				}

				# apply the new sort order                
                for my $i ( 0 .. $#sorted ) {
                    $node->insert_at_index( $sorted[$i], $i );
                }
            }
        );
        return $self;
    }

=item sort_tips()

Sorts nodes in (an approximation of) the provided ordering. Given an array
reference of taxa, an array reference of name strings, or a taxa object, this
method attempts to order the tips in the same way. It does this by recursively
computing the rank for all internal nodes by taking the average rank of its
children. This results in the following orderings:

 (a,b,c,d,e,f); => $tree->sort_tips( [ qw(a c b f d e) ] ) => (a,c,b,f,d,e);
 
 (a,b,(c,d),e,f); => $tree->sort_tips( [ qw(a b e d c f) ] ); => (a,b,(e,(d,c)),f);
 
 ((a,b),((c,d),e),f); => $tree->sort_tips( [ qw(a e d c b f) ] ); => ((e,(d,c)),(a,b),f);

 Type    : Tree manipulator
 Title   : sort_tips
 Usage   : $tree->sort_tips($ordering);
 Function: Sorts nodes
 Returns : The modified invocant.
 Args    : Required, an array reference (or taxa object) whose ordering to match

=cut

    sub sort_tips {
        my ( $self, $taxa ) = @_;
        my @taxa =
          UNIVERSAL::can( $taxa, 'get_entities' )
          ? @{ $taxa->get_entities }
          : @{$taxa};
        my @names =
          map { UNIVERSAL::can( $_, 'get_name' ) ? $_->get_name : $_ } @taxa;
        my $i = 1;
        my %rank = map { $_ => $i++ } @names;
        $self->visit_depth_first(
            '-post' => sub {
                my $node     = shift;
                my @children = @{ $node->get_children };
                if (@children) {
                    my @ranks = map { $_->get_generic('rank') } @children;
                    my $sum   = sum @ranks;
                    my $mean  = $sum / scalar(@ranks);
                    $node->set_generic( 'rank' => $mean );
                    $node->clear;
                    $node->insert(
                        sort {
                            $a->get_generic('rank') <=> $b->get_generic('rank')
                          } @children
                    );
                }
                else {
                    $node->set_generic( 'rank' => $rank{ $node->get_name } );
                }
            }
        );
        return $self->_analyze;
    }

=item exponentiate()

Raises branch lengths to argument.

 Type    : Tree manipulator
 Title   : exponentiate
 Usage   : $tree->exponentiate($power);
 Function: Raises branch lengths to $power.
 Returns : The modified invocant.
 Args    : A $power in any of perl's number formats.

=cut

    sub exponentiate {
        my ( $tree, $power ) = @_;
        if ( !looks_like_number $power ) {
            throw 'BadNumber' => "Power \"$power\" is a bad number";
        }
        else {
            foreach my $node ( @{ $tree->get_entities } ) {
                my $bl = $node->get_branch_length;
                $node->set_branch_length( $bl**$power );
            }
        }
        return $tree;
    }

=item multiply()

Multiples branch lengths by argument.

 Type    : Tree manipulator
 Title   : multiply
 Usage   : $tree->multiply($num);
 Function: Multiplies branch lengths by $num.
 Returns : The modified invocant.
 Args    : A $number in any of perl's number formats.

=cut
    
    sub multiply {
    	my ( $tree, $num ) = @_;
    	if ( !looks_like_number $num ) {
    		throw 'BadNumber' => "Number '$num' is a bad number";
    	}
    	$tree->visit(sub{
    		my $node = shift;
    		my $length = $node->get_branch_length;
    		if ( $length ) {
    			$node->set_branch_length( $length * $num );
    		}
    	});
    	return $tree;
    }

=item log_transform()

Log argument base transform branch lengths.

 Type    : Tree manipulator
 Title   : log_transform
 Usage   : $tree->log_transform($base);
 Function: Log $base transforms branch lengths.
 Returns : The modified invocant.
 Args    : A $base in any of perl's number formats.

=cut

    sub log_transform {
        my ( $tree, $base ) = @_;
        if ( !looks_like_number $base ) {
            throw 'BadNumber' => "Base \"$base\" is a bad number";
        }
        else {
            foreach my $node ( @{ $tree->get_entities } ) {
                my $bl = $node->get_branch_length;
                my $newbl;
                eval { $newbl = ( log $bl ) / ( log $base ); };
                if ($@) {
                    throw 'OutOfBounds' =>
                      "Invalid input for log transform: $@";
                }
                else {
                    $node->set_branch_length($newbl);
                }
            }
        }
        return $tree;
    }

=item remove_unbranched_internals()

Collapses internal nodes with fewer than 2 children.

 Type    : Tree manipulator
 Title   : remove_unbranched_internals
 Usage   : $tree->remove_unbranched_internals;
 Function: Collapses internal nodes 
           with fewer than 2 children.
 Returns : The modified invocant.
 Args    : NONE
 Comments:

=cut

    sub remove_unbranched_internals {
        my $self = shift;
        my @delete;
        $self->visit_depth_first(
            '-post' => sub {
                my $node = shift;
                my @children = @{ $node->get_children };
                
                # the node is interior, now need to check for each child
                # if it's interior as well
                if ( @children ) {
                
                	# special case for the root with unbranched child
                	if ( $node->is_root and 1 == @children ) {
                		my ($child) = @children;
						for my $gchild ( @{ $child->get_children } ) {
					
							# compute the new branch length for $gchild
							my $clength = $child->get_branch_length;
							my $glength = $gchild->get_branch_length;
							my $length = $clength if defined $clength;
							$length += $glength if defined $glength;
							$gchild->set_branch_length($length) if defined $length;
							
							# connect grandchild to root
							$gchild->set_parent($node);
							$node->delete($child);
					
							# will delete these nodes from the tree array
							# after the recursion
							push @delete, $child;						
						}              		
                	}
                	else {
                    
						# iterate over children 
						for my $child ( @children ) {
							my $child_name = $child->get_name;
							my @grandchildren = @{ $child->get_children };
						
							# $child is an unbranched internal, so $grandchildren[0]
							# needs to be connected to $node
							if ( 1 == scalar @grandchildren ) {
								my $gchild = $grandchildren[0];
							
								# compute the new branch length for $gchild
								my $clength = $child->get_branch_length;
								my $glength = $gchild->get_branch_length;
								my $length = $clength if defined $clength;
								$length += $glength if defined $glength;
								$gchild->set_branch_length($length) if defined $length;
								
								$gchild->set_parent($node);
								$node->delete($child);
							
								# will delete these nodes from the tree array
								# after the recursion
								push @delete, $child;						
							}
						}
                    }				
                }
            }
        );
        $self->delete($_) for @delete;
        return $self;
    }

=item remove_orphans()

Removes all unconnected nodes.

 Type    : Tree manipulator
 Title   : remove_orphans
 Usage   : $tree->remove_orphans;
 Function: Removes all unconnected nodes
 Returns : The modified invocant.
 Args    : NONE
 Comments:

=cut

    sub remove_orphans {
    	my $self = shift;
    	
    	# collect all nodes that are topologically connected
    	my %seen;
    	$self->visit_depth_first(
    		'-pre' => sub {
    			$seen{ shift->get_id }++;
    		}
    	);
    	
    	# collect all nodes
    	my @delete;
    	$self->visit(sub {
    		my $node = shift;
    		push @delete, $node if not $seen{$node->get_id};
    	});
    	$self->delete($_) for @delete;
    	
    	# notify user
    	if ( scalar @delete ) {
    		$logger->warn("deleted ".scalar(@delete)." orphaned nodes");
    	}
    	
    	return $self;
    }

=item deroot()

Collapses one of the children of a basal bifurcation

 Type    : Tree manipulator
 Title   : deroot
 Usage   : $tree->deroot;
 Function: Removes root
 Returns : The modified invocant.
 Args    : Optional: node to collapse
 Comments:

=cut

    sub deroot {
        my ($self,$collapsible) = @_;
        my $root = $self->get_root;
        my @children = @{ $root->get_children };
        if ( scalar @children < 3 ) {
        	if ( not $collapsible) {
            	($collapsible) = grep { $_->is_internal } @children;
            }
            $collapsible->collapse;
            return $self;
        }
        else {
            return $self;
        }
    }

=back

=head2 UTILITY METHODS

=over

=item clone()

Clones invocant.

 Type    : Utility method
 Title   : clone
 Usage   : my $clone = $object->clone;
 Function: Creates a copy of the invocant object.
 Returns : A copy of the invocant.
 Args    : Optional: a hash of code references to 
           override reflection-based getter/setter copying

           my $clone = $object->clone(  
               'set_forest' => sub {
                   my ( $self, $clone ) = @_;
                   for my $forest ( @{ $self->get_forests } ) {
                       $clone->set_forest( $forest );
                   }
               },
               'set_matrix' => sub {
                   my ( $self, $clone ) = @_;
                   for my $matrix ( @{ $self->get_matrices } ) {
                       $clone->set_matrix( $matrix );
                   }
           );

 Comments: Cloning is currently experimental, use with caution.
           It works on the assumption that the output of get_foo
           called on the invocant is to be provided as argument
           to set_foo on the clone - such as 
           $clone->set_name( $self->get_name ). Sometimes this 
           doesn't work, for example where this symmetry doesn't
           exist, or where the return value of get_foo isn't valid
           input for set_foo. If such a copy fails, a warning is 
           emitted. To make sure all relevant attributes are copied
           into the clone, additional code references can be 
           provided, as in the example above. Typically, this is
           done by overrides of this method in child classes.

=cut

    sub clone {
        my $self = shift;
        $logger->info("cloning $self");
        my %subs = @_;

        # override, because we'll handle insert
        $subs{'set_root'}      = sub { };
        $subs{'set_root_node'} = sub { };

        # we'll clone node objects, so no raw copying
        $subs{'insert'} = sub {
            my ( $self, $clone ) = @_;
            my %clone_of;
            for my $node ( @{ $self->get_entities } ) {
                my $cloned_node = $node->clone;
                $clone_of{ $node->get_id } = $cloned_node;
                $clone->insert($cloned_node);
            }
            for my $node ( @{ $self->get_entities } ) {
                my $cloned_node = $clone_of{ $node->get_id };
                if ( my $parent = $node->get_parent ) {
                    my $cloned_parent_node = $clone_of{ $parent->get_id };
                    $cloned_node->set_parent($cloned_parent_node);
                }
            }
        };
        return $self->SUPER::clone(%subs);
    }

=back

=head2 SERIALIZERS

=over

=item to_nexus()

Serializes invocant to nexus string.

 Type    : Stringifier
 Title   : to_nexus
 Usage   : my $string = $tree->to_nexus;
 Function: Turns the invocant tree object 
           into a nexus string
 Returns : SCALAR
 Args    : Any arguments that can be passed to Bio::Phylo::Forest::to_nexus

=cut

    sub to_nexus {
        my $self   = shift;
        my $forest = $fac->create_forest;
        $forest->insert($self);
        return $forest->to_nexus(@_);
    }

=item to_newick()

Serializes invocant to newick string.

 Type    : Stringifier
 Title   : to_newick
 Usage   : my $string = $tree->to_newick;
 Function: Turns the invocant tree object 
           into a newick string
 Returns : SCALAR
 Args    : NONE

=cut

    sub to_newick {
        my $self   = shift;
        my %args   = @_;
        my $newick = unparse( '-format' => 'newick', '-phylo' => $self, %args );
        return $newick;
    }

=item to_xml()

Serializes invocant to xml.

 Type    : Serializer
 Title   : to_xml
 Usage   : my $xml = $obj->to_xml;
 Function: Turns the invocant object into an XML string.
 Returns : SCALAR
 Args    : NONE

=cut

    sub to_xml {
        my $self     = shift;
        my $xsi_type = 'nex:IntTree';
        for my $node ( @{ $self->get_entities } ) {
            my $length = $node->get_branch_length;
            if ( defined $length and $length !~ /^[+-]?\d+$/ ) {
                $xsi_type = 'nex:FloatTree';
            }
        }
        $self->set_attributes( 'xsi:type' => $xsi_type );
        my $xml = $self->get_xml_tag;
        if ( my $root = $self->get_root ) {
            $xml .= $root->to_xml;
        }
        $xml .= $self->sets_to_xml . sprintf('</%s>', $self->get_tag);
        return $xml;
    }

=item to_svg()

Serializes invocant to SVG.

 Type    : Serializer
 Title   : to_svg
 Usage   : my $svg = $obj->to_svg;
 Function: Turns the invocant object into an SVG string.
 Returns : SCALAR
 Args    : Same args as the Bio::Phylo::Treedrawer constructor
 Notes   : This will only work if you have the SVG module
           from CPAN installed on your system.

=cut

    sub to_svg {
        my $self   = shift;
        my $drawer = $fac->create_drawer(@_);
        $drawer->set_tree($self);
        return $drawer->draw;
    }

=item to_dom()

 Type    : Serializer
 Title   : to_dom
 Usage   : $tree->to_dom($dom)
 Function: Generates a DOM subtree from the invocant
           and its contained objects
 Returns : an Element object
 Args    : DOM factory object

=cut

    sub to_dom {
        my ( $self, $dom ) = @_;
        $dom ||= $Bio::Phylo::NeXML::DOM::DOM;
        unless ( looks_like_object $dom, _DOMCREATOR_ ) {
            throw 'BadArgs' => 'DOM factory object not provided';
        }
        my $xsi_type = 'nex:IntTree';
        for my $node ( @{ $self->get_entities } ) {
            my $length = $node->get_branch_length;
            if ( defined $length and $length !~ /^[+-]?\d+$/ ) {
                $xsi_type = 'nex:FloatTree';
            }
        }
        $self->set_attributes( 'xsi:type' => $xsi_type );
        my $elt = $self->get_dom_elt($dom);
        if ( my $root = $self->get_root ) {
            $elt->set_child($_) for $root->to_dom($dom);
        }
        return $elt;
    }

=begin comment

 Type    : Internal method
 Title   : _consolidate
 Usage   : $tree->_consolidate;
 Function: Does pre-order traversal, only keeps
           nodes seen during traversal in tree,
           in order of traversal
 Returns :
 Args    :

=end comment

=cut

    sub _consolidate {
        my $self = shift;
        my @nodes;
        $self->visit_depth_first( '-pre' => sub { push @nodes, shift } );
        $self->clear;
        $self->insert(@nodes);
    }

=begin comment

 Type    : Internal method
 Title   : _container
 Usage   : $tree->_container;
 Function:
 Returns : CONSTANT
 Args    :

=end comment

=cut

    sub _container { $CONTAINER_CONSTANT }

=begin comment

 Type    : Internal method
 Title   : _type
 Usage   : $tree->_type;
 Function:
 Returns : CONSTANT
 Args    :

=end comment

=cut

    sub _type { $TYPE_CONSTANT }
    sub _tag  { 'tree' }

=back

=cut

    # podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::Listable>

The L<Bio::Phylo::Forest::Tree|Bio::Phylo::Forest::Tree> object inherits from
the L<Bio::Phylo::Listable|Bio::Phylo::Listable> object, so the methods defined
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
__DATA__
sub get_nodes {
	my $self = shift;
	my $order = 'depth';
	my @nodes;
	if ( @_ ) {
		my %args = @_;
		if ( $args{'-order'} and $args{'-order'} =~ m/^b/ ) {
			$order = 'breadth';
		}
	}
	if ( my $root = $self->get_root ) {	
        if ( $order eq 'depth' ) {      
            $root->visit_depth_first(
                -pre => sub { push @nodes, shift }
            );
        }
        else {
            $root->visit_level_order( sub { push @nodes, shift } ); # XXX bioperl is wrong
        }
	}
	return @nodes;
}

sub set_root {
	my ( $self, $node ) = @_;
	my @nodes = ($node);
	if ( my $desc = $node->get_descendants ) {
		push @nodes, @{ $desc };
	}
	$self->clear;
	$self->insert(@nodes);
	return $node;
}

*set_root_node = \&set_root;

*as_string = \&to_newick;

sub get_root_node{ shift->get_root }

sub number_nodes { shift->calc_number_of_nodes }

sub total_branch_length { shift->calc_tree_length }

sub height {
	my $self = shift;
	my $nodect =  $self->calc_number_of_nodes;
	return 0 if( ! $nodect ); 
	return log($nodect) / log(2);
}

sub id {
	my $self = shift;
	if ( @_ ) {
		$self->set_name(shift);
	}
	return $self->get_name;
}

sub score {
	my $self = shift;
	if ( @_ ) {
		$self->set_score(shift);
	}
	return $self->get_score;
}

sub get_leaf_nodes {
	my $self = shift;
	my $tips = $self->get_terminals;
	if ( $tips ) {
		return @{ $tips };
	}
	return;
}

sub _parse_newick {
	my $self = shift;
	my $newick = join ('', @{ $_[0] } ) . ';';
	my $forest = Bio::Phylo::IO::parse( '-format' => 'newick', '-string' => $newick );
	my $tree = $forest->first;
	my @nodes = @{ $tree->get_entities };
	for my $node ( @nodes ) {
		$self->insert($node);
		$tree->delete($node);
	}
	$tree->DESTROY;
	$forest->DESTROY;
}

sub find_node {
   my $self = shift;
   if( ! @_ ) { 
       $logger->warn("Must request a either a string or field and string when searching");
   }
   my ( $field, $value );
   if ( @_ == 1 ) {
        ( $field, $value ) = ( 'id', shift );
   }
   elsif ( @_ == 2 ) {
        ( $field, $value ) = @_;
        $field =~ s/^-//;
   }
   my @nodes;
   $self->visit(
        sub {
            my $node = shift;
            push @nodes, $node if $node->$field and $node->$field eq $value;
        }
   );
   if ( wantarray) { 
       return @nodes;
   } 
   else { 
       if( @nodes > 1 ) { 
	        $logger->warn("More than 1 node found but caller requested scalar, only returning first node");
       }
       return shift @nodes;
   }   
}

sub verbose {
    my ( $self, $level ) = @_;
    $level = 0 if $level < 0;
    $self->VERBOSE( -level => $level );
}

sub reroot {
    my ( $self, $node ) = @_;
    my $id = $node->get_id;
    my $new_root = $node->set_root_below;
    if ( $new_root ) {
        my @children = grep { $_->get_id != $id } @{ $new_root->get_children };
        $node->set_child($_) for @children;
        return 1;    
    }
    else {
        return 0;
    }
}

sub remove_Node {
    my ( $self, $node ) = @_;
    if ( not ref $node ) {
        ($node) = grep { $_->get_name eq $node } @{ $self->get_entities };
    }
    if ( $node->is_terminal ) {
        $node->get_parent->prune_child( $node );
    }
    else {
        $node->collapse;
    }
    $self->delete($node);
}

sub splice {
    my ( $self, @args ) = @_;
    if ( ref($args[0]) ) {
        $_->collapse for @args;
    }
    else {
        my %args = @args;
        my ( @keep, @remove );
        for my $key ( keys %args ) {
            if ( $key =~ /^-keep_(.+)$/ ) {
                my $field = $1;
                my %val;
                if ( ref $args{$key} ) {
                    %val = map { $_ => 1 } @{ $args{$key} };
                }
                else {
                    %val = ( $args{$key} => 1 );
                }
                push @keep, grep { $val{ $_->$field } } @{ $self->get_entities };
            }
            elsif ( $key =~ /^-remove_(.+)$/ ) {
                my $field = $1;
                my %val;
                if ( ref $args{$key} ) {
                    %val = map { $_ => 1 } @{ $args{$key} };
                }
                else {
                    %val = ( $args{$key} => 1 );
                }
                push @remove, grep { $val{ $_->$field } } @{ $self->get_entities };           
            }
        }
        my @netto;
        REMOVE: for my $remove ( @remove ) {
            for my $keep ( @keep ) {
                next REMOVE if $remove->get_id == $keep->get_id;
            }
            push @netto, $remove;
        }
        my @names = map { $_->id } @netto;
        my @keep_names = map { $_->id } @keep;
        if ( @names ) {
            $self->prune_tips(\@names);
        }
        elsif ( @keep_names ) {
            $self->keep_tips( \@keep_names );
        }
    }
}

sub move_id_to_bootstrap {
    my $self = shift;
    $self->visit( 
        sub { 
            my $node = shift; 
            $node->bootstrap( $node->id ) if defined $node->id;
            $node->id("");
        } 
    );
}
