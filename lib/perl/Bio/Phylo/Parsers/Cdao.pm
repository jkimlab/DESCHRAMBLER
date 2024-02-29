package Bio::Phylo::Parsers::Cdao;
use strict;
use warnings;
use base 'Bio::Phylo::Parsers::Abstract';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw'looks_like_instance :namespaces :objecttypes';
use Bio::Phylo::Util::Dependency qw'RDF::Trine::Node::Resource RDF::Query';

=head1 NAME

Bio::Phylo::Parsers::Cdao - Parser used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module is used for parsing CDAO RDF. The implementation is incomplete,
especially for character state matrices (trees and OTUs work fine).

=cut

my $ns_cdao = _NS_CDAO_;
my $ns_rdf  = _NS_RDF_;
my $ns_rdfs = _NS_RDFS_;

my %prefix_for_ns = (
    $ns_cdao => 'cdao',
    $ns_rdf  => 'rdf',
    $ns_rdfs => 'rdfs',
);

my %objects;

my $prefixes = <<"PREFIXES";
PREFIX rdf: <${ns_rdf}>
PREFIX cdao: <${ns_cdao}>
PREFIX rdfs: <${ns_rdfs}>
PREFIXES

my $query = <<"QUERY";
${prefixes}
SELECT
	?subject
WHERE {
	?subject rdf:type cdao:%s
}
QUERY

my $subclass = <<"SUBCLASS";
${prefixes}
SELECT
	?subject
WHERE {
	?subject rdfs:subClassOf cdao:%s
}
SUBCLASS

my $states = <<"STATES";
${prefixes}
SELECT
	?subject ?stateset ?state ?label
WHERE {
    ?subject cdao:belongs_to_TU <%s> .
    ?subject cdao:belongs_to_Character <%s> .
    ?subject cdao:has_%sState ?state .
    ?state rdfs:label ?label .
    ?state rdf:type ?stateset
}
STATES

sub _parse {
    warn "***Please note: implementation is incomplete, character data are not yet read correctly.***\n";
    my $self = shift;
    %objects = ();
    $self->_args->{'-opts'} = {
        'lang'      => 'sparql',
        'base'      => $self->_args->{'-base'},
        'update'    => 0,
        'load_data' => 0,
    };
    $self->_project->set_base_uri($self->_args->{'-base'});
    $self->_process_tus;
    $self->_process_trees;
    $self->_process_nodes;
    $self->_process_edges;
    $self->_process_matrices;
    
    my $proj = $self->_project;
    my @objects = ( @{ $proj->get_taxa }, @{ $proj->get_forests }, @{ $proj->get_matrices } );
    $proj->clear;
    return @objects;
}

sub _object_from_resource {
    my ( $self, $resource, $creator ) = @_;
    my $fac = $self->_factory;
    my $base = $self->_args->{'-base'};
    my $uri = $resource->value;
    my $id = $uri;
    $id  =~ s/^\Q$base\E#?//;
    my $object = $fac->$creator( '-guid' => $id, '-xml_id' => $id );
    my $iterator = $self->_args->{'-model'}->get_statements($resource,undef,undef);
    while ( my $inner = $iterator->next ) {
        my ( $predicate, $value ) = ( $inner->predicate, $inner->object );
        $self->_process_annotation( $predicate->value, $value->value, $object );

    }
    $objects{$uri} = $object;    
}

