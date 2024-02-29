package Bio::Phylo::PhyloWS::Service::UbioClassificationBank;
use strict;
use warnings;
use base 'Bio::Phylo::PhyloWS::Service';
use constant RDFURL => 'http://www.ubio.org/authority/metadata.php?lsid=urn:lsid:ubio.org:classificationbank:';
use Bio::Phylo::IO 'parse';
use Bio::Phylo::Util::Logger;
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw'/looks_like/ :objecttypes';


{
    my $logger = Bio::Phylo::Util::Logger->new;

=head1 NAME

Bio::Phylo::PhyloWS::Service::UbioClassificationBank - PhyloWS service wrapper
for uBio ClassificationBank records

=head1 SYNOPSIS

 # inside a CGI script:
 use CGI;
 use Bio::Phylo::PhyloWS::Service::UbioClassificationBank;

 # obtain a key code from http://www.ubio.org/index.php?pagename=form
 # and define it as an environment variable:
 $ENV{'UBIO_KEYCODE'} = '******';
 my $cgi = CGI->new;
 my $service = Bio::Phylo::PhyloWS::Service::UbioClassificationBank->new(
    '-base_uri' => $url
 );
 $service->handle_request($cgi);

=head1 DESCRIPTION

This is an example implementation of a PhyloWS service. The service
wraps around some of the uBio XML services described at
L<http://www.ubio.org/index.php?pagename=xml_services>.

Record lookups for this service return project objects
that capture the RDF metadata for a single ClassficationBank record as semantic
annotations to a taxon object. An example of the sort of metadata that
can be expected is shown here:
L<http://www.ubio.org/authority/metadata.php?lsid=urn:lsid:ubio.org:classificationbank:11168417>

=head1 METHODS

=head2 ACCESSORS

=over

=item get_record()

Gets a uBio classification bank record by its id

 Type    : Accessor
 Title   : get_record
 Usage   : my $record = $obj->get_record( -guid => $guid );
 Function: Gets a uBio classification bank record by its id
 Returns : Bio::Phylo::Project
 Args    : Required: -guid => $guid
 Comments: For the $guid argument, this method only cares
           whether the last part of the argument is a series
           of integers, which are understood to be classification
           bank identifiers

=cut


    sub get_record {
        my $self = shift;
        my $proj;
        if ( my %args = looks_like_hash @_ ) {
            if ( my $guid = $args{'-guid'} && $args{'-guid'} =~ m|(\d+)$| ) {
                
                # fetch and parse the metadata record
                my $namebank_id = $1;
                $logger->info("Going to fetch metadata for record $namebank_id");
                $proj = parse(
                    '-url'        => RDFURL . $namebank_id,
                    '-format'     => 'ubiocbmeta',
                    '-as_project' => 1,
                );

                # attach links back for rss
                my $prefix = $self->get_url_prefix;
                my ($taxa) = @{ $proj->get_taxa };
                $taxa->visit(sub{
                    my $taxon = shift;
                    $taxon->set_link( $prefix . $taxon->get_guid );
                })
            }
            else {
                throw 'BadArgs' => "No parseable GUID: '$args{-guid}'";
            }
        }
        return $proj;
    }
    
=item get_supported_formats()

Gets an array ref of supported formats

 Type    : Accessor
 Title   : get_supported_formats
 Usage   : my @formats = @{ $obj->get_supported_formats };
 Function: Gets an array ref of supported formats
 Returns : [ 'nexml', 'json', 'nexus', 'rss1' ]
 Args    : NONE

=cut    
    
    sub get_supported_formats { [ 'nexml', 'json', 'nexus', 'rss1' ] }

=item get_authority()

Gets the authority prefix (e.g. TB2) for the implementing service

 Type    : Authority
 Title   : get_authority
 Usage   : my $auth = $obj->get_authority;
 Function: Gets authority prefix
 Returns : 'uBioCB'
 Args    : None

=cut

    sub get_authority { 'uBioCB' }

=back

=cut

    # podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

Also see the manual: L<Bio::Phylo::Manual> and L<http://rutgervos.blogspot.com>

=head1 CITATION

If you use Bio::Phylo in published research, please cite it:

B<Rutger A Vos>, B<Jason Caravas>, B<Klaas Hartmann>, B<Mark A Jensen>
and B<Chase Miller>, 2011. Bio::Phylo - phyloinformatic analysis using Perl.
I<BMC Bioinformatics> B<12>:63.
L<http://dx.doi.org/10.1186/1471-2105-12-63>



=cut

}
1;