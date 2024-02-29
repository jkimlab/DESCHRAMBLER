package Bio::Phylo::Util::OptionalInterface;
use strict;
use warnings;
use Bio::Phylo::Util::CONSTANT 'looks_like_class';
use Bio::Phylo::Util::Logger;
my $logger = Bio::Phylo::Util::Logger->new;

sub import {
    my $class = shift;
    my ($caller) = caller;
    for my $iface (@_) {
        eval { looks_like_class $iface };
        if ($@) {
            $logger->info("Couldn't load optional interface $iface");
            undef($@);
        }
        else {
            eval "push \@${caller}::ISA, '$iface'";
            $logger->info("Added interface $iface to $caller");
        }
    }
}
1;
__END__

=head1 NAME

Bio::Phylo::Util::OptionalInterface - Utility class for managing optional
superclasses. No serviceable parts inside.

=head1 DESCRIPTION

This package is for optionally importing superclasses or interfaces and placing
them above the importing class in the inheritance tree. This is principally
used for managing the relationship with L<BioPerl>.

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
