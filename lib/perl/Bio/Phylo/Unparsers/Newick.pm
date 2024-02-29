package Bio::Phylo::Unparsers::Newick;
use strict;
use warnings;
use base 'Bio::Phylo::Unparsers::Abstract';
use Bio::Phylo::Forest::Tree;
use Bio::Phylo::Util::CONSTANT ':objecttypes';

=head1 NAME

Bio::Phylo::Unparsers::Newick - Serializer used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module turns a tree object into a newick formatted (parenthetical) tree
description. It is called by the L<Bio::Phylo::IO> facade, don't call it
directly. You can pass the following additional arguments to the unparse
call:
	
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
	
	# array ref used to specify keys, which are embedded as key/value pairs (where
	# the value is obtained from $node->get_generic($key)) in comments, 
	# formatted depending on '-nhxstyle', which could be 'nhx' (default), i.e.
	# [&&NHX:$key1=$value1:$key2=$value2] or 'mesquite', i.e. 
	# [% $key1 = $value1, $key2 = $value2 ]
	-nhxkeys => [ $key1, $key2 ]	
	
	# if set, appends labels to internal nodes (names obtained from the same
	# source as specified by '-tipnames')
	-nodelabels => 1
	
	# specifies a formatting style / dialect
	-nhxstyle => one of (mesquite|nhx)
	
	# specifies a branch length sprintf number formatting template, default is %f
	-blformat => '%e'


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
    if ( $type == _TREE_ ) {
        my $root = $tree->get_root;
        my %args;
        for
          my $key (qw(TRANSLATE TIPNAMES NHXKEYS NODELABELS BLFORMAT NHXSTYLE))
        {
            if ( my $val = $self->{$key} ) {
                my $arg = '-' . lc($key);
                $args{$arg} = $val;
            }
        }
        return $root->to_newick(%args);
    }
    elsif ( $type == _FOREST_ ) {
        my $forest = $tree;
        my $newick = "";
        for my $tree ( @{ $forest->get_entities } ) {
            my $root = $tree->get_root;
            my %args;
            for my $key (
                qw(TRANSLATE TIPNAMES NHXKEYS NODELABELS BLFORMAT NHXSTYLE))
            {
                if ( my $val = $self->{$key} ) {
                    my $arg = '-' . lc($key);
                    $args{$arg} = $val;
                }
            }
            $newick .= $root->to_newick(%args) . "\n";
        }
        return $newick;
    }
    elsif ( $type == _PROJECT_ ) {
        my $project = $tree;
        my $newick  = "";
        for my $forest ( @{ $project->get_forests } ) {
            for my $tree ( @{ $forest->get_entities } ) {
                my $root = $tree->get_root;
                my %args;
                for my $key (
                    qw(TRANSLATE TIPNAMES NHXKEYS NODELABELS BLFORMAT NHXSTYLE))
                {
                    if ( my $val = $self->{$key} ) {
                        my $arg = '-' . lc($key);
                        $args{$arg} = $val;
                    }
                }
                $newick .= $root->to_newick(%args) . "\n";
            }
        }
        return $newick;
    }
}

=begin comment

 Type    : Unparser
 Title   : __to_string
 Usage   : $newick->__to_string($tree, $node);
 Function: Unparses the tree object into a newick string.
 Alias   :
 Returns : SCALAR
 Args    : A Bio::Phylo::Forest::Tree object. Optional: A Bio::Phylo::Forest::Node
           object, the starting point for recursion.

=end comment

=cut

{
    my $string = q{};

    #no warnings 'uninitialized';
    sub __to_string {
        my ( $self, $tree, $n ) = @_;
        if ( !$n->get_parent ) {
            if ( defined $n->get_branch_length ) {
                $string = $n->get_name . ':' . $n->get_branch_length . ';';
            }
            else {
                $string = defined $n->get_name ? $n->get_name . ';' : ';';
            }
        }
        elsif ( !$n->get_previous_sister ) {
            if ( defined $n->get_branch_length ) {
                $string = $n->get_name . ':' . $n->get_branch_length . $string;
            }
            else { $string = $n->get_name . $string; }
        }
        else {
            if ( defined $n->get_branch_length ) {
                $string =
                  $n->get_name . ':' . $n->get_branch_length . ',' . $string;
            }
            else { $string = $n->get_name . ',' . $string; }
        }
        if ( $n->get_first_daughter ) {
            $n      = $n->get_first_daughter;
            $string = ')' . $string;
            $self->__to_string( $tree, $n );
            while ( $n->get_next_sister ) {
                $n = $n->get_next_sister;
                $self->__to_string( $tree, $n );
            }
            $string = '(' . $string;
        }
    }
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The newick unparser is called by the L<Bio::Phylo::IO> object.
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
