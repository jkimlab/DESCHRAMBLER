package Bio::Phylo::NeXML::XML2JSON;
use XML::XML2JSON;
use base 'XML::XML2JSON';
use strict;
use warnings;

=head1 NAME

Bio::Phylo::NeXML::XML2JSON - Helps convert NeXML to JSON, no serviceable parts inside

=cut

# As of 2017, the most recent version of XML::XML2JSON seems to have been
# abandoned with a bug in it. It assumes that hash keys are ordered, whereas
# more recent Perl versions randomize these. The upshot is that it starts
# peeling of hash keys from a data structure where it expects that the first
# key name will be a good name for an XML element (basically, a CURIE), and
# all subsequent keys will be attribute names (with a prefix, by default the
# '@' symbol). Because the hash keys are now randomized, this logic no longer
# works: sometimes it will try to instantiate an attribute as an element 
# name, which will fail. To overcome this problem we are applying a patch here.
sub _obj2dom_patch {
	my ( $Self, $Obj ) = @_;
	my $Version  = $Obj->{ $Self->{attribute_prefix} . 'version' }  || $Obj->{'version'}  || '1.0';
	my $Encoding = $Obj->{ $Self->{attribute_prefix} . 'encoding' } || $Obj->{'encoding'} || 'UTF-8';
	my $Dom = $XML::XML2JSON::XMLPARSER->createDocument( $Version, $Encoding );
	my $GotRoot = 0;

	# patch: first filter out the element names, then the attributes. 
	my @attr     = grep { /^[@]/  } keys %$Obj;
	my @non_attr = grep { /^[^@]/ } keys %$Obj;
	for my $Key ( @non_attr, @attr ) {
		$Obj->{$Key} = "" unless defined($Obj->{$Key});		
		my $RefType = ref( $Obj->{$Key} );
		warn "Value ref type for $Key is: $RefType (value seems to be $Obj->{$Key})" if $Self->{debug};
		my $Name = $Key;

		# replace a "$" in the name with a ":"
		$Name =~ s/([^^])\$/$1\:/;
		if ( $RefType eq 'HASH' ) {
			warn "Creating root element: $Name" if $Self->{debug};
			$GotRoot = 1;
			my $Root = $Dom->createElement($Name);
			$Dom->setDocumentElement($Root);
			$Self->_process_element_hash( $Dom, $Root, $Obj->{$Key} );
		}
		elsif ( !$RefType ) {		
			if ( $Obj->{$Key} ne '' ) {
				unless ($GotRoot) {
					my $Root;
					eval { $Root = $Dom->createElement($Name) };
					if ( $@ ) {
						die "Problem creating root element $Name: $@";
					}
					$Dom->setDocumentElement($Root);
					$Root->appendText( $Obj->{$Key} );
					$GotRoot = 1;
				}
			}
		}
		else {
			warn "unknown reference: $RefType";
		}
	}
	return $Dom;
}

