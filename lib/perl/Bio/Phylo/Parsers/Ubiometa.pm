package Bio::Phylo::Parsers::Ubiometa;
use base 'Bio::Phylo::Parsers::Abstract';
use Bio::Phylo::Util::Dependency 'XML::Twig';
use Bio::Phylo::NeXML::Entities '/entities/';
use strict;
use warnings;

=head1 NAME

Bio::Phylo::Parsers::Ubiometa - Parser used by Bio::Phylo::IO, no serviceable
parts inside

=head1 DESCRIPTION

This module parses RDF metadata for uBio namebank records. An example of such a
record is here: L<http://www.ubio.org/authority/metadata.php?lsid=urn:lsid:ubio.org:namebank:2481730>

The parser creates a single L<Bio::Phylo::Taxa::Taxon> object to which all
metadata are attached as L<Bio::Phylo::NeXML::Meta> objects. This taxon is
embedded in a taxa block, or optionally in a L<Bio::Phylo::Project> object
if the C<-as_project> flag was provided to the call to C<parse()>.

=cut

# prettify the output, make sure there is a name and description
sub _rss_prettify {
    my ( $self, $taxon ) = @_;
    $taxon->set_name( $taxon->get_meta_object('dc:subject') );
    $taxon->set_desc(
        $taxon->get_meta_object('dc:type')
        . ', Rank: '
        . $taxon->get_meta_object('gla:rank')
        . ', Status: '
        . $taxon->get_meta_object('ubio:lexicalStatus')
    );     
}

# copy the local part of the LSID to the guid field and dc:identifier
sub _copy_identifiers {
    my ( $self, $elt, $obj ) = @_;
    if ( $elt->att('rdf:about') =~ /(\d+)$/ ) {
        my $namebankID = $1;
        $obj->set_guid($namebankID);
        $obj->add_meta( $self->_factory->create_meta(
            '-triple' => { 'dc:identifier' => $namebankID }                    
        ) );
    }    
}

# attach namespaces from element to object
sub _copy_namespaces {
    my ( $self, $elt, $obj ) = @_;
    for my $att_name ( $elt->att_names ) {
        if ( $att_name =~ /xmlns:(\S+)/ ) {
            my $prefix = $1;
            my $ns = $elt->att($att_name);
            $obj->set_namespaces( $prefix => $ns );
        }
    }    
}

sub _parse {
    my $self = shift;
    my $fac  = $self->_factory;
    my $taxa = $fac->create_taxa;
    XML::Twig->new(
        'twig_handlers' => {
            'rdf:RDF' => sub {
                my ( $twig, $elt ) = @_;
                my $taxon = $fac->create_taxon;
                
                # attach namespaces from root element to taxon
                $self->_copy_namespaces($elt,$taxon);
                
                # attach metadata
                my ($child) = $elt->children('rdf:Description');
                for my $meta_elt ( $child->children ) {
                    my $val = encode_entities( $meta_elt->att('rdf:resource') || $meta_elt->text );
                    my $key = $meta_elt->tag;
                    if ( $key eq 'dc:identifier' ) {
                        $key = 'ubio:namebankIdentifier';
                    }
                    $taxon->add_meta( $fac->create_meta(
                        '-triple' => { $key => $val }                    
                    ) );
                }
                
                # parse the rdf:about lsid, use the numerical part as
                # guid and dc:identifier                
                $self->_copy_identifiers($child,$taxon);
                
                # prettify the output, make sure there is a name and description
                $self->_rss_prettify($taxon);
                
                $taxa->insert($taxon);
            }
        }
    )->parse($self->_string);
    return $taxa;
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The uBio metadata parser is called by the L<Bio::Phylo::IO> object.
Look there to learn more about parsing.

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
