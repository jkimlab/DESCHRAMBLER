package Bio::Phylo::Forest;
use strict;
use warnings;
use base qw'Bio::Phylo::Listable Bio::Phylo::Taxa::TaxaLinker';
use Bio::Phylo::Util::CONSTANT qw':objecttypes /looks_like/';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Factory;

=begin comment

This class has no internal state, no cleanup is necessary.

=end comment

=cut

{
    my $logger             = __PACKAGE__->get_logger;
    my $factory            = Bio::Phylo::Factory->new;
    my $CONSTANT_TYPE      = _FOREST_;
    my $CONTAINER_CONSTANT = _PROJECT_;

=head1 NAME

Bio::Phylo::Forest - Container for tree objects

=head1 SYNOPSIS

 use Bio::Phylo::Factory;
 my $fac = Bio::Phylo::Factory->new;
 my $forest = $fac->create_forest;
 my $tree = $fac->create_tree;
 $forest->insert($tree);
 print $forest->to_nexus;

=head1 DESCRIPTION

The Bio::Phylo::Forest object models a set of trees. The object subclasses the
L<Bio::Phylo::Listable> object, so look there for more methods available to
forest objects.

=head1 CALCULATIONS

=over

=item calc_split_frequency()

Calculates frequency of provided split

 Type    : Calculation
 Title   : calc_split_frequency
 Usage   : my $freq = $trees->calc_split_frequency([$node1,$node2]);
 Function: Calculates split frequency
 Returns : Scalar, a number
 Args    : An array of taxon objects, or a taxa object
 Comment :

=cut

    sub calc_split_frequency {
        my ( $self, $arg ) = @_;
        my @trees  = @{ $self->get_entities };
        my $ntrees = scalar @trees;
        if ($ntrees) {
            my $count = 0;
            for my $tree (@trees) {
                $count++ if $tree->is_clade($arg);
            }
            return $count / $ntrees;
        }
        return 0;
    }

=back

=head1 METHODS

=over

=item insert()

Inserts trees in forest.

 Type    : Method
 Title   : insert
 Usage   : $trees->insert( $tree1, $tree2, ... );
 Function: Inserts trees in forest.
 Returns : A Bio::Phylo::Forest object.
 Args    : Trees
 Comment : The last seen tree that is set as default
           becomes the default for the entire forest

=cut

    sub insert {
        my $self = shift;
        if ( $self->can_contain(@_) ) {
            my $seen_default = 0;
            for my $tree ( reverse @_ ) {
                if ( $tree->is_default ) {
                    if ( not $seen_default ) {
                        $seen_default++;
                    }
                    else {
                        $tree->set_not_default;
                    }
                }
            }
            if ($seen_default) {
                if ( my $tree = $self->get_default_tree ) {
                    $tree->set_not_default;
                }
            }
            $self->SUPER::insert(@_);
        }
        else {
            throw 'ObjectMismatch' => "Failed insertion: @_ [in $self]";
        }
    }

=item get_default_tree()

Gets the default tree in the forest.

 Type    : Method
 Title   : get_default_tree
 Usage   : my $tree = $trees->get_default_tree;
 Function: Gets the default tree in the forest.
 Returns : A Bio::Phylo::Forest::Tree object.
 Args    : None
 Comment : If no default tree has been set, 
           returns first tree. 

=cut

    sub get_default_tree {
        my $self  = shift;
        my $first = $self->first;
        for my $tree ( @{ $self->get_entities } ) {
            return $tree if $tree->is_default;
        }
        return $first;
    }

=item check_taxa()

Validates taxon links of nodes in invocant's trees.

 Type    : Method
 Title   : check_taxa
 Usage   : $trees->check_taxa;
 Function: Validates the taxon links of the
           nodes of the trees in $trees
 Returns : A validated Bio::Phylo::Forest object.
 Args    : None

=cut

    sub check_taxa {
        my $self = shift;

        # is linked
        if ( my $taxa = $self->get_taxa ) {
            my %tips;
			
			# build a hash of all the unlinked tips by their names
            TIP: for my $tip ( map { @{ $_->get_terminals } } @{ $self->get_entities } ) {
				next TIP if $tip->get_taxon && $taxa->contains($tip->get_taxon);
                my $name = $tip->get_internal_name;
                if ( not $tips{$name} ) {
                    $tips{$name} = [];
                }
                push @{ $tips{$name} }, $tip;
            }
			
			# build a hash of the available taxa
            my %taxa = map { $_->get_internal_name => $_ } @{ $taxa->get_entities };
			
			# iterate over unlinked tip
            for my $name ( keys %tips ) {
                $logger->debug("linking tip $name");
				
				# tip not seen yet, creating new
                if ( not exists $taxa{$name} ) {
                    $logger->debug("no taxon object for $name yet, instantiating");
                    $taxa->insert( $taxa{$name} = $factory->create_taxon( '-name' => $name ) );
                }
				
				# link tips to newly created taxon
                for my $tip ( @{ $tips{$name} } ) {
                    $tip->set_taxon( $taxa{$name} );
                }
            }
        }

        # not linked
        else {
            for my $tree ( @{ $self->get_entities } ) {
                for my $node ( @{ $tree->get_entities } ) {
                    $node->set_taxon();
                }
            }
        }
        return $self;
    }

=item make_consensus()

Creates a consensus tree.

 Type    : Method
 Title   : make_consensus
 Usage   : my $tree = $obj->make_consensus
 Function: Creates a consensus tree
 Returns : $tree
 Args    : Optional:
	   -fraction  => a fraction that specifies the cutoff frequency for including
                     bipartitions in the consensus. Default is 0.5 (MajRule)
	   -branches  => 'frequency' or 'average', sets branch lengths to bipartition
	                 frequency or average branch length in input trees
	   -summarize => 'fraction' or 'probability', sets node label as either the
	                 fraction of this bipartition on the whole (e.g. "85/100") or
	                 as a probability (e.g. "0.85")

=cut

    sub make_consensus {
        my $self     = shift;
        my %args     = looks_like_hash @_;
        my $perc     = $args{'-fraction'} || 0.5;
        my $branches = $args{'-branches'} || 'freq';
        my %seen_partitions;
        my %clade_lengths;
        my $tree_count = 0;
        my $average    = sub {
            my @list = @_;
            my $sum  = 0;
            for my $val (@list) {
                $sum += $val if defined $val;
            }
            my $avg = $sum / scalar @list;
            return $avg;
        };

# here we populate a hash whose keys are strings identifying all bipartitions in all trees
# in the forest. Because we construct these strings by concatenating (with an unlikely
# separator) all tips in that clade after sorting them alphabetically, we will get
# the same string in topologically identical clades across trees. We use these keys
# to keep a running tally of all seen bipartitions.
        for my $tree ( @{ $self->get_entities } ) {
            for my $node ( @{ $tree->get_internals } ) {

           # whoever puts this string in their input tree gets what he deserves!
                my $clade =
                  join '!\@\$%^&****unlikely_clade_separator***!\@\$%^&****',
                  sort { $a cmp $b }
                  map  { $_->get_internal_name } @{ $node->get_terminals };
                $seen_partitions{$clade}++;
                if ( not exists $clade_lengths{$clade} ) {
                    $clade_lengths{$clade} = [];
                }
                push @{ $clade_lengths{$clade} }, $node->get_branch_length;
            }
            for my $tip ( @{ $tree->get_terminals } ) {
                my $clade = $tip->get_internal_name;
                if ( not exists $clade_lengths{$clade} ) {
                    $clade_lengths{$clade} = [];
                }
                push @{ $clade_lengths{$clade} }, $tip->get_branch_length;
            }
            $tree_count++;
        }

# here we remove the seen bipartitions that occur in fewer trees than in the specified
# fraction
        my @by_size =
          sort { $seen_partitions{$b} <=> $seen_partitions{$a} }
          keys %seen_partitions;
        my $largest    = shift @by_size;
        my @partitions = keys %seen_partitions;
        for my $partition (@partitions) {
            if ( ( $seen_partitions{$partition} / $tree_count ) <= $perc ) {
                delete $seen_partitions{$partition};
            }
        }

# we now sort the clade strings by size, which automatically means once we start
# traversing them that we will visit the bipartitions in the right nesting order
        my @sorted = sort { length($b) <=> length($a) } keys %seen_partitions;
        my %seen_nodes;
        my $tree = $factory->create_tree;
        if ( @sorted == 0 ) {
            push @sorted, $largest;
            $seen_partitions{$largest} = $tree_count;
        }
        for my $partition (@sorted) {

            # now create the individual tip names again from the key string
            my @tips =
              split /\Q!\@\$%^&****unlikely_clade_separator***!\@\$%^&****\E/,
              $partition;

            # create the tip object if we haven't done so already
            for my $tip (@tips) {
                if ( not exists $seen_nodes{$tip} ) {
                    my $node = $factory->create_node( '-name' => $tip );
                    if ( $branches =~ /^f/i ) {
                        $node->set_branch_length(1.0);
                        $node->set_generic( 'average_branch_length' =>
                              $average->( @{ $clade_lengths{$tip} } ) );
                    }
                    else {
                        $node->set_branch_length(
                            $average->( @{ $clade_lengths{$tip} } ) );
                        $node->set_generic( 'bipartition_frequency' => 1.0 );
                    }
                    $seen_nodes{$tip} = $node;
                    $tree->insert($node);
                }
            }

            # create the new parent node
            my $new_parent = $factory->create_node();
            if ( $branches =~ /^f/i ) {
                $new_parent->set_branch_length(
                    $seen_partitions{$partition} / $tree_count );
                $new_parent->set_name(
                    $average->( @{ $clade_lengths{$partition} } ) );
            }
            else {
                $new_parent->set_branch_length( $average->( @{ $clade_lengths{$partition} } ) );
                if ( $args{'-summarize'} =~ /^f/i ) {
                	$new_parent->set_name( $seen_partitions{$partition} .'/'. $tree_count );
                }
                else {
                	$new_parent->set_name( $seen_partitions{$partition} / $tree_count );
                }
            }
            $tree->insert($new_parent);

# check to see if there is an old parent node: we want to squeeze the new parent
# node between the old parent and its children
            my $old_parent = $seen_nodes{ $tips[0] }->get_parent;
            if ($old_parent) {
                $new_parent->set_parent($old_parent);
            }

            # now assign the new parent to the tips in the current bipartition
            for my $tip (@tips) {
                my $node = $seen_nodes{$tip};
                $node->set_parent($new_parent);
            }
        }

# theoretically, the root length should be 1.0 because this "partition is present
# in all trees. But it's too much trouble to stick :-)
        $tree->get_root->set_branch_length();
        return $tree;
    }

=item make_matrix()

Creates an MRP matrix object.

 Type    : Method
 Title   : make_matrix
 Usage   : my $matrix = $obj->make_matrix
 Function: Creates an MRP matrix object
 Returns : $matrix
 Args    : NONE

=cut

    sub make_matrix {
        my $self   = shift;
        my $taxa   = $self->make_taxa;
        my $matrix = $factory->create_matrix;
        $matrix->set_taxa($taxa);
        my ( %data, @charlabels, @statelabels );
        for my $taxon ( @{ $taxa->get_entities } ) {
            my $datum = $factory->create_datum;
            $datum->set_taxon($taxon);
            $datum->set_name( $taxon->get_name );
            $matrix->insert($datum);
            $data{ $taxon->get_name } = [];
        }
        my $recursion = sub {
            my ( $node, $tree, $taxa, $method ) = @_;
            push @charlabels, $tree->get_internal_name;
            push @statelabels, [ 'outgroup', $node->get_nexus_name ];
            my %tip_values =
              map { $_->get_name => 1 } @{ $node->get_terminals };
            for my $tipname ( map { $_->get_name } @{ $tree->get_terminals } ) {
                $tip_values{$tipname} = 0 if not exists $tip_values{$tipname};
            }
            for my $datumname ( keys %data ) {
                if ( exists $tip_values{$datumname} ) {
                    push @{ $data{$datumname} }, $tip_values{$datumname};
                }
                else {
                    push @{ $data{$datumname} }, '?';
                }
            }
            $method->( $_, $tree, $taxa, $method )
              for grep { $_->is_internal } @{ $node->get_children };
        };
        for my $tree ( @{ $self->get_entities } ) {
			if ( my $root = $tree->get_root ) {
				$recursion->( $root, $tree, $taxa, $recursion );
			}
        }
        for my $datum ( @{ $matrix->get_entities } ) {
			if ( my $data = $data{ $datum->get_name } ) {
				$datum->set_char( $data ) if @{ $data };
			}
        }
        $matrix->set_charlabels( \@charlabels );
        $matrix->set_statelabels( \@statelabels );
        return $matrix;
    }

=item make_taxa()

Creates a taxa block from the objects contents if none exists yet.

 Type    : Method
 Title   : make_taxa
 Usage   : my $taxa = $obj->make_taxa
 Function: Creates a taxa block from the objects contents if none exists yet.
 Returns : $taxa
 Args    : NONE

=cut

    sub make_taxa {
        my $self = shift;
        if ( my $taxa = $self->get_taxa ) {
            return $taxa;
        }
        else {
            my %taxa;
            my $taxa = $factory->create_taxa;
            for my $tree ( @{ $self->get_entities } ) {
                for my $tip ( @{ $tree->get_terminals } ) {
                    my $name = $tip->get_internal_name;
                    if ( not $taxa{$name} ) {
                        $taxa{$name} =
                          $factory->create_taxon( '-name' => $name );
                    }
                }
            }
            if (%taxa) {
                $taxa->insert( map { $taxa{$_} }
                      sort { $a cmp $b } keys %taxa );
            }
            $self->set_taxa($taxa);
            return $taxa;
        }
    }

=item to_newick()

Serializes invocant to newick string.

 Type    : Stringifier
 Title   : to_newick
 Usage   : my $string = $forest->to_newick;
 Function: Turns the invocant forest object 
           into a newick string, one line per tree
 Returns : SCALAR
 Args    : The same arguments as 
           Bio::Phylo::Forest::Tree::to_newick

=cut

    sub to_newick {
        my $self = shift;
        my $newick;
        for my $tree ( @{ $self->get_entities } ) {
            $newick .= $tree->to_newick(@_) . "\n";
        }
        return $newick;
    }

=item to_nexus()

Serializer to nexus format.

 Type    : Format convertor
 Title   : to_nexus
 Usage   : my $data_block = $matrix->to_nexus;
 Function: Converts matrix object into a nexus data block.
 Returns : Nexus data block (SCALAR).
 Args    : Trees can be formatted using the same arguments as those
           passed to Bio::Phylo::Unparsers::Newick. In addition, you
           can provide: 
           
           # as per mesquite's inter-block linking system (default is false):
           -links => 1 (to create a TITLE token, and a LINK token, if applicable)
           
           # rooting is determined based on basal trichotomy. "token" means 'TREE' or 'UTREE'
           # is used, "comment" means [&R] or [&U] is used, "nhx" means [%unrooted=on] or
           # [%unrooted=off] if used, default is "comment"
           -rooting => one of (token|comment|nhx)
           
           # to map taxon names to indices (default is true)
           -make_translate => 1 (autogenerate translation table, overrides -translate => {})
		   
		   # when making a translation table, which index to start (default is
		   # 1, BayesTraits needs 0)
		   -translate_start => 1
 Comments:

=cut

    sub to_nexus {
        my $self = shift;
        my %args = (
			'-rooting'         => 'comment',
			'-make_translate'  => 1,
			'-translate_start' => 1,
			@_
		);
        my %translate;
        my $nexus;

        # make translation table
        if ( $args{'-make_translate'} ) {
            my $i = 0;
            for my $tree ( @{ $self->get_entities } ) {
                for my $node ( @{ $tree->get_terminals } ) {
                    my $name;
                    if ( not $args{'-tipnames'} ) {
                        $name = $node->get_nexus_name;
                    }
                    elsif ( $args{'-tipnames'} =~ /^internal$/i ) {
                        $name = $node->get_nexus_name;
                    }
                    elsif ( $args{'-tipnames'} =~ /^taxon/i
                        and $node->get_taxon )
                    {
                        if ( $args{'-tipnames'} =~ /^taxon_internal$/i ) {
                            $name = $node->get_taxon->get_nexus_name;
                        }
                        elsif ( $args{'-tipnames'} =~ /^taxon$/i ) {
                            $name = $node->get_taxon->get_nexus_name;
                        }
                    }
                    else {
                        $name = $node->get_generic( $args{'-tipnames'} );
                    }
                    $translate{$name} = ( $args{'-translate_start'} + $i++ )
                      if not exists $translate{$name};
                }
            }
            $args{'-translate'} = \%translate;
        }

        # create header
        $nexus = "BEGIN TREES;\n";
        $nexus .=
            "[! Trees block written by "
          . ref($self) . " "
          . $self->VERSION . " on "
          . localtime() . " ]\n";
		if ( $args{'-figtree'} ) {
			delete $args{'-figtree'};
			$nexus .= "[! Tree(s) include FigTree node annotations ]\n";
		}
        if ( $args{'-links'} ) {
            delete $args{'-links'};
            $nexus .= "\tTITLE " . $self->get_nexus_name . ";\n";
            if ( my $taxa = $self->get_taxa ) {
                $nexus .= "\tLINK TAXA=" . $taxa->get_nexus_name . ";\n";
            }
        }

        # stringify translate table
        if ( $args{'-make_translate'} ) {
            delete $args{'-make_translate'};
            $nexus .= "\tTRANSLATE\n";
            my @translate;
            for ( keys %translate ) { $translate[ $translate{$_} - 1 ] = $_ }
            for my $i ( 0 .. $#translate ) {
                $nexus .= "\t\t" . ( $i + 1 ) . " " . $translate[$i];
                if ( $i == $#translate ) {
                    $nexus .= ";\n";
                }
                else {
                    $nexus .= ",\n";
                }
            }
        }

        # stringify trees
        for my $tree ( @{ $self->get_entities } ) {
            if ( $tree->is_rooted ) {
                if ( $args{'-rooting'} =~ /^token$/i ) {
                    $nexus .=
                        "\tTREE "
                      . $tree->get_nexus_name . ' = '
                      . $tree->to_newick(%args) . "\n";
                }
                elsif ( $args{'-rooting'} =~ /^comment$/i ) {
                    $nexus .=
                        "\tTREE "
                      . $tree->get_nexus_name
                      . ' = [&R] '
                      . $tree->to_newick(%args) . "\n";
                }
                elsif ( $args{'-rooting'} =~ /^nhx/i ) {
                    $tree->get_root->set_generic( 'unrooted' => 'off' );
                    if ( $args{'-nhxkeys'} ) {
                        push @{ $args{'-nhxkeys'} }, 'unrooted';
                    }
                    else {
                        $args{'-nhxkeys'} = ['unrooted'];
                    }
                    $nexus .=
                        "\tTREE "
                      . $tree->get_nexus_name . ' = '
                      . $tree->to_newick(%args) . "\n";
                }
            }
            else {
                if ( $args{'-rooting'} =~ /^token$/i ) {
                    $nexus .=
                        "\tUTREE "
                      . $tree->get_nexus_name . ' = '
                      . $tree->to_newick(%args) . "\n";
                }
                elsif ( $args{'-rooting'} =~ /^comment$/i ) {
                    $nexus .=
                        "\tTREE "
                      . $tree->get_nexus_name
                      . ' = [&U] '
                      . $tree->to_newick(%args) . "\n";
                }
                elsif ( $args{'-rooting'} =~ /^nhx/i ) {
                    $tree->get_root->set_generic( 'unrooted' => 'on' );
                    if ( $args{'-nhxkeys'} ) {
                        push @{ $args{'-nhxkeys'} }, 'unrooted';
                    }
                    else {
                        $args{'-nhxkeys'} = ['unrooted'];
                    }
                    $nexus .=
                        "\tTREE "
                      . $tree->get_nexus_name . ' = '
                      . $tree->to_newick(%args) . "\n";
                }
            }
        }

        # done!
        $nexus .= "END;\n";
        return $nexus;
    }

=begin comment

 Type    : Internal method
 Title   : _container
 Usage   : $trees->_container;
 Function:
 Returns : CONSTANT
 Args    :

=end comment

=cut

    sub _container { $CONTAINER_CONSTANT }

=begin comment

 Type    : Internal method
 Title   : _type
 Usage   : $trees->_type;
 Function:
 Returns : CONSTANT
 Args    :

=end comment

=cut

    sub _type { $CONSTANT_TYPE }
    sub _tag  { 'trees' }

=back

=cut

    # podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::Listable>

The forest object inherits from the L<Bio::Phylo::Listable>
object. The methods defined therein are applicable to forest objects.

=item L<Bio::Phylo::Taxa::TaxaLinker>

The forest object inherits from the L<Bio::Phylo::Taxa::TaxaLinker>
object. The methods defined therein are applicable to forest objects.

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
