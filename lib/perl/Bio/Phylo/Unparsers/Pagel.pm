package Bio::Phylo::Unparsers::Pagel;
use strict;
use warnings;
use base 'Bio::Phylo::Unparsers::Abstract';
use Bio::Phylo::Forest::Tree;

=head1 NAME

Bio::Phylo::Unparsers::Pagel - Serializer used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module unparses a Bio::Phylo data structure into an input file for
Discrete/Continuous/Multistate. The pagel file format (as it is interpreted
here) consists of:

=over

=item first line

the number of tips, the number of characters

=item subsequent lines

offspring name, parent name, branch length, character state(s).

=back

Here is an example of what the output might look like:

 4 2
 A,n1,0.000000,1,2
 B,n1,0.000000,1,2
 n1,n2,0.000000
 C,n2,0.000000,2,2
 n2,n3,0.000000
 D,n3,0.000000,2,1

To the unparse() function pass a tree object as value of the '-phylo'
argument. The tips in this tree must be linked to taxon objects, and
the taxon objects must be linked to datum objects whose character
state sequences are to be serialized.

During unparsing, the tree is randomly resolved, and branch lengths are
formatted to %f floats (i.e. integers, decimal point, integers).

The pagel module is called by the L<Bio::Phylo::IO> object, so
look there to learn about parsing and serializing in general.

=begin comment

 Type    : Unparser
 Title   : to_string($tree)
 Usage   : $pagel->to_string($tree);
 Function: Unparses a Bio::Phylo::Tree object into a pagel formatted string.
 Returns : SCALAR
 Args    : Bio::Phylo::Tree

=end comment

=cut

sub _to_string {
    my $self = shift;
    my $tree = $self->{'PHYLO'};
    $tree->resolve;
    my ( $charcounter, $string ) = 0;
    foreach my $node ( @{ $tree->get_entities } ) {
        if ( $node->get_parent ) {
            $string .= $node->get_internal_name . ','
              . $node->get_parent->get_internal_name . ',';
            if ( $node->get_branch_length ) {
                $string .= sprintf( "%f", $node->get_branch_length );
            }
            else {
                $string .= sprintf( "%f", 0 );
            }
            if ( $node->get_taxon ) {
                my $taxon = $node->get_taxon;
                foreach ( @{ $taxon->get_data } ) {
                    $string .= ',' . $_->get_char;
                    $charcounter++;
                }
            }
            $string .= "\n";
        }
        else {
            next;
        }
    }
    my $header = $tree->calc_number_of_terminals . " ";
    $header .= $charcounter / $tree->calc_number_of_terminals;
    $string = $header . "\n" . $string;
    return $string;
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The pagel unparser is called by the L<Bio::Phylo::IO> object.
Look there to learn how to create pagel formatted files.

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
