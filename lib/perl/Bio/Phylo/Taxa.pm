package Bio::Phylo::Taxa;
use strict;
use warnings;
use base 'Bio::Phylo::Listable';
use Bio::Phylo::Util::CONSTANT qw':objecttypes /looks_like/ :namespaces';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Mediators::TaxaMediator;
use Bio::Phylo::Factory;

=begin comment

This class has no internal state, no cleanup is necessary.

=end comment

=cut

{
    my $logger    = __PACKAGE__->get_logger;
    my $mediator  = 'Bio::Phylo::Mediators::TaxaMediator';
    my $factory   = Bio::Phylo::Factory->new;
    my $CONTAINER = _PROJECT_;
    my $TYPE      = _TAXA_;
    my $MATRIX    = _MATRIX_;
    my $FOREST    = _FOREST_;

=head1 NAME

Bio::Phylo::Taxa - Container of taxon objects

=head1 SYNOPSIS

 use Bio::Phylo::Factory;
 my $fac = Bio::Phylo::Factory->new;

 # A mesquite-style default
 # taxa block for 10 taxa.
 my $taxa  = $fac->create_taxa;
 for my $i ( 1 .. 10 ) {
     $taxa->insert( $fac->create_taxon( '-name' => "taxon_${i}" ) );
 }
 
 # prints a taxa block in nexus format
 print $taxa->to_nexus;

=head1 DESCRIPTION

The Bio::Phylo::Taxa object models a set of operational taxonomic units. The
object subclasses the Bio::Phylo::Listable object, and so the filtering
methods of that class are available.

A taxa object can link to multiple forest and matrix objects.

=head1 METHODS

=head2 CONSTRUCTOR

=over

=item new()

Taxa constructor.

 Type    : Constructor
 Title   : new
 Usage   : my $taxa = Bio::Phylo::Taxa->new;
 Function: Instantiates a Bio::Phylo::Taxa object.
 Returns : A Bio::Phylo::Taxa object.
 Args    : none.

=cut

    #     sub new {
    #         # could be child class
    #         my $class = shift;
    #
    #         # notify user
    #         $logger->info("constructor called for '$class'");
    #
    #         # recurse up inheritance tree, get ID
    #         my $self = $class->SUPER::new( '-tag' => __PACKAGE__->_tag, @_ );
    #
    #         # local fields would be set here
    #
    #         return $self;
    #     }

=back

=head2 MUTATORS

=over

=item set_forest()

Sets associated Bio::Phylo::Forest object.

 Type    : Mutator
 Title   : set_forest
 Usage   : $taxa->set_forest( $forest );
 Function: Associates forest with the 
           invocant taxa object (i.e. 
           creates reference).
 Returns : Modified object.
 Args    : A Bio::Phylo::Forest object 
 Comments: A taxa object can link to multiple 
           forest and matrix objects.

=cut

    sub set_forest {
        my ( $self, $forest ) = @_;
        $logger->debug("setting forest $forest");
        if ( looks_like_object $forest, $FOREST ) {
            $forest->set_taxa($self);
        }
        return $self;
    }

=item set_matrix()

Sets associated Bio::Phylo::Matrices::Matrix object.

 Type    : Mutator
 Title   : set_matrix
 Usage   : $taxa->set_matrix($matrix);
 Function: Associates matrix with the 
           invocant taxa object (i.e. 
           creates reference).
 Returns : Modified object.
 Args    : A Bio::Phylo::Matrices::Matrix object
 Comments: A taxa object can link to multiple 
           forest and matrix objects. 

=cut

    sub set_matrix {
        my ( $self, $matrix ) = @_;
        $logger->debug("setting matrix $matrix");
        if ( looks_like_object $matrix, $MATRIX ) {
            $matrix->set_taxa($self);
        }
        return $self;
    }

=item unset_forest()

Removes association with argument Bio::Phylo::Forest object.

 Type    : Mutator
 Title   : unset_forest
 Usage   : $taxa->unset_forest($forest);
 Function: Disassociates forest from the 
           invocant taxa object (i.e. 
           removes reference).
 Returns : Modified object.
 Args    : A Bio::Phylo::Forest object

=cut

    sub unset_forest {
        my ( $self, $forest ) = @_;
        $logger->debug("unsetting forest $forest");
        if ( looks_like_object $forest, $FOREST ) {
            $forest->unset_taxa();
        }
        return $self;
    }

=item unset_matrix()

Removes association with Bio::Phylo::Matrices::Matrix object.

 Type    : Mutator
 Title   : unset_matrix
 Usage   : $taxa->unset_matrix($matrix);
 Function: Disassociates matrix from the 
           invocant taxa object (i.e. 
           removes reference).
 Returns : Modified object.
 Args    : A Bio::Phylo::Matrices::Matrix object

=cut

    sub unset_matrix {
        my ( $self, $matrix ) = @_;
        $logger->debug("unsetting matrix $matrix");
        if ( looks_like_object $matrix, $MATRIX ) {
            $matrix->unset_taxa();
        }
        return $self;
    }

=back

=head2 ACCESSORS

=over

=item get_forests()

Gets all associated Bio::Phylo::Forest objects.

 Type    : Accessor
 Title   : get_forests
 Usage   : @forests = @{ $taxa->get_forests };
 Function: Retrieves forests associated 
           with the current taxa object.
 Returns : An ARRAY reference of 
           Bio::Phylo::Forest objects.
 Args    : None.

=cut

    sub get_forests {
        my $self = shift;
        return $mediator->get_link(
            '-source' => $self,
            '-type'   => $FOREST,
        );
    }

=item get_matrices()

Gets all associated Bio::Phylo::Matrices::Matrix objects.

 Type    : Accessor
 Title   : get_matrices
 Usage   : @matrices = @{ $taxa->get_matrices };
 Function: Retrieves matrices associated 
           with the current taxa object.
 Returns : An ARRAY reference of 
           Bio::Phylo::Matrices::Matrix objects.
 Args    : None.

=cut

    sub get_matrices {
        my $self = shift;
        return $mediator->get_link(
            '-source' => $self,
            '-type'   => $MATRIX,
        );
    }

=item get_ntax()

Gets number of contained Bio::Phylo::Taxa::Taxon objects.

 Type    : Accessor
 Title   : get_ntax
 Usage   : my $ntax = $taxa->get_ntax;
 Function: Retrieves the number of taxa for the invocant.
 Returns : INT
 Args    : None.
 Comments:

=cut

    sub get_ntax {
        my $self = shift;
        return scalar @{ $self->get_entities };
    }

=back

=head2 METHODS

=over

=item merge_by_name()

Merges argument Bio::Phylo::Taxa object with invocant.

 Type    : Method
 Title   : merge_by_name
 Usage   : $merged = $taxa->merge_by_name($other_taxa);
 Function: Merges two or more taxa objects such that 
           internally different taxon objects 
           with the same name become a single
           object with the combined references 
           to datum objects and node objects 
           contained by the two.           
 Returns : A merged Bio::Phylo::Taxa object.
 Args    : Bio::Phylo::Taxa objects.

=cut

    sub merge_by_name {
        my $merged = $factory->create_taxa( '-name' => 'Merged' );
        for my $taxa (@_) {
            
            # build a hash of what we have so far
            my %taxon_by_name = map { $_->get_name => $_ } @{ $merged->get_entities };
              
            # iterate over focal taxa block
            for my $taxon ( @{ $taxa->get_entities } ) {
                my $name = $taxon->get_name;
                
                # retrieve or create target taxon
                my $target;
                if ( $taxon_by_name{$name} ) {
                    $target = $taxon_by_name{$name};
                }
                else {
                    $target = $factory->create_taxon( '-name' => $name );
                    $merged->insert($target);
                    $taxon_by_name{$name} = $target;
                }                
                
                # copy over data, metadata and node links
                $_->set_taxon($target) for @{ $taxon->get_data };
                $_->set_taxon($target) for @{ $taxon->get_nodes };
                $target->add_meta($_)  for @{ $taxon->get_meta };
            }
        }
        return $merged;
    }

=item merge_by_meta()

Merges argument Bio::Phylo::Taxa object with invocant.

 Type    : Method
 Title   : merge_by_meta
 Usage   : $taxa->merge_by_name('dc:identifier',$other_taxa);
 Function: Merges two taxa objects such that 
           internally different taxon objects 
           with the same annotation value become
           a single object with the combined references 
           to datum objects, node objects and
           metadata annotations contained by
           the two.           
 Returns : A merged Bio::Phylo::Taxa object.
 Args    : a CURIE predicate and Bio::Phylo::Taxa objects.

=cut

    sub merge_by_meta {
        my ( $self, $predicate, @others ) = @_;
        push @others, $self;
        my $merged = $factory->create_taxa;
        for my $taxa ( @others ) {
                        
            my %object_by_value =
                map { $_->get_meta_object($predicate) => $_ }
                @{ $merged->get_entities };
                
            for my $taxon ( @{ $taxa->get_entities } ) {
                
                # instantiate or fetch taxon based on predicate value
                my $value = $taxon->get_meta_object($predicate);
                my $target = $object_by_value{$value} || $factory->create_taxon();
                
                # copy links and metadata
                $_->set_taxon($target) for @{ $taxon->get_data };
                $_->set_taxon($target) for @{ $taxon->get_nodes };
                $target->add_meta($_) for @{ $taxon->get_meta };
                
                # copy name to bp:contributing_name
                if ( my $name = $taxon->get_name ) {
                    $target->add_meta(
                        $factory->create_meta(
                            '-namespaces' => { 'bp' => _NS_BIOPHYLO_ },
                            '-triple' => { 'bp:contributing_name' => $name }
                        )
                    );
                }
                
                # add to hash and block if newly created
                if ( not exists $object_by_value{$value} ) {
                    $merged->insert($target);
                    $object_by_value{$value} = $target;
                }
            }            
        }
        return $merged;
    }

=item prune_taxa()

Removes taxa by name or object

 Type    : Method
 Title   : prune_taxa
 Usage   : $taxa->prune_taxa([$t1, $t2]);
 Function: Prunes taxa from the taxa object           
 Returns : A pruned Bio::Phylo::Taxa object.
 Args    : An array reference of taxa, either by name or as taxon objects

=cut

	sub prune_taxa {
		my ( $self, $arrayref ) = @_;
		if ( ref($arrayref) eq 'ARRAY' ) {
			for my $t ( @{ $arrayref } ) {
				if ( not ref $t ) {
					if ( my $obj = $self->get_by_name($t) ) {
						$self->delete($obj);
					}
					else {
						$logger->warn("Couldn't find taxon with name '$t'");
					}				
				}
				elsif ( looks_like_object $t, _TAXON_ ) {
					$self->delete($t);
				}			
			}		
		}
		else {
			throw 'BadArgs' => 'Argument is not an array reference';
		}
		return $self;
	}


=item to_nexus()

Serializes invocant to nexus format.

 Type    : Format convertor
 Title   : to_nexus
 Usage   : my $block = $taxa->to_nexus;
 Function: Converts $taxa into a nexus taxa block.
 Returns : Nexus taxa block (SCALAR).
 Args    : -links => 1 (optional, adds 'TITLE' token)
 Comments:

=cut    

    sub to_nexus {
        my ( $self, %args ) = @_;
        my %m = (
            'header' => ( $args{'-header'} && '#NEXUS' ) || '',
            'title' =>
              ( $args{'-links'} && sprintf 'TITLE %s;', $self->get_nexus_name )
              || '',
            'version'   => $self->VERSION,
            'ntax'      => $self->get_ntax,
            'class'     => ref $self,
            'time'      => my $time = localtime(),
            'taxlabels' => join "\n\t\t",
            map { $_->get_nexus_name } @{ $self->get_entities }
        );
        return <<TEMPLATE;
$m{header}
BEGIN TAXA;
[! Taxa block written by $m{class} $m{version} on $m{time} ]
	$m{title}
        DIMENSIONS NTAX=$m{ntax};
        TAXLABELS
		$m{taxlabels}
        ;
END;
TEMPLATE
    }

=begin comment

 Type    : Internal method
 Title   : _container
 Usage   : $taxa->_container;
 Function:
 Returns : CONSTANT
 Args    :

=end comment

=cut

    sub _container { $CONTAINER }

=begin comment

 Type    : Internal method
 Title   : _type
 Usage   : $taxa->_type;
 Function:
 Returns : SCALAR
 Args    :

=end comment

=cut

    sub _type { $TYPE }
    sub _tag  { 'otus' }

=back

=cut

    # podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::Listable>

The L<Bio::Phylo::Taxa> object inherits from the L<Bio::Phylo::Listable>
object. Look there for more methods applicable to the taxa object.

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

}
1;
