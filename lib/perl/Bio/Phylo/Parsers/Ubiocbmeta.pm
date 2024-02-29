package Bio::Phylo::Parsers::Ubiocbmeta;
use base 'Bio::Phylo::Parsers::Abstract';
use Bio::Phylo::Util::Dependency 'XML::Twig';
use Bio::Phylo::NeXML::Entities '/entities/';
use strict;
use warnings;

=head1 NAME

Bio::Phylo::Parsers::Ubiocbmeta - Parser used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module parses RDF metadata for uBio classification bank records. An example
of such a record is here:
L<http://www.ubio.org/authority/metadata.php?lsid=urn:lsid:ubio.org:classificationbank:11168417>

The parser creates a single L<Bio::Phylo::Taxa::Taxon> object to which all
metadata are attached as L<Bio::Phylo::NeXML::Meta> objects. This taxon is
embedded in a taxa block, or optionally in a L<Bio::Phylo::Project> object
if the C<-as_project> flag was provided to the call to C<parse()>.

=cut

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

# prettify the output, make sure there is a name and description
sub _rss_prettify {
    my ( $self, $obj ) = @_;
    $obj->set_name( $obj->get_meta_object('dc:title') );
    $obj->set_desc(
        'Rank: '
        . $obj->get_meta_object('gla:rank')
        . ', Classification: '
        . $obj->get_meta_object('ubio:classificationName')
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

# process annotation values: xml escape strings and urls, return
# child nodes as is
sub _process_value {
    my ( $self, $elt ) = @_;
    my $val;
    if ( $val = $elt->att('rdf:resource') ) {
        return encode_entities($val);
    }
    elsif ( ($val) = $elt->children('rdf:Seq') ) {
        return $val;
    }
    else {
        return encode_entities($elt->text);
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
                
                # $child contains all the metadata to parse
                my ($child) = $elt->children('rdf:Description');
                KEY: for my $meta_elt ( $child->children ) {
                    my $key = $meta_elt->tag;
                    next KEY if $key eq '#PCDATA';
                    
                    # process annotation value
                    my $val = $self->_process_value($meta_elt);                    
                    
                    # we will use the numerical part as dc:identifier
                    if ( $key eq 'dc:identifier' ) {
                        $key = 'ubio:classificationbankIdentifier';
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

The uBio classification bank metadata parser is called by the L<Bio::Phylo::IO>
object. Look there to learn more about parsing.

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
