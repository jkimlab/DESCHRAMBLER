package Bio::Phylo::PhyloWS::Service::UbioNameBank;
use strict;
use warnings;
use base 'Bio::Phylo::PhyloWS::Service';
use constant UBIO_BASE => 'http://www.ubio.org/';
use constant UBIO_SRCH => UBIO_BASE . 'browser/search.php?search_all=';
use constant UBIO_NMBK => UBIO_BASE . 'browser/details.php?namebankID=';
use constant RDFURL => UBIO_BASE . 'authority/metadata.php?lsid=urn:lsid:ubio.org:namebank:';
use constant UBIOWS => UBIO_BASE . 'webservices/service.php?function=namebank_search&searchName=%s&sci=1&vern=1&keyCode=%s';
use Bio::Phylo::Util::Dependency qw'XML::Twig LWP::UserAgent';
use Bio::Phylo::Util::CONSTANT qw'looks_like_hash';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::Logger;
use Bio::Phylo::IO 'parse';
use Bio::Phylo::Factory;

{

    my $fac = Bio::Phylo::Factory->new;
    my $logger = Bio::Phylo::Util::Logger->new;

=head1 NAME

Bio::Phylo::PhyloWS::Service::UbioNameBank - PhyloWS service wrapper for uBio
NameBank records

=head1 SYNOPSIS

 # inside a CGI script:
 use CGI;
 use Bio::Phylo::PhyloWS::Service::UbioNameBank;

 # obtain a key code from http://www.ubio.org/index.php?pagename=form
 # and define it as an environment variable:
 $ENV{'UBIO_KEYCODE'} = '******';
 my $cgi = CGI->new;
 my $service = Bio::Phylo::PhyloWS::Service::UbioNameBank->new( '-base_uri' => $url );
 $service->handle_request($cgi);

=head1 DESCRIPTION

This is an example implementation of a PhyloWS service. The service
wraps around some of the uBio XML services described at
L<http://www.ubio.org/index.php?pagename=xml_services>.

Record lookups for this service return project objects
that capture the RDF metadata for a single NameBank record as semantic
annotations to a taxon object. An example of the sort of metadata that
can be expected is shown here:
L<http://www.ubio.org/authority/metadata.php?lsid=urn:lsid:ubio.org:namebank:2481730>

Queries on this service run namebank searches and return project objects
that capture the NameBank search XML (an example is shown here:
L<http://www.ubio.org/webservices/examples/namebank_search.xml>)
as semantic annotations to taxon objects.

URLs to this service that specify format=html in the query string redirect
to web pages on the uBio site at L<http://www.ubio.org>. The redirect
URLs either point to search result listings or to NameBank record pages,
depending on whether the redirect is for a record query or a record lookup,
respectively.

=head1 UBIO KEY CODES

B<Some functionality of this service requires a key code to the uBio API>. Such
key codes can be obtained from L<http://www.ubio.org/index.php?pagename=form>.
When deploying this service on a web server (e.g. as shown in the SYNOPSIS) this
code must be provided in an environment variable called C<UBIO_KEYCODE>.

=head1 METHODS

=head2 ACCESSORS

=over

=item get_record()

Gets a uBio namebank record by its id

 Type    : Accessor
 Title   : get_record
 Usage   : my $record = $obj->get_record( -guid => $guid );
 Function: Gets a uBio namebank record by its id
 Returns : Bio::Phylo::Project
 Args    : Required: -guid => $guid
 Comments: For the $guid argument, this method only cares
           whether the last part of the argument is a series
           of integers, which are understood to be namebank
           identifiers

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
                    '-format'     => 'ubiometa',
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

=item get_authority()

Gets the authority prefix (e.g. TB2) for the implementing service

 Type    : Authority
 Title   : get_authority
 Usage   : my $auth = $obj->get_authority;
 Function: Gets authority prefix
 Returns : 'uBioNB'
 Args    : None

=cut

    sub get_authority { 'uBioNB' }

=item get_supported_formats()

Gets an array ref of supported formats

 Type    : Accessor
 Title   : get_supported_formats
 Usage   : my @formats = @{ $obj->get_supported_formats };
 Function: Gets an array ref of supported formats
 Returns : [ qw(nexml nexus html json) ]
 Args    : NONE

=cut
    
    sub get_supported_formats { [ 'nexml', 'html', 'json', 'nexus', 'rss1' ] }

=item get_redirect()

Gets a redirect URL if relevant

 Type    : Accessor
 Title   : get_redirect
 Usage   : my $url = $obj->get_redirect;
 Function: Gets a redirect URL if relevant
 Returns : String
 Args    : $cgi
 Comments: This method is called by handle_request so that
           services can 303 redirect a record lookup to 
           another URL. By default, this method returns 
           undef (i.e. no redirect), but if this implementation
           is called to handle a request that specifies 
           'format=html' the request is forwarded to the
           appropriate page on the http://www.ubio.org website

=cut
    
    sub get_redirect {
        my ( $self, $cgi ) = @_;
        if ( $cgi->param('format') eq 'html' ) {
            if ( my $query = $cgi->param('query') ) {
                return UBIO_SRCH . $query;
            }
            else {
                my $path_info = $cgi->path_info;
                if ( $path_info =~ m/(\d+)$/ ) {
                    my $namebank_id = $1;
                    $logger->info("Getting html redirect for id: $namebank_id");
                    return UBIO_NMBK . $namebank_id;
                }
                else {
                    throw 'BadArgs' => "Not a parseable guid: '$path_info'";
                }
            }
        }
        return;
    }

=item get_query_result()

Gets a query result and returns it as a project object

 Type    : Accessor
 Title   : get_query_result
 Usage   : my $proj = $obj->get_query_result($query);
 Function: Gets a query result
 Returns : Bio::Phylo::Project
 Args    : A simple query string for a namebank search
 Comments: The $query is a simple CQL level 0 term-only query

=cut
    
    sub get_query_result {
        my ( $self, $query ) = @_;
        throw 'System' => "No UBIO_KEYCODE env var" unless $ENV{'UBIO_KEYCODE'};
        my $prefix = $self->get_url_prefix;
        
        # do the search query
        my $proj = parse(
            '-url'        => sprintf( UBIOWS, $query, $ENV{'UBIO_KEYCODE'} ),
            '-format'     => 'ubiosearch',
            '-as_project' => 1,
        );
        
        # construct links relative to the current service
        my ($taxa) = @{ $proj->get_taxa };
        $taxa->visit( sub {
            my $taxon = shift;
            $taxon->set_link( $prefix . $taxon->get_guid );
        } );
        
        return $proj;
    }

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