package Bio::Phylo::Unparsers::Adjacency;
use strict;
use warnings;
use base 'Bio::Phylo::Unparsers::Abstract';
use Bio::Phylo::Forest::Tree;
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT ':objecttypes';

=head1 NAME

Bio::Phylo::Unparsers::Adjacency - Serializer used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module turns a tree structure into tabular data organized as an "adjacency
list", i.e. child -> parent relationships. The table at least has the
following columns: 'child' and 'parent'. 'length' is interpreted as branch
length. Columns starting with 'node:' are created for semantic annotations
to the focal node, columns starting with 'branch:' are created for the focal
branch. Records are listed in pre-order, so that references to parent
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


sub _to_string {
    my $self  = shift;
    my $phylo = $self->{'PHYLO'};
    my $type  = $phylo->_type;
	
	# optionally, there might be predicates to serialize
	my $predicates = $self->{'PREDICATES'};
	my $cols;
	if ( $predicates ) {
		$cols = "\t" . join "\t", map { "node:$_" } @{ $predicates };
	}
	
	# create header
	my $output = <<HEADER;
child	parent	length$cols
HEADER
	
	# get the focal tree from the input
	my $tree;
    if ( $type == _TREE_ ) {
		$tree = $phylo;
    }
    elsif ( $type == _FOREST_ ) {
		$tree = $phylo->first;
    }
    elsif ( $type == _PROJECT_ ) {
		($tree) = @{ $phylo->get_items(_TREE_) };
    }
	else {
		throw 'BadArgs' => "Don't know how to serialize $phylo";
	}
	
	# create the output
	$tree->visit_depth_first(
		'-pre' => sub {
			my $node  = shift;
			my $name  = $node->get_internal_name;
			
			# parent name
			my $pname = '';
			if ( my $parent = $node->get_parent ) {
				$pname = $parent->get_internal_name;
			}
			
			# branch length
			my $bl = $node->get_branch_length;
			my $length = defined $bl ? $bl : '';
			
			# other annotations
			my $annotations = '';
			if ( $predicates ) {
				my @values;
				for my $p ( @{ $predicates } ) {
					push @values, $node->get_meta_object($p);
				}
				$annotations = "\t" . join "\t", @values;
			}
			$output .= "$name\t$pname\t$length$annotations\n";
		}
	);
	return $output;
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The adjacency unparser is called by the L<Bio::Phylo::IO> object.
Look there to learn how to unparse trees.

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
