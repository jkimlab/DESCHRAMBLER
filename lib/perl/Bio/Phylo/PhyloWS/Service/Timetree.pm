package Bio::Phylo::PhyloWS::Service::Timetree;
use strict;
use warnings;
use utf8;
use base 'Bio::Phylo::PhyloWS::Service';
use Bio::Phylo::IO 'parse';
use Bio::Phylo::Factory;
use Bio::Phylo::Util::Logger;
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw'looks_like_hash looks_like_instance';
use Bio::Phylo::Util::Dependency qw'LWP::UserAgent HTML::TreeBuilder::XPath URI::Escape';
use constant URL => 'http://timetree.org/time_query.php?';
use constant NCBI => 'http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=';

# http://localhost/nexml/service/timetree/phylows/tree/find?query=dcterms.identifier=9606%20and%20dcterms.identifier=9597
{
    my $fac    = Bio::Phylo::Factory->new;
    my $logger = Bio::Phylo::Util::Logger->new;
    
    $logger->VERBOSE(
        '-level' => 4,
        '-class' => 'Bio::Phylo::Parsers::Timetree',
    );
    
    my $parse_html = sub {
        my ( $content ) = @_;
        my $tree = HTML::TreeBuilder::XPath->new;
        $tree->parse_content($content);
        my ($title) = $tree->findnodes(q{//td[@class='titleBlack']/strong});
        my $str = $title->as_text;
        $str =~ s/^(\d+\.\d+).*$/$1/;
        return $str;
    };
    
    my $get_query_result_raw = sub {
        my ( $self, $taxon_a, $taxon_b ) = @_;
        my $lua = LWP::UserAgent->new;
        my $url = URL . "taxon_a=${taxon_a}&taxon_b=${taxon_b}";
        my $response = $lua->get($url);
        if ( $response->is_success ) {
            my $content = $response->content;
            utf8::decode($content);
            return $content;
        }
        else {
            throw 'NetworkError' => $response->status_line;
        }
    };
    
    my $create_project = sub {
        my ($name_a,$name_b) = @_;
        my $project = $fac->create_project;
        my $forest  = $fac->create_forest;
        my $taxa    = $fac->create_taxa;        
        my $taxona  = $fac->create_taxon(
            '-name' => $name_a,
            '-link' => NCBI . $name_a,
            '-guid' => $name_a,
        );        
        my $taxonb  = $fac->create_taxon(
            '-name' => $name_b,
            '-link' => NCBI . $name_b,
            '-guid' => $name_b,
        );
        
        $project->insert( $taxa, $forest );
        $taxa->insert( $taxona, $taxonb );
        $forest->set_taxa($taxa);
        return ( $project, $taxona, $taxonb, $forest );
    };

=head1 NAME

Bio::Phylo::PhyloWS::Service::Timetree - PhyloWS service wrapper for Timetree

=head1 SYNOPSIS

 # inside a CGI script:
 use CGI;
 use Bio::Phylo::PhyloWS::Service::Timetree;

 my $cgi = CGI->new;
 my $service = Bio::Phylo::PhyloWS::Service::Timetree->new( '-url' => $url );
 $service->handle_request($cgi);

=head1 DESCRIPTION

This is an example implementation of a PhyloWS service. The service
wraps around the timetree web site (using screen scraping) and returns 
project objects that include a tree for every search result.

=head1 METHODS

=head2 ACCESSORS

=over

=item get_query_result()

Gets a phylows cql query result

 Type    : Accessor
 Title   : get_query_result
 Usage   : my $result = $obj->get_query_result( $query );
 Function: Gets a query result 
 Returns : Bio::Phylo::Project
 Args    : Required: $query

=cut

    sub get_query_result {
        my ( $self, $query ) = @_;
        my ( $taxon_a, $taxon_b );
        
        # clean up CQL query
        $query = URI::Escape::uri_unescape($query);
        if ( $query =~ m/^\D*(\d+)\D+(\d+)/ ) {
            ( $taxon_a, $taxon_b ) = ( $1, $2 );    
        }                

        # download timetree result
        my $content = $get_query_result_raw->( $self, $taxon_a, $taxon_b );

        # parse timetree result
        my $age = $parse_html->( $content );

        # populate project
        my ( $project, $taxona, $taxonb, $forest ) = $create_project->($taxon_a,$taxon_b);
        my $tree = $fac->create_tree;
        my $tree_root = $fac->create_node;
        
        my $node_a = $fac->create_node(
            '-branch_length' => $age,
            '-parent'        => $tree_root,
            '-taxon'         => $taxona,
            '-name'          => $taxona->get_name,
            '-link'          => NCBI . $taxona->get_name,
            '-guid'          => $taxona->get_name,
        );
        
        my $node_b = $fac->create_node(
            '-branch_length' => $age,
            '-parent'        => $tree_root,
            '-taxon'         => $taxonb,
            '-name'          => $taxonb->get_name,
            '-link'          => NCBI . $taxonb->get_name,
            '-guid'          => $taxonb->get_name,
        );
        
        $tree->insert( $tree_root, $node_a, $node_b );
        $forest->insert($tree);

        # return project
        return $project;
    }

=item get_supported_formats()

Gets an array ref of supported formats

 Type    : Accessor
 Title   : get_supported_formats
 Usage   : my @formats = @{ $obj->get_supported_formats };
 Function: Gets an array ref of supported formats
 Returns : [ qw(nexml nexus newick html) ]
 Args    : NONE

=cut

    sub get_supported_formats { [qw(nexml nexus newick html)] }

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
           appropriate page on the http://timetree.org website

=cut

    sub get_redirect {
        my ( $self, $cgi ) = @_;
        if ( $cgi->param('format') eq 'html' ) {
            my $query = $cgi->param('query');
            $query = URI::Escape::uri_unescape($query);
            my ( $taxon_a, $taxon_b );
            if ( $query =~ m/^\D*(\d+)\D+(\d+)/ ) {
                ( $taxon_a, $taxon_b ) = ( $1, $2 );    
            }            
            my $url = URL . "taxon_a=${taxon_a}&taxon_b=${taxon_b}";
            return $url;
        }
        return;
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
