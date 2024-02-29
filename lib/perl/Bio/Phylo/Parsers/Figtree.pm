package Bio::Phylo::Parsers::Figtree;
use strict;
use warnings;
use base 'Bio::Phylo::Parsers::Abstract';
use Bio::Phylo::Util::CONSTANT qw':namespaces :objecttypes';
use Bio::Phylo::Factory;
use Bio::Phylo::IO 'parse_tree';
use Bio::Phylo::Util::Logger ':levels';

my $fac = Bio::Phylo::Factory->new;
my $log = Bio::Phylo::Util::Logger->new;
my $ns  = _NS_FIGTREE_;
my $pre = 'fig';

=head1 NAME

Bio::Phylo::Parsers::Figtree - Parser used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module parses annotated trees in NEXUS format as interpreted by FigTree
(L<http://tree.bio.ed.ac.uk/software/figtree/>), i.e. trees where nodes have
additional 'hot comments' attached to them in the tree description. The
implementation assumes syntax as follows:

 [&minmax={0.1231,0.3254},rate=0.0075583392800736]
 
I.e. the first token inside the comments is an ampersand, the annotations are
comma-separated key/value pairs, where ranges are between curly parentheses.

The annotations are stored as meta objects, e.g.:

 $node->get_meta_object('fig:rate'); # 0.0075583392800736
 $node->get_meta_object('fig:minmax_min'); # 0.1231
 $node->get_meta_object('fig:minmax_max'); # 0.3254

Annotations that have non-alphanumerical symbols in them will have these removed
from them. For example, C<rate_95%_HPD={}> becomes two annotations:
C<rate_95_HPD_min> and C<rate_95_HPD_max>.

=cut

sub _parse {
    my $self = shift;
	my $fh = $self->_handle;
	my $forest = $fac->create_forest;
	$forest->set_namespaces( $pre => $ns );
	my $tree_block;
	my $tree_string;
	my %translate;
	while(<$fh>) {
		$tree_block++ if /BEGIN TREES;/i;
		if ( /^\s*TREE (\S+) = \[&([RU])\] (.+)$/i ) {
			my ( $name, $rooted, $newick ) = ( $1, $2, $3 );
			$tree_string++;
			my $tree = parse_tree(
				'-format'          => 'newick',
				'-string'          => $newick,
				'-ignore_comments' => 1,
			);
			$tree->set_as_unrooted if $rooted eq 'U';
			$tree->set_name( $name );
			$self->_post_process( $tree );
			for my $tip ( @{ $tree->get_terminals } ) {
				my $name = $tip->get_name;
				$tip->set_name( $translate{$name} );
			}
			$forest->insert($tree);
		}
		if ( $tree_block and not $tree_string and /\s+(\d+)\s+(.+)/ ) {
			my ( $id, $name ) = ( $1, $2 );
			$name =~ s/[,;]$//;
			$translate{$id} = $name;
		}
	}
	return $forest;
}

sub _post_process {
	my ( $self, $tree ) = @_;
	$log->debug("going to post-process tree");
    $tree->visit(sub{
    	my $n = shift;
    	my $name = $n->get_name;
    	$name =~ s/\\//g;
    	$log->debug("name: $name");
    	if ( $name =~ /\[/ and $name =~ /^([^\[]*?)\[(.+?)\]$/ ) {
    		my ( $trimmed, $comments ) = ( $1, $2 );
    		$n->set_name( $trimmed );
    		$log->debug("trimmed name: $trimmed");
    		
    		# "hot comments" start with ampersand. ignore if not.
    		if ( $comments =~ /^&(.+)/ ) {
    			$log->debug("hot comments: $comments");
    			$comments = $1;
    			
    			# string needs to be fully eaten up
    			COMMENT: while( my $old_length = length($comments) ) {
    			
    				# grab the next key
    				if ( $comments =~ /^(.+?)=/ ) {
    					my $key = $1;
    					
    					# remove the key and the =
    					$comments =~ s/^\Q$key\E=//;
						$key =~ s/\%//;
    					
    					# value is a comma separated range
    					if ( $comments =~ /^{([^}]+)}/ ) {
    						my $value = $1;
							my ( $min, $max ) = split /,/, $value;
							_meta( $n, "${key}_min" => $min );
							_meta( $n, "${key}_max" => $max );
							$log->debug("$key: $min .. $max");
    						
    						# remove the range
    						$value = "{$value}";
    						$comments =~ s/^\Q$value\E//;
    					}
    					
    					# value is a scalar
    					elsif ( $comments =~ /^([^,]+)/ ) {
    						my $value = $1;
							_meta( $n, $key => $value );
    						$comments =~ s/^\Q$value\E//;
    						$log->debug("$key: $value");
    					}
    					
    					# remove trailing comma, if any
    					$comments =~ s/^,//;
    				}
    				if ( $old_length == length($comments) ) {
    					$log->warn("couldn't parse newick comment: $comments");
    					last COMMENT;
    				}
    			}
    		}
    		else {
    			$log->debug("not hot: $comments");
    		}
    	}
    });
}

sub _meta {
	my ( $node, $key, $value ) = @_;
	#if ( $key =~ /[()+]/ ) {
		$log->info("cleaning up CURIE candidate $key");
		$key =~ s/\(/_/g;
		$key =~ s/\)/_/g;
		$key =~ s/\+/_/g;
		$key =~ s/\!//;
	#}
	$node->add_meta(
		$fac->create_meta( '-triple' => { "${pre}:${key}" => $value } )
	);
}


# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The figtree parser is called by the L<Bio::Phylo::IO> object.
Look there to learn how to parse phylogenetic data files in general.

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
