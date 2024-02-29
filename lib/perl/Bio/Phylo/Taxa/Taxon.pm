package Bio::Phylo::Taxa::Taxon;
use strict;
use warnings;
use base 'Bio::Phylo::NeXML::Writable';
use Bio::Phylo::Util::CONSTANT qw':objecttypes looks_like_object';
use Bio::Phylo::Mediators::TaxaMediator;
{
    my $TYPE_CONSTANT      = _TAXON_;
    my $CONTAINER_CONSTANT = _TAXA_;
    my $DATUM_CONSTANT     = _DATUM_;
    my $NODE_CONSTANT      = _NODE_;
    my $logger             = __PACKAGE__->get_logger;
    my $mediator           = 'Bio::Phylo::Mediators::TaxaMediator';

=head1 NAME

Bio::Phylo::Taxa::Taxon - Operational taxonomic unit

=head1 SYNOPSIS

 use Bio::Phylo::IO qw(parse);
 use Bio::Phylo::Factory;
 my $fac = Bio::Phylo::Factory->new;

 # array of names
 my @apes = qw(
     Homo_sapiens
     Pan_paniscus
     Pan_troglodytes
     Gorilla_gorilla
 );

 # newick string
 my $str = '(((Pan_paniscus,Pan_troglodytes),';
 $str   .= 'Homo_sapiens),Gorilla_gorilla);';

 # create tree object
 my $tree = parse(
    -format => 'newick',
    -string => $str
 )->first;

 # instantiate taxa object
 my $taxa = $fac->create_taxa;

 # instantiate taxon objects, insert in taxa object
 foreach( @apes ) {
    my $taxon = $fac->create_taxon(
        -name => $_,
    );
    $taxa->insert($taxon);
 }

 # crossreference tree and taxa
 $tree->cross_reference($taxa);

 # iterate over nodes
 while ( my $node = $tree->next ) {

    # check references
    if ( $node->get_taxon ) {

        # prints crossreferenced tips
        print "match: ", $node->get_name, "\n";
    }
 }

=head1 DESCRIPTION

The taxon object models a single operational taxonomic unit. It is useful for
cross-referencing datum objects and tree nodes.

=head1 METHODS

=head2 MUTATORS

=over

=item set_data()

Associates argument data with invocant.

 Type    : Mutator
 Title   : set_data
 Usage   : $taxon->set_data( $datum );
 Function: Associates data with
           the current taxon.
 Returns : Modified object.
 Args    : Must be an object of type
           Bio::Phylo::Matrices::Datum

=cut

    sub set_data : Clonable {
        my ( $self, $datum ) = @_;
        if ( not defined $datum ) {
            return $self;
        }
        elsif ( ref $datum eq 'ARRAY' ) {
            for my $d ( @{ $datum } ) {
                $self->set_data($d);
            }        
        }
        elsif ( looks_like_object $datum, $DATUM_CONSTANT ) {
            $mediator->set_link(
                '-one'  => $self,
                '-many' => $datum,
            );
        }
        return $self;
    }

=item set_nodes()

Associates argument node with invocant.

 Type    : Mutator
 Title   : set_nodes
 Usage   : $taxon->set_nodes($node);
 Function: Associates tree nodes
           with the current taxon.
 Returns : Modified object.
 Args    : A Bio::Phylo::Forest::Node object

=cut

    sub set_nodes : Clonable {
        my ( $self, $node ) = @_;
        if ( not defined $node ) {
            return $self;
        }        
        elsif ( ref $node eq 'ARRAY' ) {
            for my $n ( @{ $node } ) {
                $self->set_nodes($n);
            }
        }
        elsif ( looks_like_object $node, $NODE_CONSTANT ) {
            $mediator->set_link(
                '-one'  => $self,
                '-many' => $node,
            );
        }
        return $self;
    }

=item unset_datum()

Removes association between argument data and invocant.

 Type    : Mutator
 Title   : unset_datum
 Usage   : $taxon->unset_datum($node);
 Function: Disassociates datum from
           the invocant taxon (i.e.
           removes reference).
 Returns : Modified object.
 Args    : A Bio::Phylo::Matrix::Datum object

=cut

    sub unset_datum {
        my ( $self, $datum ) = @_;
        $mediator->remove_link(
            '-one'  => $self,
            '-many' => $datum,
        );
        return $self;
    }

=item unset_node()

Removes association between argument node and invocant.

 Type    : Mutator
 Title   : unset_node
 Usage   : $taxon->unset_node($node);
 Function: Disassociates tree node from
           the invocant taxon (i.e.
           removes reference).
 Returns : Modified object.
 Args    : A Bio::Phylo::Forest::Node object

=cut

    sub unset_node {
        my ( $self, $node ) = @_;
        $mediator->remove_link(
            '-one'  => $self,
            '-many' => $node,
        );
        return $self;
    }

=back

=head2 ACCESSORS

=over

=item get_data()

Retrieves associated datum objects.

 Type    : Accessor
 Title   : get_data
 Usage   : @data = @{ $taxon->get_data };
 Function: Retrieves data associated
           with the current taxon.
 Returns : An ARRAY reference of
           Bio::Phylo::Matrices::Datum
           objects.
 Args    : None.

=cut

    sub get_data {
        my $self = shift;
        return $mediator->get_link(
            '-source' => $self,
            '-type'   => $DATUM_CONSTANT,
        ) || [];
    }

=item get_nodes()

Retrieves associated node objects.

 Type    : Accessor
 Title   : get_nodes
 Usage   : @nodes = @{ $taxon->get_nodes };
 Function: Retrieves tree nodes associated
           with the current taxon.
 Returns : An ARRAY reference of
           Bio::Phylo::Trees::Node objects
 Args    : None.

=cut

    sub get_nodes {
        my $self = shift;
        return $mediator->get_link(
            '-source' => $self,
            '-type'   => $NODE_CONSTANT,
        ) || [];
    }

=begin comment

 Type    : Internal method
 Title   : _container
 Usage   : $taxon->_container;
 Function:
 Returns : CONSTANT
 Args    :

=end comment

=cut

    sub _container { $CONTAINER_CONSTANT }

=begin comment

 Type    : Internal method
 Title   : _type
 Usage   : $taxon->_type;
 Function:
 Returns : CONSTANT
 Args    :

=end comment

=cut

    sub _type { $TYPE_CONSTANT }
    sub _tag  { 'otu' }

=back

=cut

    # podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::NeXML::Writable>

The taxon objects inherits from the L<Bio::Phylo::NeXML::Writable> object. The methods defined
there are also applicable to the taxon object.

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
