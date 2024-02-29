package Bio::Phylo::PhyloWS::Resource;
use strict;
use warnings;
use base qw'Bio::Phylo::PhyloWS Bio::Phylo::NeXML::Writable';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw'_DESCRIPTION_ _RESOURCE_ /looks_like/';
use Bio::Phylo::Util::Logger;
{
    my @fields;
    my $logger = Bio::Phylo::Util::Logger->new;

=head1 NAME

Bio::Phylo::PhyloWS::Resource - Represents a PhyloWS web resource

=head1 SYNOPSIS

 # no direct usage

=head1 DESCRIPTION

This class represents a resource on the web that implements the PhyloWS
recommendations.

=head1 METHODS

=head2 CONSTRUCTOR

=over

=item new()

 Type    : Constructor
 Title   : new
 Usage   : my $phylows = Bio::Phylo::PhyloWS::Resource->new( -guid => $guid );
 Function: Instantiates Bio::Phylo::PhyloWS::Resource object
 Returns : a Bio::Phylo::PhyloWS::Resource object 
 Args    : Required: -guid => $guid
           Optional: any number of setters. For example,
 		   Bio::Phylo::PhyloWS::Resource->new( -format => $format )
 		   will call set_format( $format ) internally

=cut

    sub new {
        my $self = shift->SUPER::new( '-tag' => 'item', @_ );
		if ( not $self->get_link ) {
			my $has_guid_and_auth = $self->get_guid && $self->get_authority;
			if ( not $has_guid_and_auth and not $self->get_query ) {
				throw 'BadArgs' => 'Need -guid and -authority or -query argument';
			}
			if ( not $self->get_section ) {
				throw 'BadArgs' => 'Need -section argument';
			}
		}
        return $self;
    }

=back

=head2 TESTS

=over

=item is_identifiable()

Tests if invocant has an xml id attribute

 Type    : Test
 Title   : is_identifiable
 Usage   : if ( $obj->is_identifiable ) {
              # do something
           }
 Function: Tests if invocant has an xml id attribute
 Returns : FALSE
 Args    : NONE

=cut

    sub is_identifiable { 0 }

=back

=head2 SERIALIZERS

=over

=item to_xml()

Serializes resource to RSS1.0 XML representation

 Type    : Serializer
 Title   : to_xml()
 Usage   : print $obj->to_xml();
 Function: Serializes object to RSS1.0 XML string
 Returns : String 
 Args    : None
 Comments:

=cut

    #   <item rdf:about="${baseURL}/${phyloWSPath}?format=nexus">
    #     <title>Nexus file</title>
    #     <link>${baseURL}/${phyloWSPath}?format=nexus</link>
    #     <description>A Nexus serialization of the resource</description>
    #     <dc:format>text/plain</dc:format>
    #   </item>
    sub to_xml {
        my $self = shift;
        my $tag  = $self->get_tag;
	
		# create the link URL
		my $link;
		if ( $link = $self->get_link ) {
			$logger->info("Using link field: $link");
		}
		else {	    
			$link = $self->get_url;
			$logger->info("Computed URL: $link");
		}
	
		# generating default elements
        my $xml = '<' . $tag . ' rdf:about="' . $link . '">';
        $xml .= '<title>' . $self->get_name . '</title>';
        $xml .= '<link>' . $link . '</link>';
        $xml .= '<description>' . $self->get_desc . '</description>';
		
		# specify output format
        if ( my $format = $self->get_format ) {
            $xml .= '<dc:format>' . $Bio::Phylo::PhyloWS::MIMETYPE{$format} . '</dc:format>';
        }
		
		# serialize additional annotations
		for my $meta ( @{ $self->get_meta } ) {
			my $predicate = $meta->get_predicate;
			my $object = $meta->get_object;
			if ( $object =~ /http:/ or $object =~ /urn:/ ) {
				$xml .= "<$predicate rdf:resource=\"$object\"/>";
			}
			elsif ( ref $object ) {
				my @methods = qw(to_xml toString sprint _as_string code xmlify as_xml dump_tree as_XML);
				SERIALIZER: for my $method (@methods) {
					  if ( looks_like_implementor( $object, $method ) ) {
						  $xml .= "<$predicate>";
						  $xml .= $object->$method;
						  $xml .= "</$predicate>";
						  last SERIALIZER;
					  }
				  }
			}
			else {
				$xml .= "<$predicate>$object</$predicate>";
			}
		}
		
		# done!
        $xml .= '</' . $tag . '>';
        return $xml;
    }
	
    sub _container { _DESCRIPTION_ }
    sub _type      { _RESOURCE_ }

    sub _cleanup {
        my $self = shift;
        my $id   = $self->get_id;
        delete $_->{$id} for @fields;
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
