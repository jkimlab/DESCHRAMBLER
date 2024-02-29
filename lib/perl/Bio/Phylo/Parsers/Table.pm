package Bio::Phylo::Parsers::Table;
use strict;
use warnings;
use base 'Bio::Phylo::Parsers::Abstract';

=head1 NAME

Bio::Phylo::Parsers::Table - Parser used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module is used to import data and taxa from plain text files or strings.
The following additional argument must be used in the call
to L<Bio::Phylo::IO|Bio::Phylo::IO>:

 -type => (one of [DNA|RNA|STANDARD|PROTEIN|NUCLEOTIDE|CONTINUOUS])

In addition, these arguments may be used to indicate line separators (default
is "\n") and field separators (default is "\t"):

 -fieldsep => '\t',
 -linesep  => '\n'

=cut

sub _parse {
    my $self = shift;
    my $fh   = $self->_handle;
    my $fac  = $self->_factory;
    my $type = $self->_args->{'-type'};
    local $/ = $self->_args->{'-linesep'} || "\n";
    my $sep    = $self->_args->{'-fieldsep'} || "\t";
    my $regex  = qr/$sep/;
    my $matrix = $fac->create_matrix( '-type' => $type );
    while (<$fh>) {
        chomp;
        my ( $name, @char ) = split $regex, $_;
        $matrix->insert(
            $fac->create_datum(
                '-type' => $type,
                '-name' => $name,
                '-char' => \@char,
            )
        );
    }
    return $matrix;
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The table parser is called by the L<Bio::Phylo::IO|Bio::Phylo::IO> object.
Look there to learn how to parse tab- (or otherwise) delimited matrices.

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
