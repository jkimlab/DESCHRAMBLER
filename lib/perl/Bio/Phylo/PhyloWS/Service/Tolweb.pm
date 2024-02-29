package Bio::Phylo::PhyloWS::Service::Tolweb;
use strict;
use warnings;
use base 'Bio::Phylo::PhyloWS::Service';
use Bio::Phylo::IO 'parse';
use Bio::Phylo::Factory;
use Bio::Phylo::Util::Logger;
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw'looks_like_hash :namespaces';
use Bio::Phylo::Util::Dependency qw'XML::Twig';
use constant TOL_BASE => 'http://tolweb.org/';
use constant WEB_SRCH => TOL_BASE . 'tree/home.pages/searchTOL?taxon=';
use constant XML_NODE => TOL_BASE . 'onlinecontributors/app?service=external&page=xml/TreeStructureService&page_depth=1&node_id=';
use constant XML_SRCH => TOL_BASE . 'onlinecontributors/app?service=external&page=xml/GroupSearchService&group=';

{
    my $fac    = Bio::Phylo::Factory->new;
    my $logger = Bio::Phylo::Util::Logger->new;

=head1 NAME

Bio::Phylo::PhyloWS::Service::Tolweb - PhyloWS service wrapper for Tree of Life

=head1 SYNOPSIS

 # inside a CGI script:
 use CGI;
 use Bio::Phylo::PhyloWS::Service::Tolweb;

 my $cgi = CGI->new;
 my $service = Bio::Phylo::PhyloWS::Service::Tolweb->new( '-url' => $url );
 $service->handle_request($cgi);

=head1 DESCRIPTION

This is an example implementation of a PhyloWS service. The service
wraps around the Tree of Life XML services described at
L<http://tolweb.org/tree/home.pages/downloadtree.html>.

When doing a record lookup this service returns project objects
that include the focal node (identified by its PhyloWS ID) and the 
nearest child and parent nodes that have web pages.

When querying, this service returns a project object with one taxa
block containing zero or more taxon objects that matched the query.

When URLs to this service specify format=html in the query string, this
service returns redirect URLs to web pages on the Tree of Life web project
site at L<http://tolweb.org>. The redirect URLs either point to search result
listings or to node pages, depending on whether the redirect is for a record
query or a record lookup, respectively.

=head1 METHODS

=head2 ACCESSORS

=over

=item get_record()

Gets a tolweb record by its id

 Type    : Accessor
 Title   : get_record
 Usage   : my $record = $obj->get_record( -guid => $guid );
 Function: Gets a tolweb record by its id
 Returns : Bio::Phylo::Project
 Args    : Required: -guid => $guid
 Comments: For the $guid argument, this method only cares
           whether the last part of the argument is a series
           of integers, which are understood to be the node
           identifier in the Tree of Life

=cut

    sub get_record {
        my $self = shift;
        if ( my %args = looks_like_hash @_ ) {
            if ( $args{'-guid'} && $args{'-guid'} =~ m|(\d+)$| ) {
                my $tolweb_id = $1;
                $logger->info("Getting nexml record for id: $tolweb_id");
                
                # fetch and parse the output
                my $proj = parse(
                    '-format'     => 'tolweb',
                    '-url'        => XML_NODE . $tolweb_id,
                    '-as_project' => 1,
                );
                $proj->set_link($self->get_url);
                $proj->set_name('Tree of Life web project lookup service');
                $proj->set_desc("Results for ID $tolweb_id");
                
                # post processing to make nice local links back to this service
                my $prefix = $self->get_url_prefix;
                my ($forest) = @{ $proj->get_forests };
                my ($tree) = @{ $forest->get_entities };
                my $taxa = $forest->make_taxa;
                $proj->insert($taxa);
                $tree->visit( sub {
                    my $node = shift;
                    $node->set_link( $prefix . $node->get_guid );
                } );                
                $taxa->visit( sub {
                    my $taxon = shift;
                    my ($node) = @{ $taxon->get_nodes };
                    $taxon->set_link($node->get_link);
                    $taxon->set_desc($node->get_desc);
                    $taxon->add_meta($_) for @{ $node->get_meta };
                } );
                
                # done!
                return $proj;
            }
            else {
                throw 'BadArgs' => "Not a parseable guid: '$args{-guid}'";
            }
        }
    }

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
           appropriate page on the http://tolweb.org website

=cut

    sub get_redirect {
        my ( $self, $cgi ) = @_;
        if ( $cgi->param('format') eq 'html' ) {
            if ( my $query = $cgi->param('query') ) {
                return WEB_SRCH . $query;
            }
            else {
                my $path_info = $cgi->path_info;
                if ( $path_info =~ m/(\d+)$/ ) {
                    my $tolweb_id = $1;
                    $logger->info("Getting html redirect for id: $tolweb_id");
                    return TOL_BASE . $tolweb_id;
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
 Args    : A simple query string for a group search
 Comments: The $query is a simple CQL level 0 term-only query

=cut

    sub get_query_result {
        my ( $self, $query ) = @_;
        my $proj = $fac->create_project(
            '-link'       => $self->get_url,
            '-namespaces' => { 'dc' => _NS_DC_ },
            '-desc'       => 'Results for query: ' . $self->get_query,
            '-name'       => 'Tree of Life web project PhyloWS search service',
        );
        my $taxa   = $fac->create_taxa;
        my $prefix = $self->get_url_prefix;
        $proj->insert( $taxa );        
        XML::Twig->new(
            'twig_handlers' => {
                'NODE' => sub {
                    my ( $twig, $node_elt ) = @_;
                    my $id = $node_elt->att('ID');
                    my ($name_elt) = $node_elt->children('NAME');
                    $taxa->insert(
                        $fac->create_taxon(
                            '-name' => $name_elt->text,
                            '-guid' => $id,
                            '-link' => $prefix . $id,
                        )->add_meta(
                            $fac->create_meta( '-triple' => { 'dc:identifier' => $id } )
                        )
                    );
                }
            }
        )->parseurl( XML_SRCH . $query );
        return $proj;
    }

=item get_supported_formats()

Gets an array ref of supported formats

 Type    : Accessor
 Title   : get_supported_formats
 Usage   : my @formats = @{ $obj->get_supported_formats };
 Function: Gets an array ref of supported formats
 Returns : [ qw(nexml nexus newick html json phyloxml rss1) ]
 Args    : NONE

=cut

    sub get_supported_formats { [qw(nexml nexus newick html json phyloxml rss1)] }

=item get_authority()

Gets the authority prefix (e.g. TB2) for the implementing service

 Type    : Abstract Accessor
 Title   : get_authority
 Usage   : my $auth = $obj->get_authority;
 Function: Gets authority prefix
 Returns : 'ToL'
 Args    : None

=cut

    sub get_authority { 'ToL' }

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
