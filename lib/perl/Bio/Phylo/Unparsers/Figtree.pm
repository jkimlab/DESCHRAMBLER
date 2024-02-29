package Bio::Phylo::Unparsers::Figtree;
use strict;
use warnings;
use base 'Bio::Phylo::Unparsers::Nexus';
use Bio::Phylo::Util::Logger ':levels';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw':objecttypes :namespaces';
use Data::Dumper;

my $log = Bio::Phylo::Util::Logger->new;
my $ns  = _NS_FIGTREE_;
my $pre = 'fig';

=head1 NAME

Bio::Phylo::Unparsers::Figtree - Serializer used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module turns objects into a nexus-formatted string that uses additional
syntax for Figtree. It is called by the L<Bio::Phylo::IO> facade, don't call it
directly. You can pass the following additional arguments to the unparse call:
	
=begin comment

 Type    : Wrapper
 Title   : _to_string($obj)
 Usage   : $figtree->_to_string($obj);
 Function: Stringifies an object into
           a nexus/figtree formatted string.
 Alias   :
 Returns : SCALAR
 Args    : Bio::Phylo::*

=end comment

=cut

sub _to_string {
    my $self = shift;
	$self->{'FOREST_ARGS'} = {
		'-nodelabels' => \&_figtree_handler,
		'-figtree' => 1,
	};
	return $self->SUPER::_to_string(@_);
}

sub _figtree_handler {

	# node object, translation table ID, if any
	my ( $node, $id ) = @_;

	# fetch Meta objects, filter out the ones that are _NS_FIGTREE_,
	# turn them into a hash without the fig prefix	
	my @meta = @{ $node->get_meta };
	my %meta = map { $_->get_predicate_local => $_->get_object }
	          grep { $_->get_predicate_namespace eq $ns } @meta;
	$log->debug( Dumper(\%meta) );
	
	# there can be separate annotations that are _min and _max for
	# the same variable name stem. We combine these into a range
	# between curly braces. Also add % percentage symbol for 95%
	# HPD ranges - the % symbol is disallowed in CURIEs, hence we
	# have to bring it back here.
	my %merged;
	KEY: for my $key ( keys %meta ) {
		if ( $key =~ /^(.+?)_min$/ ) {
			my $stem = $1;
			my $max_key = $stem . '_max';
			$stem =~ s/95/95%/;
			$merged{$stem} = '{'.$meta{$key}.','.$meta{$max_key}.'}';
		}
		elsif ( $key =~ /^(.+?)_max$/ ) {
			next KEY;
		}
		else {
			$key =~ s/95/95%/;
			$merged{$key} = $meta{$key};
		}
	}
	
	# create the concatenated annotation string
	my $anno = '[&' . join( ',',map { $_.'='.$merged{$_} } keys %merged ) . ']';
	
	# construct the name:
	my $name;
	
	# case 1 - a translation table index was provided, this now replaces the name
	if ( defined $id ) {		
		$name = $id;
	}
	
	# case 2 - no translation table index, use the node name
	elsif ( defined $node->get_name ) {
		$name = $node->get_name;
	}
	
	# case 3 - use the empty string, to avoid uninitialized warnings.
	else {
		$name = '';
	}
	
	# append the annotation string, if we have it
	my $annotated = $anno ne '[&]' ? $name . $anno : $name;
	$log->debug($annotated);
	return $annotated;
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The nexus serializer is called by the L<Bio::Phylo::IO> object.

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
