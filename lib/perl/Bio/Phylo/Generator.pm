package Bio::Phylo::Generator;
use strict;
use warnings;
use Bio::Phylo::Util::CONSTANT 'looks_like_hash';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::Logger;
use Bio::Phylo::Util::Dependency 'Math::Random';
use Bio::Phylo::Factory;
Math::Random->import(qw'random_exponential random_uniform');
{
    my $logger  = Bio::Phylo::Util::Logger->new;
    my $factory = Bio::Phylo::Factory->new;

=head1 NAME

Bio::Phylo::Generator - Generator of tree topologies

=head1 SYNOPSIS

 use Bio::Phylo::Factory;
 my $fac = Bio::Phylo::Factory->new;
 my $gen = $fac->create_generator;
 my $trees = $gen->gen_rand_pure_birth( 
     '-tips'  => 10, 
     '-model' => 'yule',
     '-trees' => 10,
 );

 # prints 'Bio::Phylo::Forest'
 print ref $trees;

=head1 DESCRIPTION

The generator module is used to simulate trees under various models.

=head1 METHODS

=head2 CONSTRUCTOR

=over

=item new()

Generator constructor.

 Type    : Constructor
 Title   : new
 Usage   : my $gen = Bio::Phylo::Generator->new;
 Function: Initializes a Bio::Phylo::Generator object.
 Returns : A Bio::Phylo::Generator object.
 Args    : NONE

=cut

    sub new {

        # could be child class
        my $class = shift;

        # notify user
        $logger->info("constructor called for '$class'");

        # the object turns out to be stateless
        my $self = bless \$class, $class;
        return $self;
    }

=back

=head2 GENERATOR

=over

=item gen_rand_pure_birth()

This method generates a Bio::Phylo::Forest 
object populated with Yule/Hey trees.

 Type    : Generator
 Title   : gen_rand_pure_birth
 Usage   : my $trees = $gen->gen_rand_pure_birth(
               '-tips'  => 10, 
               '-model' => 'yule',
               '-trees' => 10,
           );
 Function: Generates markov tree shapes, 
           with branch lengths sampled 
           from a user defined model of 
           clade growth, for a user defined
           number of tips.
 Returns : A Bio::Phylo::Forest object.
 Args    : -tips  => number of terminal nodes (default: 10),
           -model => either 'yule' or 'hey',
           -trees => number of trees to generate (default: 10)
	   Optional: -factory => a Bio::Phylo::Factory object

=cut

    sub _yule_rand_bl {
        my $i = shift;
        return random_exponential( 1, 1 / ( $i + 1 ) );
    }

    sub _hey_rand_bl {
        my $i = shift;
        random_exponential( 1, ( 1 / ( $i * ( $i + 1 ) ) ) );
    }

    sub _make_split {
        my ( $parent, $length, $fac, $nodes ) = @_;
        my @tips;
        for ( 1 .. 2 ) {
            my $node = $fac->create_node;
            $node->set_branch_length($length);
            $node->set_parent($parent);
            $nodes->{ $node->get_id } = $node;
            push @tips, $node;
        }
        return @tips;
    }

    sub gen_rand_pure_birth {
        my $random  = shift;
        my %options = looks_like_hash @_;
        my $model   = $options{'-model'};
        if ( $model =~ m/yule/i ) {
            return $random->_gen_pure_birth(
                '-blgen' => \&_yule_rand_bl,
                @_,
            );
        }
        elsif ( $model =~ m/hey/i ) {
            return $random->_gen_pure_birth(
                '-blgen' => \&_hey_rand_bl,
                @_,
            );
        }
        else {
            throw 'BadFormat' => "model '$model' not implemented";
        }
    }

    sub _gen_pure_birth {
        my $random   = shift;
        my %options  = looks_like_hash @_;
        my $factory  = $options{'-factory'} || $factory;
        my $blgen    = $options{'-blgen'};
        my $killrate = $options{'-killrate'} || 0;
        my $ntips    = $options{'-tips'} || 10;
        my $ntrees   = $options{'-trees'} || 10;
        my $forest   = $factory->create_forest;
        for ( 0 .. ( $ntrees - 1 ) ) {

            # instantiate root node
            my $root = $factory->create_node;
            $root->set_branch_length(0);
            my %nodes = ( $root->get_id => $root );

            # make the first split, insert new tips in @tips, from
            # which we will draw (without replacement) a new tip
            # to split until we've reached target number
            push my @tips, _make_split( $root, $blgen->(1), $factory, \%nodes );

            # start growing the tree
            my $i = 2;
            my @extinct;
            while (1) {
                if ( rand(1) < $killrate ) {
                    my $extinct_index = int rand scalar @tips;
                    my $extinct = splice @tips, $extinct_index, 1;
                    push @extinct, $extinct;
                    delete $nodes{ $extinct->get_id };
                }

                # obtain candidate parent of current split
                my $parent;
                ( $parent, @tips ) = _fetch_equiprobable(@tips);

                # generate branch length
                my $bl = $blgen->( $i++ );

                # stretch all remaining tips to the present
                for my $tip (@tips) {
                    my $oldbl = $tip->get_branch_length;
                    $tip->set_branch_length( $oldbl + $bl );
                }

                # add new nodes to tips array
                push @tips, _make_split( $parent, $bl, $factory, \%nodes );
                last if scalar @tips >= $ntips;
            }
            my $tree = $factory->create_tree;
            $tree->insert(
                map  { $_->[0] }
                sort { $a->[1] <=> $b->[1] }
                map  { [ $_, $_->get_id ] } values %nodes
            );
            $tree->prune_tips( \@extinct );
            $tree->_analyze;
            $forest->insert($tree);
        }
        return $forest;
    }

=item gen_rand_birth_death()

This method generates a Bio::Phylo::Forest 
object populated under a birth/death model

 Type    : Generator
 Title   : gen_rand_birth_death
 Usage   : my $trees = $gen->gen_rand_birth_death(
               '-tips'     => 10, 
               '-killrate' => 0.2,
               '-trees'    => 10,
           );
 Function: Generates trees where any growing lineage is equally
           likely to split at any one time, and is equally likely
	   to go extinct at '-killrate'
 Returns : A Bio::Phylo::Forest object.
 Args    : -tips  => number of terminal nodes (default: 10),
           -killrate => extinction over speciation rate (default: 0.2)
           -trees => number of trees to generate (default: 10)
	   Optional: -factory => a Bio::Phylo::Factory object
 Comments: Past extinction events are retained as unbranched internal
           nodes in the produced trees.

=cut

    sub gen_rand_birth_death {
        my $random  = shift;
        my %options = looks_like_hash @_;
        return $random->_gen_pure_birth(
            '-blgen'    => \&_yule_rand_bl,
            '-killrate' => $options{'-killrate'} || 0.2,
            @_,
        );
    }

=item gen_exp_pure_birth()

This method generates a Bio::Phylo::Forest object 
populated with Yule/Hey trees whose branch lengths 
are proportional to the expected waiting times (i.e. 
not sampled from a distribution).

 Type    : Generator
 Title   : gen_exp_pure_birth
 Usage   : my $trees = $gen->gen_exp_pure_birth(
               '-tips'  => 10, 
               '-model' => 'yule',
               '-trees' => 10,
           );
 Function: Generates markov tree shapes, 
           with branch lengths following 
           the expectation under a user 
           defined model of clade growth, 
           for a user defined number of tips.
 Returns : A Bio::Phylo::Forest object.
 Args    : -tips  => number of terminal nodes (default: 10),
           -model => either 'yule' or 'hey'
           -trees => number of trees to generate (default: 10)
	   Optional: -factory => a Bio::Phylo::Factory object

=cut

    sub _yule_exp_bl {
        my $i = shift;
        return 1 / ( $i + 1 );
    }

    sub _hey_exp_bl {
        my $i = shift;
        return 1 / ( $i * ( $i + 1 ) );
    }

    sub gen_exp_pure_birth {
        my $random  = shift;
        my %options = looks_like_hash @_;
        my $model   = $options{'-model'};
        if ( $model =~ m/yule/i ) {
            return $random->_gen_pure_birth(
                '-blgen' => \&_yule_exp_bl,
                @_,
            );
        }
        elsif ( $model =~ m/hey/i ) {
            return $random->_gen_pure_birth(
                '-blgen' => \&_hey_exp_bl,
                @_,
            );
        }
        else {
            throw 'BadFormat' => "model '$model' not implemented";
        }
    }

=item gen_coalescent()

This method generates coalescent trees for a given effective population size
(popsize) and number of alleles (tips) such that the probability of coalescence
in the previous generation for any pair of alleles is 1 / ( 2 * popsize ).

 Type    : Generator
 Title   : gen_coalescent
 Usage   : my $trees = $gen->gen_coalescent(
               '-tips'    => 10, 
               '-popsize' => 100,
               '-trees'   => 10,
           );
 Function: Generates coalescent trees.
 Returns : A Bio::Phylo::Forest object.
 Args    : -tips    => number of terminal nodes (default: 10)
           -popsize => effective population size (default: 100)
           -trees   => number of trees to generate (default: 10)
	   Optional: -factory => a Bio::Phylo::Factory object

=cut

    sub gen_coalescent {
        my $self    = shift;
        my %args    = looks_like_hash @_;
        my $popsize = $args{'-popsize'} || 100;
        my $ntips   = $args{'-tips'} || 10;
        my $ntrees  = $args{'-trees'} || 10;
        my $factory = $args{'-factory'} || $factory;
        my $forest  = $factory->create_forest;
        my $cutoff  = 1 / ( 2 * $popsize );
        for my $i ( 1 .. $ntrees ) {
            my $ngen = 1;
            my ( @tips, @nodes );
            push @tips, $factory->create_node() for 1 .. $ntips;

            # starting from a pool of all tips, we iterate over all
            # possible pairs, and for each pair we test to see if
            # the coalesce at generation $ngen, at probability
            # 1/2N. When they do, we create a parent for the pair,
            # take the pair out of the pool and put the parent in it
            while ( scalar @tips > 1 ) {
                my $poolsize = $#tips;
                my $j        = 0;
                while ( $j < $poolsize ) {
                    my $k = $j + 1;
                    while ( $k <= $poolsize ) {
                        my $rand = random_uniform();
                        if ( $rand <= $cutoff ) {
                            my $tip2 = splice @tips, $k, 1;
                            my $tip1 = splice @tips, $j, 1;
                            my $parent = $factory->create_node(
                                '-generic' => { 'age' => $ngen } );
                            unshift @nodes,
                              $tip1->set_parent($parent),
                              $tip2->set_parent($parent);
                            push @tips, $parent;
                            $poolsize--;
                        }
                        $k++;
                    }
                    $j++;
                }
                $ngen++;
            }
            push @nodes, shift @tips;
            my $tree = $factory->create_tree()->insert(@nodes);
            $tree->agetobl;
            $forest->insert($tree);
        }
        return $forest;
    }

=item gen_equiprobable()

This method draws tree shapes at random, 
such that all shapes are equally probable.

 Type    : Generator
 Title   : gen_equiprobable
 Usage   : my $trees = $gen->gen_equiprobable( '-tips' => 10 );
 Function: Generates an equiprobable tree 
           shape, with branch lengths = 1;
 Returns : A Bio::Phylo::Forest object.
 Args    : Optional: -tips  => number of terminal nodes (default: 10),
           Optional: -trees => number of trees to generate (default: 1),
	   Optional: -factory => a Bio::Phylo::Factory object

=cut

    sub _fetch_equiprobable {
        my @tips      = @_;
        my $tip_index = int rand scalar @tips;
        my $tip       = splice @tips, $tip_index, 1;
        return $tip, @tips;
    }

    sub _fetch_balanced {
        return @_;
    }

    sub _fetch_ladder {
        my $tip = pop;
        return $tip, @_;
    }

    sub _gen_simple {
        my $random  = shift;
        my %options = looks_like_hash @_;
        my $fetcher = $options{'-fetcher'};
        my $factory = $options{'-factory'} || $factory;
        my $ntrees  = $options{'-trees'} || 1;
        my $ntips   = $options{'-tips'} || 10;
        my $forest  = $factory->create_forest;
        for my $i ( 1 .. $ntrees ) {
            my $tree = $factory->create_tree;
            my ( @tips, @nodes );

            # each iteration, we will remove two "tips" from this
            # and add their newly created parent to it
            push @tips, $factory->create_node( '-branch_length' => 1, )
              for ( 1 .. $ntips );

            # this stays above 0 because the root ends up in it
            while ( @tips > 1 ) {
                my $parent = $factory->create_node( '-branch_length' => 1, );
                $tree->insert($parent);
                for ( 1 .. 2 ) {
                    my $tip;
                    ( $tip, @tips ) = $fetcher->(@tips);
                    $tree->insert( $tip->set_parent($parent) );
                }

                # the parent becomes a new candidate tip
                push @tips, $parent;
            }
            $forest->insert($tree);
        }
        return $forest;
    }

    sub gen_equiprobable {
        return _gen_simple( @_, '-fetcher' => \&_fetch_equiprobable );
    }

=item gen_balanced()

This method creates the most balanced topology possible given the number of tips

 Type    : Generator
 Title   : gen_balanced
 Usage   : my $trees = $gen->gen_balanced( '-tips'  => 10 );
 Function: Generates the most balanced topology
           possible, with branch lengths = 1;
 Returns : A Bio::Phylo::Forest object.
 Args    : Optional: -tips  => number of terminal nodes (default: 10),
           Optional: -trees => number of trees to generate (default: 1),
	   Optional: -factory => a Bio::Phylo::Factory object

=cut

    sub gen_balanced {
        return _gen_simple( @_, '-fetcher' => \&_fetch_balanced );
    }

=item gen_ladder()

This method creates a ladder tree for the number of tips

 Type    : Generator
 Title   : gen_ladder
 Usage   : my $trees = $gen->gen_ladder( '-tips'  => 10 );
 Function: Generates the least balanced topology
           (a ladder), with branch lengths = 1;
 Returns : A Bio::Phylo::Forest object.
 Args    : Optional: -tips  => number of terminal nodes (default: 10),
           Optional: -trees => number of trees to generate (default: 1),
	   Optional: -factory => a Bio::Phylo::Factory object

=cut

    sub gen_ladder {
        return _gen_simple( @_, '-fetcher' => \&_fetch_ladder );
    }

=back

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

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
