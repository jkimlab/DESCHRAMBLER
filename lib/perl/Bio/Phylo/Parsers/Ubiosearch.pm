package Bio::Phylo::Parsers::Ubiosearch;
use strict;
use warnings;
use base 'Bio::Phylo::Parsers::Abstract';
use Bio::Phylo::Util::Dependency 'XML::Twig';
use Bio::Phylo::Util::Logger;

=head1 NAME

Bio::Phylo::Parsers::Ubiosearch - Parser used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module parses the XML that is returned by a uBio namebank search. An
example of such a record is here: L<http://www.ubio.org/webservices/examples/namebank_search.xml>

The parser creates a single L<Bio::Phylo::Taxa> object to which the metadata
on the search (time, date stamp, uBio version number) are attached. This taxa
object is then populated with L<Bio::Phylo::Taxa::Taxon> objects that are
annotated with the metadata for each search result.

=cut

my $DCID = 'dc:identifier';
my $DCSUB = 'dc:subject';

my %predicate_for = (
    'namebankID'     => $DCID,
    'packageName'    => $DCSUB,
    'rankName'       => 'gla:rank',
);

my %object_for = (
    'namebankID' => sub { 'urn:lsid:ubio.org:namebank:' . shift },
);

my %namespaces = (
    'dc'   => 'http://purl.org/dc/elements/1.1/',
    'ubio' => 'urn:lsid:ubio.org:predicates:',
    'gla'  => 'urn:lsid:lsid.zoology.gla.ac.uk:predicates:',
);

my $logger = Bio::Phylo::Util::Logger->new;

sub _parse {
    my $self = shift;
    my $fac  = $self->_factory;
    my $taxa = $fac->create_taxa( '-namespaces' => \%namespaces );
    XML::Twig->new(
        'twig_handlers' => {
            'serviceData' => sub {
                my ( $twig, $elt ) = @_;
                $self->_elt_handler( $elt, $taxa );
            },
            'value' => sub {
                my ( $twig, $elt ) = @_;
                my $taxon = $fac->create_taxon;
                $self->_elt_handler( $elt, $taxon );
                
                # copy record title to name field
                if ( my $name = $taxon->get_meta_object($DCSUB) ) {
                    $taxon->set_name( $name );
                    $logger->info("Copied $DCSUB to name field: $name");
                }
                else {
                    $logger->warn("Couldn't find $DCSUB");
                }
                
                # copy namebank LSID to guid field and ubio:namebankIdentifier,
                # set local namebank ID as value of dc:identifier
                if ( my ($meta) = @{ $taxon->get_meta($DCID) } ) {
                    $logger->info("Meta object for $DCID is $meta");
                    my $lsid = $meta->get_object;
                    $taxon->add_meta( $fac->create_meta(
                        '-triple' => { 'ubio:namebankIdentifier' => $lsid }    
                    ) );
                    my $id = $lsid;
                    $id =~ s/.+://;
                    $taxon->set_guid( $id );
                    $taxon->remove_meta( $meta );
                    $taxon->add_meta( $fac->create_meta( '-triple' => { $DCID => $id } ) );
                    $logger->info("Processed $DCID annotation: $id");                    
                }
                else {
                    $logger->warn("Couldn't find $DCID annotation");
                }
                $taxa->insert($taxon);
            }
        }
    )->parse( $self->_string );
    return $taxa;
}

sub _elt_handler {
    my ( $self, $elt, $obj ) = @_;
    for my $child ( $elt->children ) {
        my ( $key, $val ) = ( $child->tag, $child->text );
        my $predicate = $predicate_for{$key} || "ubio:${key}";
        my $object = $object_for{$key} ? $object_for{$key}->($val) : $val;
        $logger->debug("Setting annotation $predicate => $object");
        $obj->add_meta(
            $self->_factory->create_meta(
                '-triple' => { $predicate => $object }
            )
        )
    }    
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The uBio search result parser is called by the L<Bio::Phylo::IO> object.
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