sub _process_element_hash_patch {
	my ( $Self, $Dom, $Element, $Obj ) = @_;

	# patch: first filter out the element names, then the attributes. Sort the 
	# element names in accordance with the NeXML schema.
	my %order = ( 
		'meta'       => 1, 
		'otus'       => 2, 
		'trees'      => 3,
		'characters' => 3,
	);
	my @attr     = grep { /^[@]/  } keys %$Obj;
	my @non_attr = map  { $_->[0] } 
				   sort { $a->[1] <=> $b->[1] }
				   map  { $order{$_} ? [ $_, $order{$_} ] : [ $_, 4 ] }
				   grep { /^[^@]/ } keys %$Obj;

	for my $Key ( @non_attr, @attr ) {
		my $RefType = ref( $Obj->{$Key} );
		my $Name = $Key;

		# replace a "$" in the name with a ":"
		$Name =~ s/([^^])\$/$1\:/;
		
		# true/false hacks
		if ($RefType eq 'JSON::XS::Boolean') {
		    $RefType = "";
		    $Obj->{$Key} = 1 if ("$Obj->{$Key}" eq 'true');
		    $Obj->{$Key} = "" if ("$Obj->{$Key}" eq 'false');
		}
		if ($RefType eq 'JSON::true') {
		    $RefType = "";
		    $Obj->{$Key} = 1;
		}
		if ($RefType eq 'JSON::false') {
		    $RefType = "";
		    $Obj->{$Key} = "";
		}

		if ( $RefType eq 'ARRAY' ) {
			for my $ChildObj ( @{ $Obj->{$Key} } ) {
				my $Child = $Dom->createElement($Name);
				$Element->addChild($Child);
				$Self->_process_element_hash( $Dom, $Child, $ChildObj );
			}
		}
		elsif ( $RefType eq 'HASH' ) {
			my $Child = $Dom->createElement($Name);
			$Element->addChild($Child);
			$Self->_process_element_hash( $Dom, $Child, $Obj->{$Key} );
		}
		elsif ( !$RefType ) {
			if ( $Key eq $Self->{content_key} ) {				
				my $Value = defined($Obj->{$Key}) ? $Obj->{$Key} : q{};
				$Element->appendText( $Value );
			}
			else {

				# remove the attribute prefix
				my $AttributePrefix = $Self->{attribute_prefix};
				if ( $Name =~ /^\Q$AttributePrefix\E(.+)/ ) {
					$Name = $1;
				}				
				my $Value = defined($Obj->{$Key}) ? $Obj->{$Key} : q{};
				$Element->setAttribute( $Name, $Value );
			}
		}
	}

	return;
}

# In addition, we patch the 
# XML::XML2JSON::_init subroutine because it was emitting a debug message
# as a warning, which is ugly. 
sub _init_patch {
	my $Self = shift;
	my %Args = @_;
	my @Modules = qw(JSON::Syck JSON::XS JSON JSON::DWIW);
	if ( $Args{module} ) {
		my $OK = 0;
		for my $Module ( @Modules ) {
			$OK = 1 if $Module eq $Args{module};
		}
		@Modules = ( $Args{module} );
	}
	$Self->{_loaded_module} = "";
	for my $Module ( @Modules ) {
		eval "use $Module (); 1;";
		unless ($@) {
			$Self->{_loaded_module} = $Module;
			last;
		}
	}

	# force arrays (this turns off array folding)
	$Self->{force_array} = $Args{force_array} ? 1 : 0;

	# use pretty printing when possible
	$Self->{pretty} = $Args{pretty} ? 1 : 0;

	# debug mode
	$Self->{debug} = $Args{debug} ? 1 : 0;

	# names
	$Self->{attribute_prefix} = defined $Args{attribute_prefix} ? $Args{attribute_prefix} : '@';
	$Self->{content_key}      = defined $Args{content_key}      ? $Args{content_key}      : '$t';

	# private_elements
	$Self->{private_elements} = {};
	if ($Args{private_elements}) {
		for my $private_element ( @{$Args{private_elements}} ) {
	
			# this must account for the ":" to "$" switch
			$private_element =~ s/([^^])\:/$1\$/;
			$Self->{private_elements}->{$private_element} = 1;
		}
	}

	# empty_elements
	$Self->{empty_elements} = {};
	if ($Args{empty_elements}) {
		for my $empty_element ( @{$Args{empty_elements}} ) {
	
			# this must account for the ":" to "$" switch
			$empty_element =~ s/([^^])\:/$1\$/;
			$Self->{empty_elements}->{$empty_element} = 1;
		}
	}

	# private_attributes
	$Self->{private_attributes} = {};
	if ($Args{private_attributes}) {
		for my $private_attribute ( @{$Args{private_attributes}} ) {
	
			# this must account for the attribute_prefix
			$Self->{private_attributes}->{ $Self->{attribute_prefix} . $private_attribute } = 1;
		}
	}
	return;
}

# Let's assume that the next version of  XML::XML2JSON will fix these issues and just test 
# for the current version, which appears to be the one that everybody has.
if ( $XML::XML2JSON::VERSION == 0.06 ) {
	*obj2dom = \&_obj2dom_patch;	
	*_init = \&_init_patch;
	*_process_element_hash = \&_process_element_hash_patch;
}

1;