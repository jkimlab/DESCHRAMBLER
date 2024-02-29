package Bio::Phylo::PhyloWS;
use strict;
use warnings;
use base 'Bio::Phylo::NeXML::Writable';
use Bio::Phylo::Util::CONSTANT 'looks_like_hash';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::Dependency 'URI::URL';
use Bio::Phylo::Util::Logger;

our %MIMETYPE = (
    'nexml'    => 'application/xml;charset=UTF-8',
    'yaml'     => 'application/x-yaml;charset=UTF-8',
    'rdf'      => 'application/rdf+xml;charset=UTF-8',
    'rss1'     => 'application/rdf+xml;charset=UTF-8',
    'phyloxml' => 'application/xml;charset=UTF-8',
    'nexus'    => 'text/plain',
    'json'     => 'text/javascript',
    'newick'   => 'text/plain',
    'fasta'    => 'text/plain',
);
{
    my @fields = \( my (%format, %section, %query, %authority) );
    my $logger = Bio::Phylo::Util::Logger->new;

=head1 NAME

Bio::Phylo::PhyloWS - Base class for phylogenetic web services

=head1 SYNOPSIS

 # no direct usage, used by child classes

=head1 DESCRIPTION

This is the base class for clients and service that implement the PhyloWS
(L<http://evoinfo.nescent.org/PhyloWS>) recommendations. This base class
isn't used directly, it contains useful methods that are inherited by
its children.

=head1 METHODS

=head2 MUTATORS

=over

=item set_format()

Sets invocant's preferred serialization format.

 Type    : Mutator
 Title   : set_format
 Usage   : $obj->set_format($format);
 Function: Assigns an object's serialization format.
 Returns : Modified object.
 Args    : Argument must be a string.

=cut

    sub set_format {
        my ( $self, $base ) = @_;
        $format{ $self->get_id } = $base;
        return $self;
    }

=item set_section()

Sets invocant's section ("table") to operate on, e.g. 'taxon', 'tree', etc.

 Type    : Mutator
 Title   : set_section
 Usage   : $obj->set_section($section);
 Function: Sets section
 Returns : Modified object.
 Args    : Argument must be a string.

=cut

    sub set_section {
        my ( $self, $section ) = @_;
        $section{ $self->get_id } = $section;
        return $self;
    }

=item set_query()

Sets invocant's query parameter

 Type    : Mutator
 Title   : set_query
 Usage   : $obj->set_query($query);
 Function: Assigns an object's query.
 Returns : Modified object.
 Args    : Argument must be a string.

=cut

    sub set_query {
		my ( $self, $query ) = @_;
		$query{ $self->get_id } = $query;
		return $self;
    }

=item set_authority()

Sets the authority prefix (e.g. TB2) for the implementing service

 Type    : Mutator
 Title   : set_authority
 Usage   : $obj->set_authority('TB2');
 Function: Sets authority prefix
 Returns : $self
 Args    : String
 Comments:

=cut

    sub set_authority {
        my ( $self, $auth ) = @_;
        $authority{ $self->get_id } = $auth;
		return $self;
    }

=back

=head2 ACCESSORS

=over

=item get_url()

Gets invocant's url. This constructs the full url including section, authority
prefix, uid and query string.

 Type    : Accessor
 Title   : get_url
 Usage   : my $url = $obj->get_url;
 Function: Returns the object's url.
 Returns : A string
 Args    :

=cut

    my $build_query_string = sub {
        my ( $uri, %args ) = @_;
        while ( my ( $key, $value ) = each %args ) {
            if ( $key =~ m/^-/ ) {
                $key =~ s/^-//;
                if ( $uri =~ m/\?/ ) {
                    if ( $uri !~ m/[&\?]$/ ) {
                        $uri .= '&amp;';
                    }
                    $uri .= "${key}=${value}";
                }
                else {
                    $uri .= '?' . "${key}=${value}";
                }
            }
        }
        return $uri;
    };

    sub get_url {
        my $self = shift;
        my $uri  = $self->get_base_uri;
		my %args;
	
		# add format flag, if one is specified
		if ( my $format = $self->get_format ) {
			$args{'-format'} = $format;
		}
	    
		# the section prefix, e.g. 'taxon'
		$uri .= '/' if $uri !~ m|/$|;
		$uri .= $self->get_section . '/';
	
		# the interaction is a query
		if ( my $query = $self->get_query ) {
			$logger->info("Constructing query URL");
			$uri .= $self->get_action;
			my $kw = $self->get_query_keyword;
			$args{'-'.$kw} = $query;
		}
	
		# the interaction is a record lookup
		else {
			$logger->info("Constructing lookup URL");
			$uri .= $self->get_authority . ':' . $self->get_guid;
		}
	    
        return $build_query_string->($uri,%args,@_);
    }

=item get_action()

Returns any appropriate action verb that needs to be composed into the URL.
By default this is C<find>, but child classes can override this to something
else (or nothing at all).

 Type    : Accessor
 Title   : get_action
 Usage   : my $action = $obj->get_action;
 Function: Returns the object's url action.
 Returns : A string
 Args    :

=cut

	sub get_action { 'find' }

=item get_query_keyword()

Returns any appropriate action verb that needs to be composed into the query
string as the keyword to identify the search string.
By default this is C<query>, but child classes can override this to something
else (or nothing at all).

 Type    : Accessor
 Title   : get_query_keyword
 Usage   : my $keyword = $obj->get_query_keyword;
 Function: Returns the object's query keyword
 Returns : A string
 Args    :

=cut

	sub get_query_keyword { 'query' }

=item get_url_prefix()

Constructs a url prefix to which an ID can be appended in order to resolve
to some resource. Combined with get_authority these form the moving parts
for how PhyloWS services could be plugged into the L<http://lsrn.org>
system.

 Type    : Accessor
 Title   : get_url_prefix
 Usage   : my $prefix = $obj->get_url_prefix;
 Function: Returns the object's url prefix.
 Returns : A string
 Args    :

=cut

    sub get_url_prefix {
        my $self = shift;
        my $prefix = $self->get_base_uri;
        $prefix .= '/' if $prefix !~ m|/$|;
        $prefix .= $self->get_section . '/' . $self->get_authority . ':';
        return $prefix;
    }

=item get_format()

Gets invocant's preferred serialization format

 Type    : Accessor
 Title   : get_format
 Usage   : my $format = $obj->get_format;
 Function: Returns the object's preferred serialization format
 Returns : A string
 Args    : None

=cut

    sub get_format {
        return $format{ shift->get_id };
    }

=item get_authority()

Gets the authority prefix (e.g. TB2) for the implementing service

 Type    : Accessor
 Title   : get_authority
 Usage   : my $auth = $obj->get_authority;
 Function: Gets authority prefix
 Returns : String
 Args    : None
 Comments:

=cut

    sub get_authority {
        return $authority{ shift->get_id };
    }

=item get_section()

Gets invocant's section ("table") to operate on, e.g. 'taxon', 'tree', etc.

 Type    : Accessor
 Title   : get_section
 Usage   : my $section = $obj->get_section;
 Function: Gets section
 Returns : String
 Args    : None

=cut

    sub get_section {
	return $section{ shift->get_id };
    }

=item get_query()

Gets invocant's query parameter

 Type    : Accessor
 Title   : get_query
 Usage   : my $query = $obj->get_query;
 Function: Retrieves an object's query.
 Returns : Query
 Args    : None

=cut

    sub get_query {
	return $query{ shift->get_id };
    }


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
