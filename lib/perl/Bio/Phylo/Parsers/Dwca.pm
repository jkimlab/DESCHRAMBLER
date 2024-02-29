package Bio::Phylo::Parsers::Dwca;
use strict;
use warnings;
use base 'Bio::Phylo::Parsers::Abstract';
use File::Temp qw[tempfile];
use Bio::Phylo::Factory;
use Bio::Phylo::Util::Logger qw[:levels];
use Bio::Phylo::Util::Exceptions qw[throw];
use Bio::Phylo::Util::Dependency qw[XML::Twig];
use Bio::Phylo::Util::Dependency qw[Archive::Zip]; 
use Bio::Phylo::Util::CONSTANT qw[/looks_like/ :namespaces :objecttypes];

# because we use the dependency management module we don't import
# the status codes and constants, hence we call them explicitly here
my $AZ_OK = Archive::Zip::AZ_OK();
my $AZ_STREAM_END = Archive::Zip::AZ_STREAM_END();
my $COMPRESSION_STORED = Archive::Zip::COMPRESSION_STORED();

=head1 NAME

Bio::Phylo::Parsers::Dwca - Parser used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module parses standard Darwin Core Archive files as produced by GBIF 
(see: L<http://www.gbif.org/resource/80639>). The end result is a L<Bio::Phylo::Taxa>
object that has as many taxon objects in it as there are distinct C<dwc:scientificName>s
in the archive. For example, if the archive is for a single species there will thus be 
only one taxon object in the produced result. Each taxon object is annotated with as many 
C<dwc:Occurrence> records, instantiated as L<Bio::Phylo::NeXML::Meta> annotations, as 
there are occurrences for that species in the archive. In turn, nested in each of these 
annotations are the predicates and objects for that record.

Using this module, the contents of a Darwin Core Archive can be easily accessed and, for
example, prepared as input for MAXENT. Here is an example to show how this is done:

	use Bio::Phylo::IO 'parse';
	use Bio::Phylo::Util::CONSTANT ':objecttypes';

	# a set of fossil occurrences of th feral horse, Equus ferus Boddaert, 1785
	# this corresponds with data set doi:10.15468/dl.yyyhyn
	my $url = 'http://api.gbif.org/v1/occurrence/download/request/0074675-160910150852091.zip';

	# like every Bio::Phylo::IO module, we can parse directly from a web location
	my $proj = parse(
		'-format' => 'dwca',
		'-url'    => $url,
		'-as_project' => 1,
	);

	# write a CSV file with MAXENT header
	print "Species,Latitude,Longitude\n";
	for my $t ( @{ $proj->get_items(_TAXON_) } ) {
		my $name = $t->get_name;
		for my $m ( @{ $t->get_meta } ) {
			my $lat = $m->get_meta_object('dwc:decimalLatitude');
			my $lon = $m->get_meta_object('dwc:decimalLongitude');
			print "\"$name\",$lat,$lon\n";
		}
	}

=cut

sub _parse {
    my $self = shift;
    my $fh   = $self->_handle;
    my $fac  = $self->_factory;
	my $log  = $self->_logger;
	
	# have to make a seekable, local copy which we clean up afterwards
	my ( $h, $tempfile ) = tempfile();
	print $h $_ while <$fh>;
	close $h;
	my ( $core, $zip ) = _process_meta_xml( $tempfile );
	
	# start building return value
	my $taxa = $fac->create_taxa(
		'-namespaces' => {
			'dwc'     => _NS_DWC_,
			'dcterms' => _NS_DCTERMS_,
			'gbif'    => _NS_GBIF_,	
		}
	);
					
	# iterate over the file locations
	for my $file ( map { $_->text } $core->first_child('files')->children('location') ) {
	
		# process an occurrences file
		$log->info("going to read file $file");
		my @header;
		my $record = 1;
		my $fdel   = $core->att('fieldsTerminatedBy');
		my $ldel   = $core->att('linesTerminatedBy');		
		LINE: for my $line ( split /$ldel/, _read_zip_member( $zip => $file ) ) {			
			my @fields = split /$fdel/, $line;			
			if ( not @header and $core->att('ignoreHeaderLines') == 1 ) {
				@header = $self->_process_header( \@fields, $core, $taxa );
				next LINE;
			}
			$log->info("processing record " . $record++);
			$self->_process_record( \@fields, \@header, $taxa );
		}								
	}
	unlink $tempfile;
	return $taxa;
}

sub _process_meta_xml {
	my ( $infh ) = @_;

	# test reading
	my $zip = Archive::Zip->new;
	if ( $zip->read($infh) != $AZ_OK ) {
		throw 'FileError' => "$infh can't be read as ZIP file";	
	}
	
	# extract to string, parse in memory, validate type
	my $xml = XML::Twig->new;
	$xml->parse( _read_zip_member( $zip => 'meta.xml' ) );
	my $core = $xml->root->first_child('core');
	if ( $core->att('rowType') ne _NS_DWC_ . 'Occurrence' ) {
		throw 'FileError' => "$infh does not contain occurrences as core data";
	}
	return $core, $zip;
}

sub _process_record {
	my ( $self, $fields, $header, $taxa ) = @_;

	# process the line
	my $occ; 
	FIELD: for my $i ( 0 .. $#{ $fields } ) {
		next FIELD if $fields->[$i] =~ /^$/;
		
		# create and populate the container meta object										
		my $pre = $header->[$i]->{'prefix'};
		my $ns  = $header->[$i]->{'namespace'};
		my $p   = $pre . ':' . $header->[$i]->{'predicate'};
		if ( $occ ) {
			$occ->add_meta($self->_factory->create_meta('-triple'=>{$p=>$fields->[$i]}));
		}
		else {
			$occ = $self->_factory->create_meta( 
				'-triple' => {
					'dwc:Occurrence' => $self->_factory->create_meta( 
						'-triple'    => { $p => $fields->[$i] } 
					) 
				} 
			);
		}
		
		# fetch or create the taxon object
		if ( $p eq 'dwc:scientificName' ) {
			my $n = $fields->[$i];
			my $t = $taxa->get_by_name($n);
			if ( not $t ) {
				$self->_logger->info("creating taxon $n");
				$t = $self->_factory->create_taxon( '-name' => $n );
				$taxa->insert($t);
			}
			$t->add_meta($occ);					
		}
	}
}

sub _process_header {
	my ( $self, $fields, $core, $taxa ) = @_;
	my @header = @$fields;
	my $nsi = 1;
	$self->_logger->info("processing ".scalar(@header)." header columns");					
	
	# process the header fields
	for my $field ( $core->children('field') ) {
								
		# split the term in namespace and predicate
		my $term = $field->att('term');
		if ( $term =~ m/^(.+\/)([^\/]+)$/ ) {
			my ( $namespace, $predicate ) = ( $1, $2 );
			
			# generate namespace prefix
			my $p = $taxa->get_prefix_for_namespace($namespace);
			if ( not $p ) {
				$p = 'ns' . $nsi++;
				$taxa->set_namespaces( $p => $namespace );
				$self->_logger->info("created prefix $p for namespace $namespace");
			}
			
			# store namespace, predicate and prefix
			my $i = $field->att('index');
			$header[$i] = {
				'namespace' => $namespace,
				'predicate' => $predicate,
				'prefix'    => $p,
			};							
		}
	}
	return @header;
}

sub _read_zip_member {
	my ( $zip, $member_name ) = @_;
	
	# instantiate the named member object
	my $member = $zip->memberNamed( $member_name );
	$member->desiredCompressionMethod( $COMPRESSION_STORED );
	
	# rewind to the start of the member
	my $status = $member->rewindData();
	if ( $status != $AZ_OK ) {
		throw 'FileError' => "Can't rewind $member_name: $status";
	}
	
	# read buffered
	my $contents;
	while ( ! $member->readIsDone() ) {
		my ( $buffer_ref, $status ) = $member->readChunk();
		if ( $status != $AZ_OK && $status != $AZ_STREAM_END ) {
			throw 'FileError' => "Can't read chunk from $member_name: $status";
		}
		$contents .= $$buffer_ref
	}
	$member->endRead();
	return $contents;
}

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The dwca parser is called by the L<Bio::Phylo::IO|Bio::Phylo::IO> object.
Look there to learn how to parse data in general

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
