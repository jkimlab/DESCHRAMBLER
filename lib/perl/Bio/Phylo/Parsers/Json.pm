package Bio::Phylo::Parsers::Json;
use strict;
use warnings;
use base 'Bio::Phylo::Parsers::Abstract';
use Bio::Phylo::IO 'parse';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::Dependency 'Bio::Phylo::NeXML::XML2JSON';

=head1 NAME

Bio::Phylo::Parsers::Json - Parser used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module is used to import NeXML data that was re-formatted as JSON, using
the mapping implemented by L<XML::XML2JSON>. This module is experimental in that
complex NeXML-to-JSON mapped strings may fail to yield valid NeXML (and,
consequently, valid Bio::Phylo objects) in the round trip. The reason for this
is that the XML2JSON omits xmlns declarations in its JSON output. We try to work
around this here by re-introducing the default namespaces, but if any additional
ones were present in the original NeXML (e.g. to specify namspaces for metadata
predicates) these can't be reconstructed. In addition, the JSON that XML2JSON
produces doesn't preserve element order. We try to be lenient about this when
parsing the intermediate NeXML, though it is actually invalid.

=cut

sub _parse {
    my $self = shift;
    my $fh   = $self->_handle;
    my $json = do { local $/; <$fh> };
    
    # perhaps not happy about prolog?
    $json =~ s/"\@encoding":"\S+?","\@version":"1.0",//;
    my $conf = Bio::Phylo::NeXML::XML2JSON->new;
    my $xml  = $conf->json2xml($json);
    my $fac  = $self->_factory;
    my $proj = $fac->create_project;
    my $ns   = $proj->get_namespaces;
    for my $pre ( keys %{ $ns } ) {
        my $uri = $ns->{$pre};
        if ( $xml !~ /xmlns:$pre/ ) {
            $xml =~ s/<nex:nexml /<nex:nexml xmlns:$pre="$uri" /;
        }
    }
    return @{ parse( '-format' => 'nexml', '-string' => $xml ) };
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The json parser is called by the L<Bio::Phylo::IO|Bio::Phylo::IO> object.
Look there to learn how to parse data using Bio::Phylo.

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
