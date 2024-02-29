package Bio::Phylo::Parsers::Adjacency;
use strict;
use warnings;
use base 'Bio::Phylo::Parsers::Abstract';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw'/looks_like/ :namespaces :objecttypes';

=head1 NAME

Bio::Phylo::Parsers::Adjacency - Parser used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module parses a tree structure from tabular data organized as an "adjacency
list", i.e. child -> parent relationships. The table should at least have the
following columns: 'child' and 'parent'. 'length' is interpreted as branch
length. Columns starting with 'node:' are assigned as semantic annotations
to the focal node, columns starting with 'branch:' are assigned to the focal
branch. Records need to be listed in pre-order, so that references to parent
nodes can be resolved immediately. Consequently, the root is the first record,
without a parent. Example:

 ((A:1,B:2)n1:3,C:4)n2:0;

Becomes (with an extra example annotation):

 child  parent  length	node:dcterms:identifier
 n2             0       35462
 n1     n2      3       34987
 A      n1      1       73843
 B      n1      2       98743
 C      n2      4       39847

=cut

sub _parse {
    my $self = shift;
    my $fh   = $self->_handle;
    my $fac  = $self->_factory;
	my $log  = $self->_logger;
    my $tree = $fac->create_tree;
	my $ns   = $self->_args->{'-namespaces'};
	if ( $ns ) {
		$tree->set_namespaces( %{ $ns } );
	}
	my ( @header, %node_cols );
	my %node_for_id;
    LINE: while (<$fh>) {
    	unless ( scalar(keys(%node_for_id)) % 1000 ) {
    		$log->debug("processed node " . scalar(keys(%node_for_id)));
    	}
        chomp;
		
		# the first line is the header row
		if ( not @header ) {
			@header = split /\t/, $_;
			for my $col ( @header ) {
				if ( $col =~ /^node:(.+)$/ ) {
					my $predicate = $1;
					$node_cols{$col} = $predicate;
				}
			}
			next LINE;
		}
		
		# this is a record
        my @fields = split /\t/, $_;
		my %record = map { $header[$_] => $fields[$_] } 0 .. $#header;
		
		# create node
		my $name   = $record{'child'};
		my $pname  = $record{'parent'};
		my $node   = $fac->create_node( '-name' => $name );
		$tree->insert($node);
		$node_for_id{$name} = $node;
		
		# build the tree structure
		if ( my $parent = $node_for_id{$pname} ) {
			$node->set_parent($parent);
		}
		
		# assign branch length, if defined
		if ( defined $record{'length'} ) {
			$node->set_branch_length($record{'length'});
		}
		
		# now see if there are any node columns
		for my $col ( keys %node_cols ) {
			my $value = $record{$col};
			if ( $value ) {
				my $predicate = $node_cols{$col};
				if ( $predicate =~ /^(.+)?:.+$/ ) {
					my $prefix = $1;
					if ( my $ns = $Bio::Phylo::Util::CONSTANT::NS->{$prefix} ) {
						$node->add_meta(
							$fac->create_meta(
								'-namespaces' => { $prefix    => $ns },
								'-triple'     => { $predicate => $value }
							)
						);
					}
					else {
						$log->warn("No namespace for prefix $prefix");
					}
				}
			}
		}
    }
	my $forest = $fac->create_forest;
	$forest->insert($tree);	
    return $forest;
}

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The adjacency parser is called by the L<Bio::Phylo::IO|Bio::Phylo::IO> object.
Look there to learn how to parse trees in general

=item L<Bio::Phylo::Manual>

Also see the manual: L<Bio::Phylo::Manual> and L<http://rutgervos.blogspot.com>

=back

=head1 CITATION

If you use Bio::Phylo in published research, please cite it:

B<Rutger A Vos>, B<Jason Caravas>, B<Klaas Hartmann>, B<Mark A Jensen>
and B<Chase Miller>, 2011. Bio::Phylo - phyloinformatic analysis using Perl.
I<BMC Bioinformatics> B<12>:63.
L<http://dx.doi.org/10.1186/1471-2105-12-63>

=cut

1;
