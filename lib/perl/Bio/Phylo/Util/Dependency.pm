package Bio::Phylo::Util::Dependency;

use strict;
use warnings;

BEGIN {
    use Bio::Phylo::Util::Exceptions 'throw';
    use Bio::Phylo::Util::CONSTANT 'looks_like_class';

    sub import {
        my $class = shift;
        looks_like_class $_ for @_;
    }
}
1;
__END__

=head1 NAME

Bio::Phylo::Util::Dependency - Utility class for importing external
dependencies. No serviceable parts inside.

=head1 DESCRIPTION

This package is for internal usage by Bio::Phylo, to help import optional 3rd
party dependencies (and report their absence) in a uniform way.

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

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
