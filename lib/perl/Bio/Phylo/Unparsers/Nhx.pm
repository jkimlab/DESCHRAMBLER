package Bio::Phylo::Unparsers::Nhx;
use strict;
use warnings;
use base 'Bio::Phylo::Unparsers::Abstract';
use Bio::Phylo::IO 'unparse';
use Bio::Phylo::Util::CONSTANT qw':objecttypes :namespaces';

=head1 NAME

Bio::Phylo::Unparsers::Nhx - Serializer used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module turns a tree object into a New Hampshire eXtended-formatted (parenthetical) 
tree description. It is called by the L<Bio::Phylo::IO> facade, don't call it directly. 
You can pass the following additional arguments to the unparse call:
	
	# by default, names for tips are derived from $node->get_name, if 
	# 'internal' is specified, uses $node->get_internal_name, if 'taxon'
	# uses $node->get_taxon->get_name, if 'taxon_internal' uses 
	# $node->get_taxon->get_internal_name, if $key, uses $node->get_generic($key)
	-tipnames => one of (internal|taxon|taxon_internal|$key)
	
	# for things like a translate table in nexus, or to specify truncated
	# 10-character names, you can pass a translate mapping as a hashref.
	# to generate the translated names, the strings obtained following the
	# -tipnames rules are used.
	-translate => { Homo_sapiens => 1, Pan_paniscus => 2 }	
	
	# if set, appends labels to internal nodes (names obtained from the same
	# source as specified by '-tipnames')
	-nodelabels => 1
	
	# specifies a branch length sprintf number formatting template, default is %f
	-blformat => '%e'

In addition, you can influence what key/value pairs are inserted into the NHX "hot 
comments" in two ways. The first way (and the way that is least likely to cause 
unintentional mishaps) is by attaching a Meta annotation to a node. This annotation
has to be associated with the NHX namespace. Here is an example:

	use Bio::Phylo::Util::CONSTANT ':classnames';
	
	# ...other things happening...
	$node->set_namespaces( 'nhx' => _NS_NHX_ );
	$node->set_meta_object( 'nhx:foo' => 'bar' );
	
	# which results in: [&&NHX:foo=bar]

The other way is by using the set/get generic methods, e.g.:

	$node->set_generic( 'foo' => 'bar');

However, this is riskier because everything you attach to an object using these methods
will be inserted into the NHX, including references (which won't serialize well).

=begin comment

 Type    : Wrapper
 Title   : _to_string($tree)
 Usage   : $newick->_to_string($tree);
 Function: Prepares for the recursion to unparse the tree object into a
           newick string.
 Alias   :
 Returns : SCALAR
 Args    : Bio::Phylo::Forest::Tree

=end comment

=cut

sub _to_string {
    my $self = shift;
    my $tree = $self->{'PHYLO'};
    my $type = $tree->_type;
    
    # collect distinct NHX keys
    my %keys;
    if ( $type == _TREE_ ) {
		_get_keys_from_tree($tree,\%keys);
    }
    elsif ( $type == _FOREST_ ) {
        my $forest = $tree;
		$forest->visit(sub{_get_keys_from_tree(shift,\%keys)});				
    }
    elsif ( $type == _PROJECT_ ) {
        my $project = $tree;
		$project->visit(sub{
			my $forest = shift;
			$forest->visit(sub{_get_keys_from_tree(shift,\%keys)});
		});
    }

	# transform arguments
	my %args = ( 
		'-format'   => 'newick',
		'-nhxstyle' => 'nhx', 
		'-nhxkeys'  => [ keys %keys ], 
		'-phylo'    => $tree, 
	);
	for my $key (qw(TRANSLATE TIPNAMES NODELABELS BLFORMAT)) {
		if ( my $val = $self->{$key} ) {
			my $arg = '-' . lc($key);
			$args{$arg} = $val;
		}
	}
	return unparse(%args);  
}

sub _get_keys_from_tree {
	my ( $tree, $hashref ) = @_;
	$tree->visit(sub{
		my $node = shift;
		for my $m ( @{ $node->get_meta } ) {
			if ( $m->get_predicate_namespace eq _NS_NHX_ ) {
				my ( $pre, $key ) = split /:/, $m->get_predicate;
				$hashref->{$key}++;
				$node->set_generic( $key => $m->get_object );
			}
		}
	});
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The NHX unparser is called by the L<Bio::Phylo::IO> object.
Look there to learn how to unparse newick strings.

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
