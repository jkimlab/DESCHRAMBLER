package Bio::Phylo::Unparsers::Fasta;
use strict;
use warnings;
use base 'Bio::Phylo::Unparsers::Abstract';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw':objecttypes looks_like_object';

=head1 NAME

Bio::Phylo::Unparsers::Fasta - Serializer used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

Definition lines for each FASTA records are either (first choice) created from
the generic 'fasta_def_line' annotation which can be manipulated like so:

 $datum->set_generic( 'fasta_def_line' => $line )
 
So you can retrieve it by calling:

 my $line = $datum->get_generic('fasta_def_line');

Alternatively the name of the $datum is used, or, lacking that, the name
of the associated taxon, if any.

=cut

sub _to_string {
    my $self = shift;
    my $obj  = $self->{'PHYLO'};
    my $matrix;
    eval { $matrix = $obj if looks_like_object $obj, _MATRIX_; };
    if ($@) {
        undef($@);
        eval {
            ($matrix) = @{ $obj->get_matrices }
              if looks_like_object $obj, _PROJECT_;
        };
        if ( $@ or not $matrix ) {
            throw 'ObjectMismatch' => 'Invalid object!';
        }
    }
    my $string = '';
    for my $seq ( @{ $matrix->get_entities } ) {
        my $taxon_name = '';
        if ( my $taxon = $seq->get_taxon ) {
            $taxon_name = $taxon->get_name;
        }
        my $name = $seq->get_generic('fasta_def_line') || $seq->get_name || $taxon_name;
        my $def  = '>' . $name . "\n";
        my $char = $seq->get_char;
        my $n = 80;    # $n is group size.
        my @groups = unpack "a$n" x (length($char)/$n) . "a*", $char;
        $string .= $def . join("\n", @groups) . "\n";
    }
    return $string;
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The fasta unparser is called by the L<Bio::Phylo::IO> object.
Look there to learn how to create phylip formatted files.

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
