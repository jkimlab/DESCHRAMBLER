package Bio::Phylo::PhyloWS::Service;
use strict;
use warnings;
use base 'Bio::Phylo::PhyloWS';
use Bio::Phylo::Factory;
use Bio::Phylo::IO 'unparse';
use Bio::Phylo::Util::CONSTANT qw'looks_like_hash _HTTP_SC_SEE_ALSO_';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::Dependency 'URI::Escape';
use Bio::Phylo::Util::Logger;
{
    my $fac = Bio::Phylo::Factory->new;
    my $logger = Bio::Phylo::Util::Logger->new;

=head1 NAME

Bio::Phylo::PhyloWS::Service - Base class for phylogenetic web services

=head1 SYNOPSIS

 # inside a CGI script:
 use CGI;
 use Bio::Phylo::PhyloWS::Service::${child};

 my $service = Bio::Phylo::PhyloWS::Service::${child}->new( '-url' => $url );
 $service->handle_request(CGI->new);

=head1 DESCRIPTION

This is the base class for services that implement 
the PhyloWS (L<http://evoinfo.nescent.org/PhyloWS>) recommendations.
Such services should subclass this class and implement any relevant
abstract methods. Examples of this are L<Bio::Phylo::PhyloWS::Service::Tolweb>
and L<Bio::Phylo::PhyloWS::Service::Ubio>.

PhyloWS services are web services for phylogenetics that provide two types of
functionality:

=over

=item Record lookup

Services that implement record lookups are services that know how to process
URL requests of the form C</phylows/$object_type/$authority:$identifier?format=$format>,
where C<$object_type> is a string representing the type of object that is
returned, e.g. 'tree', 'matrix', 'taxon', etc., $authority is a naming authority
such as TB2 for TreeBASE2, $identifier is a local identifier for the object,
for example an accession number, and $format is a serialization format such as
'nexml'.

In order to provide this functionality, subclasses of this class must implement
a method called C<get_record> which is passed at least a named C<-guid> argument
that provides the local identifier. The C<get_record> method must return a
L<Bio::Phylo::Project> object, which is subsequently serialized in the requested
format by the C<handle_request> method provided here.

=item Record search

Services that implement record searches are services that know how to process
URL requests of the form C</phylows/$object_type/find?query=$query&format=$format>,
where $object_type is a string representing the type of object to search for,
$query is a CQL query (L<http://www.loc.gov/standards/sru/specs/cql.html>), and
$format is the serialization format in which the returned results are represented.

In order to provide this functionality, subclasses of this class must implement
a method called C<get_query_result>, which is passed the $query parameter and
which must return a L<Bio::Phylo::Project> object that combines the search
results (e.g. in a single taxa block for taxon searches).

CQL has different levels of support, services may only implement certain levels
of support. The example services L<Bio::Phylo::PhyloWS::Service::Tolweb>
and L<Bio::Phylo::PhyloWS::Service::Ubio> only proved Level 0, term-only support,
meaning that C<$query> is simply a term such as C<Homo+sapiens>.

=back

Child classes that implement some or all of the functionality described above
can subsequently be made operational on a web server by calling them from a
simple CGI script as shown in the SYNOPSIS section, where C<$child> must be
substituted by the actual class name of the child class (e.g. C<Tolweb>). The
C<$url> parameter that is passed to the constructor is usually simply the URI
of the CGI script, i.e. the environment variable C<$ENV{'SCRIPT_URI'}> under
most standard HTTP servers.

=head2 REQUEST HANDLER

=over

=item handle_request()

 Type    : Request handler
 Title   : handle_request
 Usage   : $service->handle_request($cgi);
 Function: Handles a service request
 Returns : prints out response and exits
 Args    : Required: a CGI.pm object

=cut

    sub _process_request_params {
        my ( $self, $cgi ) = @_;
        $self->set_format($cgi->param('format'));
        $self->set_query($cgi->param('query'));
        my $path = $cgi->path_info;
        my $section;
        if ( $path =~ m|/phylows/([a-z]+)/| ) {
            $section = $1;
            $self->set_section($section);
        }        
        if ( $path !~ /find/ && $path =~ m|/phylows/$section/(.+?):(.+)$|) {
            my ( $authority, $guid ) = ( $1, $2 );
            if ( $authority ne $self->get_authority ) {
                throw 'BadArgs' => ref($self) . " can't process identifiers "
                    ."with the $authority prefix";
            }
            $self->set_guid($guid);
        }
        if ( $path !~ /phylows/ ) {
            $logger->warn("'$path' is not a PhyloWS URL");
        }
    }
    
    sub handle_request {
        my ( $self, $cgi ) = @_;    # CGI.pm
        $self->_process_request_params($cgi);
            
        # there is a different address under the given conditions.
        # typically this is the case if there are web pages we can
        # point to.
        if ( my $redirect = $self->get_redirect($cgi) ) {                
            $logger->info("Redirecting to $redirect");
            print $cgi->redirect(
                '-uri'    => $redirect,
                '-status' => _HTTP_SC_SEE_ALSO_,
            );
        }
            
        # a serialization format has been specified
        if ( my $f = $self->get_format ) {
            $logger->info("Returning $f serialization");
            my %args = (
                '-format' => $f,
                '-phylo'  => $self->get_result,
            );
            if ( my $recordSchema = $cgi->param('recordSchema') ) {
                $args{'-recordSchema'} = $recordSchema;
            }
            print $cgi->header( $Bio::Phylo::PhyloWS::MIMETYPE{$f} );
            binmode STDOUT, ":utf8";
            print unparse(%args);
        }
        
        # no serialization format has been specified, returning a
        # resource description instead
        else {
            $logger->info("Returning RDF description");
            print $cgi->header( $Bio::Phylo::PhyloWS::MIMETYPE{'rdf'} );
            binmode STDOUT, ":utf8";
            print $self->get_description->to_xml;
        }
            
        exit(0);
    }

=back

=head2 ACCESSORS

=over

=item get_result()

Gets a phylows result, either a record lookup or a query result,
depending on the internal state of the service object

 Type    : Accessor
 Title   : get_result
 Usage   : my $proj = $obj->get_result;
 Function: Gets a phylows result
 Returns : Bio::Phylo::Project
 Args    : None
 Comments: 

=cut

    sub get_result {
        my $self = shift;
        my $name = ref($self);
        $name =~ s/.+://;
        my $proj;
        if ( my $id = $self->get_guid ) {
            $proj = $self->get_record( '-guid' => $id );
            $proj->set_name("$name PhyloWS record lookup service");
            $proj->set_desc("Results for ID: $id");
        }
        elsif ( my $query = $self->get_query ) {
            $proj = $self->get_query_result($query);
            $proj->set_name("$name PhyloWS query service");
            $proj->set_desc("Results for query: $query");
        }
        else {
            throw 'BadArgs' => "Neither GUID nor query provided!";
        }
        $proj->set_link($self->get_url);
        return $proj;
    }

=item get_record()

Gets a phylows record by its id

 Type    : Abstract Accessor
 Title   : get_record
 Usage   : my $record = $obj->get_record( -guid => $guid );
 Function: Gets a phylows record by its id
 Returns : Bio::Phylo::Project
 Args    : Required: -guid => $guid, 
           Optional: -format => $format
 Comments: This is an ABSTRACT method that needs to be implemented
           by a child class

=cut

    sub get_record {
        my $self = shift;
        throw 'NotImplemented' => 'Method get_record should be in '
          . ref($self)
          . ", but isn't";
    }

=item get_query_result()

Gets a phylows cql query result

 Type    : Abstract Accessor
 Title   : get_query_result
 Usage   : my $result = $obj->get_query_result( $query );
 Function: Gets a query result 
 Returns : Bio::Phylo::Project
 Args    : Required: $query
 Comments: This is an ABSTRACT method that needs to be implemented
           by a child class

=cut

    sub get_query_result {
        my $self = shift;
        throw 'NotImplemented' => 'Method get_query_result should be in '
          . ref($self)
          . ", but isn't";
    }

=item get_supported_formats()

Gets an array ref of supported formats

 Type    : Abstract Accessor
 Title   : get_supported_formats
 Usage   : my @formats = @{ $obj->get_supported_formats };
 Function: Gets an array ref of supported formats
 Returns : ARRAY
 Args    : NONE
 Comments: This is an ABSTRACT method that needs to be implemented
           by a child class

=cut

    sub get_supported_formats {
        my $self = shift;
        throw 'NotImplemented' => 'Method get_supported_formats should be in '
          . ref($self)
          . ", but isn't";
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
           undef (i.e. no redirect)

=cut

    sub get_redirect {
        my ( $self, $cgi ) = @_;
        return;
    }

=item get_description()

Gets an RSS1.0/XML representation of a phylows record

 Type    : Accessor
 Title   : get_description
 Usage   : my $desc = $obj->get_description;
 Function: Gets an RSS1.0/XML representation of a phylows record
 Returns : String
 Args    : None
 Comments: This method creates a representation of a single record
           (i.e. the service's base url + the record's guid)
           that can be serialized in whichever formats are 
           supported

=cut

    sub get_description {
        my $self = shift;
        
        # create constructor args
        my %args = (
            '-section'  => $self->get_section,
            '-base_uri' => $self->get_base_uri,
        );
        if ( $self->get_query ) {
            $args{'-query'} = $self->get_query;
        }
        else {
            $args{'-authority'} = $self->get_authority;
            $args{'-guid'} = $self->get_guid;
        }
        
        # create root description
        my $desc = $fac->create_description(
            '-name' => 'About ' . $self->get_url,
            '-desc' => 'Available serializations for this resource',
            %args,
        );
        
        # create available resources
        for my $format ( @{ $self->get_supported_formats } ) {
            $desc->insert(
                $fac->create_resource(
                    '-format' => $format,
                    '-name'   => $format,
                    '-desc'   => "A $format serialization of the resource",
                    %args
                )
            );
        }
        return $desc;
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
