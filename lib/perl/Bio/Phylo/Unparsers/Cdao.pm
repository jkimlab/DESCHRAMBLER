package Bio::Phylo::Unparsers::Cdao;
use strict;
use warnings;
use base 'Bio::Phylo::Unparsers::Abstract';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw':objecttypes looks_like_object';
use File::Temp 'tempfile';

=head1 NAME

Bio::Phylo::Unparsers::Cdao - Serializer used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module generates an RDF representation of a Bio::Phylo::Project object,
using terms from the CDAO ontology: L<http://www.evolutionaryontology.org/cdao>.

The module depends on the xsltproc utility being present in the PATH of your
system: L<http://xmlsoft.org/XSLT/xsltproc2.html>. If your xsltproc is in a
different location, you can optionally specify it with the -xsltproc => (path)
argument to the unparse() call.

Unless an additional -xslt => (file|url) argument is passed to the unparse()
call, xsltproc will try to download the stylesheet that transforms NeXML to
RDF from this location: L<http://nexml.org/nexml/xslt/nexml2cdao.xsl>. This
means that, if you don't give the -xslt argument, your computer must be
connected to the internet.

=cut

sub _to_string {
    my $self = shift;
    my $project = $self->{'PHYLO'};
    if ( looks_like_object $project, _PROJECT_ ) {
        my $stylesheet = $self->{'XSLT'}   || $ENV{'NEXML_ROOT'} ? $ENV{'NEXML_ROOT'} . '/xslt/nexml2cdao.xsl' : 'http://nexml.org/nexml/xslt/nexml2cdao.xsl';
        my $xsltproc = $self->{'XSLTPROC'} || 'xsltproc';
        my ( $fh, $file ) = tempfile();
        print $fh $project->to_xml;
        my $result = `$xsltproc $stylesheet $file`;
        if ( $? ) {
            throw 'System' => "Error running xsltproc - exited with $?";
        }
        else {
            return $result;
        }
    }
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The cdao unparser is called by the L<Bio::Phylo::IO> object.
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