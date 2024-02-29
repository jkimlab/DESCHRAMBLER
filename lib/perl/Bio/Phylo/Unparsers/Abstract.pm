package Bio::Phylo::Unparsers::Abstract;
use strict;
use warnings;
use base 'Bio::Phylo::IO';
use Bio::Phylo::Util::Logger;
my $logger = Bio::Phylo::Util::Logger->new;

=head1 NAME

Bio::Phylo::Unparsers::Abstract - Superclass for unparsers used by Bio::Phylo::IO

=head1 DESCRIPTION

This package is subclassed by all other packages within Bio::Phylo::Unparsers::.*.
There is no direct usage.

=cut

sub _logger { $logger }

sub _new {
    my $class = shift;
    my $self  = {};
    if (@_) {
        my %opts = @_;
        for my $key ( keys %opts ) {
            my $localkey = uc $key;
            $localkey =~ s/-//;
            unless ( ref $opts{$key} ) {
                $self->{$localkey} = uc $opts{$key};
            }
            else {
                $self->{$localkey} = $opts{$key};
            }
        }
    }
    bless $self, $class;
    return $self;
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The parsers are called by the L<Bio::Phylo::IO> object.
Look there for examples.

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
