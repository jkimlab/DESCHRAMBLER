package Bio::Phylo::PhyloWS::Client;
use strict;
use warnings;
use base 'Bio::Phylo::PhyloWS';
use Bio::Phylo::IO 'parse';
use Bio::Phylo::Factory;
use Bio::Phylo::Util::Logger;
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT 'looks_like_hash';
use Bio::Phylo::Util::Dependency qw'LWP::UserAgent XML::Twig';
{
    my @fields = \( my (%ua) );
    my $logger = Bio::Phylo::Util::Logger->new;
    my $fac    = Bio::Phylo::Factory->new;

=head1 NAME

Bio::Phylo::PhyloWS::Client - Base class for phylogenetic web service clients

=head1 SYNOPSIS

 #!/usr/bin/perl
 use strict;
 use warnings;
 use Bio::Phylo::Factory;
 
 my $fac = Bio::Phylo::Factory->new;
 my $client = $fac->create_client( 
 	'-base_uri'  => 'http://nexml-dev.nescent.org/nexml/phylows/tolweb/phylows/',
 	'-authority' => 'uBioNB',
 );
 my $desc = $client->get_query_result( 
	'-query'     => 'Homo sapiens', 
	'-section'   => 'taxon',
 );
 for my $res ( @{ $desc->get_entities } ) {
	my $proj = $client->get_record( '-guid' => $res->get_guid );
	print $proj->to_nexus, "\n";
 }

=head1 DESCRIPTION

This is the base class for clients connecting to services that implement 
the PhyloWS (L<http://evoinfo.nescent.org/PhyloWS>) recommendations.

=head1 METHODS

=head2 CONSTRUCTOR

=over

=item new()

 Type    : Constructor
 Title   : new
 Usage   : my $phylows = Bio::Phylo::PhyloWS::Client->new( -url => $url );
 Function: Instantiates Bio::Phylo::PhyloWS::Client object
 Returns : a Bio::Phylo::PhyloWS::Client object 
 Args    : Required: -url => $url
           Optional: any number of setters. For example,
 		   Bio::Phylo::PhyloWS->new( -name => $name )
 		   will call set_name( $name ) internally

=cut

    sub new {

        # could be child class
        my $class = shift;

        # go up inheritance tree, eventually get an ID
        my $self = $class->SUPER::new(@_);

        # store a user agent object to delegate http stuff to
        if ( not $self->get_ua ) {
            my $ua = LWP::UserAgent->new;
            $ua->timeout(300);
            $ua->env_proxy;
            $self->set_ua($ua);
        }
        return $self;
    }
    my $ua = sub {
        return $ua{ shift->get_id };
    };

=back

=head2 MUTATORS

=over

=item set_ua()

Assigns a new L<LWP::UserAgent> object that the client uses to communicate 
with the service. Typically you don't have to use this unless you have to
configure a user agent for things such as proxies. Normally a default user
agent is instantiated when the client constructor is called.

 Type    : Mutator
 Title   : set_ua
 Usage   : $obj->set_ua( LWP::UserAgent->new );
 Function: Assigns another (non-default) user agent
 Returns : $self
 Args    : An LWP::UserAgent object (or child class)

=cut

    sub set_ua {
    	my $self = shift;
    	my $arg = shift;
    	if ( UNIVERSAL::isa( $arg, 'LWP::UserAgent' ) ) {
    	    $ua{ $self->get_id } = $arg;	
    	}
    	else {
    	    throw 'BadArgs' => "'$arg' is not an LWP::UserAgent";	
    	}
    	return $self;
    }

=back

=head2 ACCESSORS

=over

=item get_query_result()

Gets search query result

 Type    : Accessor
 Title   : get_query_result
 Usage   : my $res = $obj->get_query_result( -query => $query );
 Function: Returns Bio::Phylo::PhyloWS::Description object
 Returns : A string
 Args    : Required: -query => $cql_query
           Optional: -section, -recordSchema

=cut

    my $rss_handler = sub {
		my ($create_method,$self,$twig,$elt) = @_;
		my %known = (
			'title'       => '-name',
			'description' => '-desc',
			'link'        => '-link',
		);
		my  ( %args, @meta );
		for my $child ( $elt->children ) {
			my $tag = $child->tag;
			if ( my $key = $known{$tag} ) {
				$args{$key} = $child->text;
			}
			elsif ( $tag ne 'items' ) {
				my $predicate = $tag;
				my ( $prefix, $namespace, $object );
				if ( $tag =~ /(.+?):/ ) {
					$prefix = $1;
					$namespace = $child->namespace;
				}
				if ( ! ( $object = $child->att('rdf:about') ) ) {
					$object = $child->text;
				}
				push @meta, $fac->create_meta(
					'-namespaces' => { $prefix => $namespace },
					'-triple'     => { $predicate => $object },
				);
			}
		}
		my $obj = $fac->$create_method(%args);
		$obj->add_meta($_) for @meta;
		my $pre  = $self->get_url_prefix;
		my $link = $obj->get_link;
		$link =~ s/^\Q$pre\E(.+?)?/$1/i;
		$obj->set_guid($link);
		return $obj;
    };

    sub get_query_result {
        my $self = shift;
        $logger->debug("going to get query result");
        if ( my %args = looks_like_hash @_ ) {
			
			# these fields need to be set first before get_url returns
			# a sane response
			$self->set_query( $args{'-query'} || throw 'BadArgs' => "Need query argument" );
			$logger->debug("set query ".$args{'-query'});
			
			$self->set_section( $args{'-section'} || 'taxon' );
			$self->set_format( 'rss1' );
			my $rs  = $args{'-recordSchema'}  || $args{'-section'} || 'taxon';
			my $url = $self->get_url( '-recordSchema' => $rs );
			$url =~ s/&amp;/&/g;
			$logger->debug("URL: $url");
			
			# do the request
			my $response = $ua->($self)->get($url);
			if ( $response->is_success ) {
				$logger->debug("request succeeded");
				my $content = $response->content;
				use Data::Dumper;
				print Dumper($response);
				
				$self->set_section($rs);
				my $desc = $self->parse_query_result($content);
				if ( $@ ) {
					$logger->fatal("Error fetching from $url");
					$logger->fatal($content);
					throw 'NetworkError' => $@;		    
				}
				else {
					$self->set_section( $args{'-section'} || 'taxon' );
					return $desc;   
				}		
			}
			else {
				throw 'NetworkError' => "Error fetching from $url: " 
					. $response->status_line;
			}
        }
    }

=item parse_query_result()

Parses a raw query result

 Type    : Accessor
 Title   : parse_query_result
 Usage   : my $desc = $obj->parse_query_result($content);
 Function: Parses a raw query result
 Returns : Bio::Phylo::PhyloWS::Resource::Description object
 Args    : Raw result content

=cut
    
    sub parse_query_result {
    	my ( $self, $content ) = @_;
		my $desc;
		eval {
			XML::Twig->new(
				'TwigHandlers' => {
					'channel' => sub {
						$desc = $rss_handler->('create_description',$self,@_);
					},
					'item' => sub {
						my $res = $rss_handler->('create_resource',$self,@_);
						$desc->insert($res);
					},
				}
			)->parse($content);
		};
		return $desc;    
    }

=item get_record()

Gets a PhyloWS database record

 Type    : Accessor
 Title   : get_record
 Usage   : my $rec = $obj->get_record( -guid => $guid );
 Function: Gets a PhyloWS database record
 Returns : Bio::Phylo::Project object
 Args    : Required: -guid => $guid

=cut

    sub get_record {
        my $self = shift;
        if ( my %args = looks_like_hash @_ ) {
		    $self->set_guid( $args{'-guid'} || throw 'BadArgs' => "Need -guid argument" );
			$self->set_query();
            my $url = $self->get_url( '-format' => 'nexml' );
            $logger->debug($url);
            return parse(
                '-format'     => 'nexml',
                '-url'        => $url,
                '-as_project' => 1,
            );
        }
    }

=item get_ua()

Gets the underlying L<LWP::UserAgent> object that the client uses to communicate with the service

 Type    : Accessor
 Title   : get_ua
 Usage   : my $ua = $obj->get_ua;
 Function: Gets user agent
 Returns : LWP::UserAgent object
 Args    : None

=cut

    sub get_ua { $ua{ shift->get_id } }

    sub _cleanup {
        my $self = shift;
        my $id   = $self->get_id;
        for my $field (@fields) {
            delete $field->{$id};
        }
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
