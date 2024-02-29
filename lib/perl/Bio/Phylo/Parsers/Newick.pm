package Bio::Phylo::Parsers::Newick;
use warnings;
use strict;
use base 'Bio::Phylo::Parsers::Abstract';
no warnings 'recursion';

=head1 NAME

Bio::Phylo::Parsers::Newick - Parser used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module parses tree descriptions in parenthetical format. It is called by the 
L<Bio::Phylo::IO> facade, don't call it directly. Several additional flags can be
passed to the Bio::Phylo::IO parse and parse_tree functions to influence how to deal
with complex newick strings:

 -keep => [ ...list of taxa names... ]

The C<-keep> flag allows you to only retain certain taxa of interest, ignoring others
while building the tree object.

 -ignore_comments => 1,

This will treat comments in square brackets as if they are a normal taxon name character,
this so that names such as C<Choristoneura diversana|BC ZSM Lep 23401[05/*> are parsed 
"successfully". (Note: square brackets should NOT be used in this way as it will break
many parsers).

 -keep_whitespace => 1,

This will treat unescaped whitespace as if it is a normal taxon name character. Normally,
whitespace is only retained inside quoted strings (e.g. C<'Homo sapiens'>), otherwise it
is the convention to use underscores (C<Homo_sapiens>). This is because some programs 
introduce whitespace to prettify a newick string, e.g. to indicate indentation/depth, 
in which case you almost certainly want to ignore it. This is the default behaviour. The 
option to keep it is provided for dealing with incorrectly formatted data.

=cut

sub _return_is_scalar { 1 }


sub _simplify {
    # Simplify a Newick tree string by removing unneeded nodes. The leaves to
    # keep are given as $ids, an arrayref of terminal node IDs. Note that only
    # cherries are simplified to keep the function fast. Ternary or higher order
    # branches are left alone. Quoted strings should be handled properly.
    my ($string, $ids) = @_;   
    my %id_hash = map { $_ => undef } @$ids;

    # Setup some regular expressions:
    # 1/ ID is anything but these characters (except when quoted): , ; : ( ) " '
    my $id_re_simple = qr/[^)(,:"';]+/;
    my $id_re_squote = qr/[^']+/;
    my $id_re_dquote = qr/[^']+/;
    my $id_re = qr/ (?: $id_re_simple | '$id_re_squote' | "$id_re_dquote" ) /x;
    # 2/ Distance is a real number (regexp taken from Regexp::Common $RE{num}{real})
    my $dist_re   = qr/(?:(?i)(?:[+-]?)(?:(?=[.]?[0123456789])(?:[0123456789]*)(?:(?:[.])(?:[0123456789]{0,}))?)(?:(?:[E])(?:(?:[+-]?)(?:[0123456789]+))|))/;
    # 3/ A pair of ID and distance (both optional)
    my $pair_re   = qr/ ($id_re)? (?: \: ($dist_re) )? /x;
    # 4/ Cherry
    my $cherry_re = qr/ ( \( $pair_re , $pair_re \) $pair_re ) /x;
    # 5/ Whitespaces 
    my $ws_re     = qr/ \s+ /msx;

    # Remove spaces and newlines (no spaces allowed in node names)
    $string =~ s/$ws_re//g;

    # Prune cherries
    my $prev_string = '';
    while (not $string eq $prev_string) {
        $prev_string = $string;
        $string =~ s/ $cherry_re / _prune_cherry($1, $2, $3, $4, $5, $6, $7, \%id_hash) /gex;
    }
	__PACKAGE__->_logger->debug("simplified string by removing unneeded nodes");
    return $string;
}


sub _prune_cherry {
    my ($match, $id1, $dist1, $id2, $dist2, $idp, $distp, $id_hash) = @_;
    my $repl;
    my $id1_exists = defined $id1 && exists $id_hash->{$id1};
    my $id2_exists = defined $id2 && exists $id_hash->{$id2};
    if ( $id1_exists && $id2_exists ) {
        # Keep both leaves
        $repl = $match;
    } else {
        # There are from zero to one leaves to keep. Delete one of them.
        my ($id, $dist) = $id1_exists ? ($id1, $dist1) : ($id2, $dist2);
        if ( defined($dist) || defined($distp) ) {
            $dist = ':'.(($dist||0) + ($distp||0));
        }
        $id   ||= '' if not defined $id;
        $dist ||= '' if not defined $dist;
        $repl = $id.$dist;
    }
    return $repl;
}


sub _parse {
    my $self   = shift;
    my $fh     = $self->_handle;
    my $forest = $self->_factory->create_forest;

    my $string;
    while (<$fh>) {
        chomp;
        $string .= $_;
    }

    my $ids        = $self->_args->{'-keep'};
    my $ignore     = $self->_args->{'-ignore_comments'};
    my $whitespace = $self->_args->{'-keep_whitespace'};
    my $quotes     = $self->_args->{'-ignore_quotes'};

    # remove comments, split on tree descriptions
    my $counter = 1;

    for my $newick ( $self->_split($string,$ignore,$whitespace,$quotes) ) {
	$self->_logger->debug("going to process newick string " . $counter++);
        # simplify tree
        if ($ids) {
            $newick = _simplify($string, $ids);
        }
		
        # parse trees
	my $tree = $self->_parse_string($newick);

        # adding labels to untagged nodes
        if ( $self->_args->{'-label'} ) {
            my $i = 1;
            $tree->visit(
                sub {
                    my $n = shift;
                    $n->set_name( 'n' . $i++ ) unless $n->get_name;
                }
            );
        }
        $forest->insert($tree);
    }
    return $forest;
}

=begin comment

 Type    : Parser
 Title   : _split($string)
 Usage   : my @strings = $newick->_split($string);
 Function: Creates an array of (decommented) tree descriptions
 Returns : A Bio::Phylo::Forest::Tree object.
 Args    : $string = concatenated tree descriptions

=end comment

=cut

sub _split {
    my ( $self, $string, $ignore, $whitespace, $quotes ) = @_;
    my $log = $self->_logger;
    my ( $QUOTED, $COMMENTED ) = ( 0, 0 );
    my $decommented = '';
    my @trees;
  TOKEN: for my $i ( 0 .. length($string) ) {
        my $token = substr( $string, $i, 1 );

	# detect apostrophe as ' between two letters
	my $prev = $i > 0 ? substr( $string, $i-1, 1 ) : 0;
	my $next = $i< length($string) ? substr( $string, $i+1, 1 ) : 0;
	my $apostr =  substr( $string, $i, 1 ) eq "'" && $prev=~/[a-z]/i && $next=~/[a-z]/i;
	$log->debug("detected apostrophe") if $apostr;

        if ( !$QUOTED && !$COMMENTED && $token eq "'" && ! $quotes && ! $apostr ) {
            $QUOTED++;
        }
        elsif ( !$QUOTED && !$COMMENTED && $token eq "[" && ! $ignore ) {
            $COMMENTED++;
            $log->debug("quote level changed to $COMMENTED");
            next TOKEN;
        }
        elsif ( !$QUOTED && $COMMENTED && $token eq "]" && ! $ignore ) {
            $COMMENTED--;
            next TOKEN;
        }
        elsif ($QUOTED
            && !$COMMENTED
            && $token eq "'"
            && substr( $string, $i, 2 ) ne "''" && ! $quotes && ! $apostr )
        {
            $QUOTED--;
        }
        if ( !$QUOTED && $token eq ' ' && ! $whitespace ) {
            next TOKEN;
        }
        $decommented .= $token unless $COMMENTED;
        if ( !$QUOTED && !$COMMENTED && substr( $string, $i, 1 ) eq ';' ) {
            push @trees, $decommented;
            $decommented = '';
        }

    }
    $log->debug("removed comments, split on tree descriptions");
    $log->debug("found ".scalar(@trees)." tree descriptions");
    return @trees;
}

=begin comment

 Type    : Parser
 Title   : _parse_string($string)
 Usage   : my $tree = $newick->_parse_string($string);
 Function: Creates a populated Bio::Phylo::Forest::Tree object from a newick
           string.
 Returns : A Bio::Phylo::Forest::Tree object.
 Args    : $string = a newick tree description

=end comment

=cut

sub _parse_string {
    my ( $self, $string ) = @_;
    my $fac = $self->_factory;
    $self->_logger->debug("going to parse tree string '$string'");
    my $tree      = $fac->create_tree;
    my $remainder = $string;
    my $token;
    my @tokens;
    while ( ( $token, $remainder ) = $self->_next_token($remainder) ) {
        last if ( !defined $token || !defined $remainder );
        $self->_logger->debug("fetched token '$token'");

        push @tokens, $token;
    }
    my $i;
    for ( $i = $#tokens ; $i >= 0 ; $i-- ) {
        last if $tokens[$i] eq ';';
    }
    my $root = $fac->create_node;
    $tree->insert($root);
    $self->_parse_node_data( $root, @tokens[ 0 .. ( $i - 1 ) ] );
    $self->_parse_clade( $tree, $root, @tokens[ 0 .. ( $i - 1 ) ] );
    return $tree;
}

sub _parse_clade {
    my ( $self, $tree, $root, @tokens ) = @_;
    my $fac = $self->_factory;
    $self->_logger->debug("recursively parsing clade '@tokens'");
    my ( @clade, $depth, @remainder );
  TOKEN: for my $i ( 0 .. $#tokens ) {
        if ( $tokens[$i] eq '(' ) {
            if ( not defined $depth ) {
                $depth = 1;
                next TOKEN;
            }
            else {
                $depth++;
            }
        }
        elsif ( $tokens[$i] eq ',' && $depth == 1 ) {
            my $node = $fac->create_node;
            $root->set_child($node);
            $tree->insert($node);
            $self->_parse_node_data( $node, @clade );
            $self->_parse_clade( $tree, $node, @clade );
            @clade = ();
            next TOKEN;
        }
        elsif ( $tokens[$i] eq ')' ) {
            $depth--;
            if ( $depth == 0 ) {
                @remainder = @tokens[ ( $i + 1 ) .. $#tokens ];
                my $node = $fac->create_node;
                $root->set_child($node);
                $tree->insert($node);
                $self->_parse_node_data( $node, @clade );
                $self->_parse_clade( $tree, $node, @clade );
                last TOKEN;
            }
        }
        push @clade, $tokens[$i];
    }
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
    
    if ( defined($tail[-1]) and $tail[-1] =~ /(\[.+\])$/ and scalar @tail != 1 ) {
        my $anno = $1;
        $self->_logger->info("discarding branch comment $anno");
        $tail[-1] =~ s/\Q$anno\E//;
    }    

    # name only
    if ( scalar @tail == 1 ) {
        $node->set_name( $tail[0] );
    }
    elsif ( scalar @tail == 2 ) {
        $node->set_branch_length( $tail[-1] );
    }
    elsif ( scalar @tail == 3 ) {
        $node->set_name( $tail[0] );
        $node->set_branch_length( $tail[-1] );
    }
}

sub _next_token {
    my ( $self, $string ) = @_;
    $self->_logger->debug("tokenizing string '$string'");
    my $ignore          = $self->_args->{'-ignore_comments'};
    my $QUOTED          = 0;
    my $COMMENTED       = 0;
    my $token           = '';
    my $TOKEN_DELIMITER = qr/[():,;]/;
  TOKEN: for my $i ( 0 .. length($string) ) {
        $token .= substr( $string, $i, 1 );
        $self->_logger->debug("growing token: '$token'");
        
	# detect apostrophe as ' between two letters
	my $prev = $i > 0 ? substr( $string, $i-1, 1 ) : 0;
	my $next = $i< length($string) ? substr( $string, $i+1, 1 ) : 0;
	my $apostr =  substr( $string, $i, 1 ) eq "'" && $prev=~/[a-z]/i && $next=~/[a-z]/i;
        $self->_logger->debug("detected apostrophe") if $apostr;

        # if -ignore_comments was specified the string can still contain comments 
        # that can contain token delimiters, so we still need to track
        # whether we are inside a comment        
        if ( $ignore && $token =~ /\[$/ ) {
        	$COMMENTED++;
        }
        if ( $ignore && $token =~ /\]$/ ) {
        	$COMMENTED--;
        	next TOKEN;
        }                
        if ( !$QUOTED && !$COMMENTED && $token =~ $TOKEN_DELIMITER ) {
            my $length = length($token);
            if ( $length == 1 ) {
                $self->_logger->debug("single char token: '$token'");
                return $token, substr( $string, ( $i + 1 ) );
            }
            else {
                $self->_logger->debug(
                    sprintf( "range token: %s",
                        substr( $token, 0, $length - 1 ) )
                );
                return substr( $token, 0, $length - 1 ),
                  substr( $token, $length - 1, 1 )
                  . substr( $string, ( $i + 1 ) );
            }
        }
        if ( !$QUOTED && !$COMMENTED && substr( $string, $i, 1 ) eq "'" && ! $apostr ) {
            $QUOTED++;
        }
        elsif ($QUOTED && !$COMMENTED
            && substr( $string, $i, 1 ) eq "'"
            && substr( $string, $i, 2 ) ne "''" && ! $apostr)
        {
            $QUOTED--;
        }
    }
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The newick parser is called by the L<Bio::Phylo::IO> object.
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