sub _parse_predicate {
    my ( $self, $predicate ) = @_;
    # attempt to split URI in namespace and term
    my ( $ns, $term );
    
    # this is for cases where the term is referenced as somewhere inside
    # an ontology using an anchor '#', e.g. in CDAO
    if ( $predicate =~ m/^(.+#)(.+?)$/ ) {
        ( $ns, $term ) = ( $1, $2 );
    }
    
    # this is for cases where the term is a path fragment inside a namespace,
    # i.e. preceded by a '/', as in dublin core
    elsif ( $predicate =~ m/^(.+\/)([^\/]+?)$/ ) {
        ( $ns, $term ) = ( $1, $2 );
    }
    
    # this is for cases where the term is relative to a urn:, i.e. preceded
    # by a ':', as in the uBio predicates
    elsif ( $predicate =~ m/^(.+:)([^:]+?)$/ ) {
        ( $ns, $term ) = ( $1, $2 );
    }
    
    else {
        $self->_logger->warn("Can't parse URI $predicate");
    }
    return $ns, $term;
}

sub _process_annotation {
    my ( $self, $predicate, $value, $object ) = @_;
    my $fac = $self->_factory;
    $predicate =~ s/^<(.+)>$/$1/;
    return if $predicate eq _NS_RDF_ . 'type';
    
    # attempt to split URI in namespace and term
    my ( $ns, $term ) = $self->_parse_predicate( $predicate );
    
    # check to see if we have a prefix for that namespace, or make one
    my $prefix = $prefix_for_ns{$ns} || 'ns' . scalar(keys %prefix_for_ns);
    $prefix_for_ns{$prefix} = $ns;
    
    # maybe we know how to deal with this in the API
    if ( "${prefix}:${term}" eq 'rdfs:label' ) {
        $object->set_name( $value );
        return;
    }
    if ( "${prefix}:${term}" eq 'cdao:represents_TU' ) {
        $object->set_taxon( $objects{$value} );
        return;
    }
    if ( "${prefix}:${term}" eq 'cdao:has_Ancestor' ) {
        return; # don't need this, will reconstruct from edge links
    }
    if ( "${prefix}:${term}" eq 'cdao:has_Root' ) {
        return; # don't need this, will be obvious from whether tree is rooted
    }
    
    # attach annotation
    $object->set_namespaces( $prefix => $ns );
    $object->add_meta(
        $fac->create_meta(
            '-triple' => { "${prefix}:${term}" => $value }
        )
    );    
}

sub _do_query {
    my ( $self, $type, $type_query ) = @_;
    $type_query = $query unless $type_query;
    my $sth = RDF::Query->new( sprintf($type_query, $type), $self->_args->{'-opts'} );
    return $sth->execute( $self->_args->{'-model'} );
}

sub _process_matrices {
    my $self = shift;
    my $fac = $self->_factory;
    my $model = $self->_args->{'-model'};
    my $iter = $self->_do_query('CharacterStateDataMatrix');
    while( my $row = $iter->next ) {
        my $subject = $row->{'subject'};
        my $matrix = $self->_object_from_resource( $subject, 'create_matrix' );
        my ($taxa) = @{ $self->_project->get_taxa };
        $matrix->set_taxa($taxa);
        
        # create rows for taxa
        my ( $rowlist, %row ) = $self->_create_rows($matrix);
        
        # create columns
        my ( $charlist, %char ) = $self->_create_characters($matrix);
        
        # maps CDAO state type predicates to Bio::Phylo matrix types
        my %types = (
            'Nucleotide_' => 'dna',
            'Continuous_' => 'continuous',
            'Standard_'   => 'standard',
            ''            => 'standard',            
        );
        my $datatype;
        
        for my $row_uri ( @{ $rowlist } ) {
            for my $col_uri ( @{ $charlist } ) {
                if ( not $datatype ) {
                    TYPE_SEARCH : for my $predicate ( keys %types ) {
                        my $state_query = sprintf($states, $row_uri, $col_uri, $predicate );
                        my $sth = RDF::Query->new( $state_query, $self->_args->{'-opts'} );
                        my $state_iterator = $sth->execute( $self->_args->{'-model'} );
                        if ( my $state = $state_iterator->next ) {
                            $datatype = $predicate;
                            $matrix->set_type($types{$predicate});
                            last TYPE_SEARCH;
                        }
                    }
                }
                else {
                    my $state_query = sprintf($states, $row_uri, $col_uri, $datatype );
                    my $sth = RDF::Query->new( $state_query, $self->_args->{'-opts'} );
                    my $state_iterator = $sth->execute( $self->_args->{'-model'} );
                    while ( my $state = $state_iterator->next ) {
                        if ( my $val = $state->{label}->value ) {
                            $row{$row_uri}->insert($val);
                        }
                    }                    
                }
            }
        }
        $self->_logger->debug($matrix->to_nexus);
    }
}

sub _create_rows {
    my ( $self, $matrix ) = @_;
    my $fac = $self->_factory;
    my ( %row, @rowlist );
    my $tu_metas = $matrix->get_meta('cdao:has_TU');
    for my $tu_meta ( @{ $tu_metas } ) {
        my $tu_uri = $tu_meta->get_object;
        my $row = $fac->create_datum(
            '-taxon' => $objects{$tu_uri},
            '-name'  => $objects{$tu_uri}->get_name,
        );
        $row{$tu_uri} = $row;
        $matrix->insert( $row );
        push @rowlist, $tu_uri;
    }
    return \@rowlist, %row;
}

sub _create_characters {
    my ( $self, $matrix ) = @_;
    my ( %char, @charlist );
    my $characters = $matrix->get_characters;
    my $char_metas = $matrix->get_meta('cdao:has_Character');
    for my $char_meta ( @{ $char_metas } ) {
        my $char_uri = $char_meta->get_object;
        my $char_resource = RDF::Trine::Node::Resource->new( $char_uri );
        my $char = $self->_object_from_resource( $char_resource, 'create_character' );
        $char{$char_uri} = $char;
        $characters->insert($char);
        push @charlist, $char_uri;
    }
    return \@charlist, %char;
}

sub _process_tus {
    my $self  = shift;
    my $fac   = $self->_factory;
    my $taxa  = $fac->create_taxa;
    my $model = $self->_args->{'-model'};
    my $iter  = $self->_do_query('TU');
    while ( my $row = $iter->next ) {
        my $subject = $row->{'subject'};
        my $taxon = $self->_object_from_resource( $subject, 'create_taxon' );
        $taxa->insert($taxon);
    }
    $self->_project->insert($taxa);
}

sub _process_trees {
    my $self   = shift;
    my $fac    = $self->_factory;
    my ($taxa) = @{ $self->_project->get_items(_TAXA_) };
    my $forest = $fac->create_forest( '-taxa' => $taxa );
    my $model  = $self->_args->{'-model'};
    
    # process rooted trees
    my $rooted_iter = $self->_do_query('RootedTree');
    while( my $row = $rooted_iter->next ) {
        my $subject = $row->{'subject'};
        my $tree = $self->_object_from_resource( $subject, 'create_tree' );
        $forest->insert($tree);
    }
    
    # process unrooted trees
    my $unrooted_iter = $self->_do_query('UnrootedTree');
    while( my $row = $unrooted_iter->next ) {
        my $subject = $row->{'subject'};
        my $tree = $self->_object_from_resource( $subject, 'create_tree' );
        $tree->set_as_unrooted;
        $forest->insert($tree);
    }
    
    $self->_project->insert($forest);
}

sub _process_nodes {
    my $self   = shift;
    my $model  = $self->_args->{'-model'};
    my $logger = $self->_logger;
    
    # this only assigns nodes to a tree object but doesn't resolve
    # topology, that's done in _process_edges
    my $node_iter = $self->_do_query('Node');
    while( my $row = $node_iter->next ) {
        my $subject = $row->{'subject'};
        my $node = $self->_object_from_resource( $subject, 'create_node' );
        my ($value) = @{ $node->get_meta('cdao:belongs_to_Tree') };
        $objects{$value->get_object}->insert($node) if $objects{$value->get_object};
        $node->remove_meta($value);
    }
}

sub _process_edges {
    my $self   = shift;
    my $model  = $self->_args->{'-model'};
    my $logger = $self->_logger;
    
    my $edge_iter = $self->_do_query('DirectedEdge');
    while( my $row = $edge_iter->next ) {
        my $subject = $row->{'subject'};
        my $edge_statements = $model->get_statements($subject);
        my ( $parent_uri, $child_uri, $branch_length );
        LINK: while( my $st = $edge_statements->next ) {
            my $predicate = $st->predicate->value;
            $logger->debug($predicate);
            if ( $predicate eq "${ns_cdao}has_Parent_Node" ) {
                $parent_uri = $st->object->value;
            }
            elsif ( $predicate eq "${ns_cdao}has_Child_Node" ) {
                $child_uri = $st->object->value;
            }
            elsif ( $predicate eq "${ns_cdao}has_Annotation" ) {
                my $annotation_statements = $model->get_statements($st->object);
                ANNO: while(my $anno = $annotation_statements->next) {
                    my $anno_pre = $anno->predicate->value;
                    if ( $anno_pre =~ /^\Q${ns_cdao}\Ehas_(?:Int|Float)_Value/ ) {
                        $branch_length = $anno->object->value;
                        last ANNO;
                    }
                }
            }
            last LINK if $parent_uri && $child_uri;           
        }
        $logger->debug("Parent: $parent_uri Child: $child_uri");
        $objects{$parent_uri}->set_child($objects{$child_uri});
        $objects{$child_uri}->set_branch_length($branch_length) if defined $branch_length;
    }
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The CDAO parser is called by the L<Bio::Phylo::IO> object.
Look there for examples.

=item L<Bio::Phylo::Manual>

Also see the manual: L<Bio::Phylo::Manual> and L<http://rutgervos.blogspot.com>.

=back

=head1 CITATION

If you use Bio::Phylo in published research, please cite it:

B<Rutger A Vos>, B<Jason Caravas>, B<Klaas Hartmann>, B<Mark A Jensen>
and B<Chase Miller>, 2011. Bio::Phylo - phyloinformatic analysis using Perl.
I<BMC Bioinformatics> B<12>:63.
L<http://dx.doi.org/10.1186/1471-2105-12-63>

=cut

1;
