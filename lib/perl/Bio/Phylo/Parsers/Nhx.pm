package Bio::Phylo::Parsers::Nhx;
use warnings;
use strict;
use Bio::Phylo::IO 'parse';
use base 'Bio::Phylo::Parsers::Newick';
use Bio::Phylo::Util::CONSTANT ':namespaces';

=head1 NAME

Bio::Phylo::Parsers::Nhx - Parser used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module parses "New Hampshire eXtended" (NHX) tree descriptions in parenthetical 
format. The node annotations, which are described here: 
https://sites.google.com/site/cmzmasek/home/software/forester/nhx, are stored as meta
annotations in the namespace whose reserved prefix, nhx, is associated with the above
URI. This means that after this parser is done, you can fetch an annotation value thusly:

 my $gene_name = $node->get_meta_object( 'nhx:GN' );

This parser is called by the L<Bio::Phylo::IO> facade, don't call it directly. In turn,
this parser delegates processing of Newick strings to L<Bio::Phylo::Parsers::Newick>.
As such, several additional flags can be passed to the Bio::Phylo::IO parse and parse_tree 
functions to influence how to deal with complex newick strings:

 -keep => [ ...list of taxa names... ]

The C<-keep> flag allows you to only retain certain taxa of interest, ignoring others
while building the tree object.

 -keep_whitespace => 1,

This will treat unescaped whitespace as if it is a normal taxon name character. Normally,
whitespace is only retained inside quoted strings (e.g. C<'Homo sapiens'>), otherwise it
is the convention to use underscores (C<Homo_sapiens>). This is because some programs 
introduce whitespace to prettify a newick string, e.g. to indicate indentation/depth, 
in which case you almost certainly want to ignore it. This is the default behaviour. The 
option to keep it is provided for dealing with incorrectly formatted data.

Note that the flag C<-ignore_comments>, which is optional for the Newick parser cannot be
used. This is because NHX embeds its metadata in what are normally comments (i.e. square
brackets), so these must be processed in a special way.

=cut

sub _return_is_scalar { 1 }


sub _parse {
    my $self = shift;
    $self->_args->{'-ignore_comments'} = 1;
	return $self->SUPER::_parse;
}

sub _parse_node_data {
    my ( $self, $node, @clade ) = @_;
    $self->_logger->debug("parsing name and branch length for node");
    my @tail;
  PARSE_TAIL: for ( my $i = $#clade ; $i >= 0 ; $i-- ) {
        if ( $clade[$i] eq ')' ) {
            @tail = @clade[ ( $i + 1 ) .. $#clade ];
            last PARSE_TAIL;
        }
        elsif ( $i == 0 ) {
            @tail = @clade;
        }
    }
    
    # process branch length, nhx is suffixed
    my $bl = $tail[-1];
	my $nhx;
	if ( $bl and $bl =~ /^(.*?)\[&&NHX:(.+?)\]$/ ) {
		$node->set_namespaces( 'nhx' => _NS_NHX_ );
		( $bl, $nhx ) = ( $1, $2 );
		for my $tuple ( split /:/, $nhx ) {
			my ( $k, $v ) = split /=/, $tuple;
			$node->set_meta_object( 'nhx:' . $k => $v );
		}
	}

    # name only
    if ( scalar @tail == 1 ) {
        $node->set_name( $tail[0] );
    }
    elsif ( scalar @tail == 2 ) {
        $node->set_branch_length( $bl );
    }
    elsif ( scalar @tail == 3 ) {
        $node->set_name( $tail[0] );
        $node->set_branch_length( $bl );
    }
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The NHX parser is called by the L<Bio::Phylo::IO> object.
Look there to learn how to parse newick strings.

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
