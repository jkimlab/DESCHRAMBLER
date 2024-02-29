package Bio::Phylo::Mediators::TaxaMediator;
use strict;
use warnings;
use Scalar::Util qw'weaken isweak';
use Bio::Phylo::Util::Logger ':simple';
use Bio::Phylo::Util::Exceptions;
use Bio::Phylo::Util::CONSTANT ':objecttypes';

{
    my $self;
    my ( @object, %id_by_type, %one_to_one, %one_to_many );

=head1 NAME

Bio::Phylo::Mediators::TaxaMediator - Mediator for links between taxa and other objects

=head1 SYNOPSIS

 # no direct usage

=head1 DESCRIPTION

This module manages links between taxon objects and other objects linked to 
them. It is an implementation of the Mediator design pattern (e.g. see 
L<http://www.atug.com/andypatterns/RM.htm>,
L<http://home.earthlink.net/~huston2/dp/mediator.html>).

Methods defined in this module are meant only for internal usage by Bio::Phylo.

=head1 METHODS

=head2 CONSTRUCTOR

=over

=item new()

TaxaMediator constructor.

 Type    : Constructor
 Title   : new
 Usage   : my $mediator = Bio::Phylo::Taxa::TaxaMediator->new;
 Function: Instantiates a Bio::Phylo::Taxa::TaxaMediator
           object.
 Returns : A Bio::Phylo::Taxa::TaxaMediator object (singleton).
 Args    : None.

=cut

    sub new {

        # could be child class
        my $class = shift;

        # notify user
        DEBUG "constructor called for '$class'";

        # singleton class
        if ( not $self ) {
            INFO "first time instantiation of singleton";
            $self = \$class;
            bless $self, $class;
        }
        return $self;
    }

=back

=head2 METHODS

=over

=item register()

Stores argument in invocant's cache.

 Type    : Method
 Title   : register
 Usage   : $mediator->register( $obj );
 Function: Stores an object in mediator's cache, if relevant
 Returns : $self
 Args    : An object, $obj
 Comments: This method is called every time an object is instantiated.

=cut

    sub register {
        my ( $self, $obj ) = @_;
        my $id = $obj->get_id;
        
        if ( ref $obj && $obj->can('_type') ) {
            my $type = $obj->_type;
            
            # node, forest, matrix, datum, taxon, taxa
            if ( $type == _NODE_ || $type == _TAXON_ || $type == _DATUM_ || $type == _TAXA_ || $type == _FOREST_ || $type == _MATRIX_ ) {
    
                # index by type
                $id_by_type{$type} = {} unless $id_by_type{$type};
                $id_by_type{$type}->{$id} = 1;

                # store in object cache
                $object[$id] = $obj;
                
                # in the one-to-many relationships we only weaken the
                # references to the many objects so that the get cleaned up
                #Êwhen they go out of scope. When the are unregistered and
                #Êthere is no more many object that references the one object,
                # the one object's reference needs to be weakened as well so
                # that it is cleaned up when it is no longer reachable from
                # elsewhere.
                #if ( $type != _TAXA_ && $type != _TAXON_ ) {
                    weaken $object[$id];
                #}
                return $self;
            }
        }
    }

=item unregister()

Removes argument from invocant's cache.

 Type    : Method
 Title   : unregister
 Usage   : $mediator->unregister( $obj );
 Function: Cleans up mediator's cache of $obj and $obj's relations
 Returns : $self
 Args    : An object, $obj
 Comments: This method is called every time an object is destroyed.

=cut

    sub unregister {
        my ( $self, $obj ) = @_;

        my $id = $obj->get_id;
        
        if ( defined $id ) {
            my $taxa_id = $one_to_one{$id};
            
            # decrease reference count of taxa block if we are the last pointer
            # to it
            if ( $taxa_id ) {
                my @others = keys %{ $one_to_many{$taxa_id} };
                if ( @others == 1 ) {
                    weaken $object[$taxa_id];
                }
                delete $one_to_many{$taxa_id}->{$id};
            }            
            
            # remove from object cache
            if ( exists $object[$id] ) {
                delete $object[$id];
            }            
            
            # remove from one-to-one mapping
            if ( exists $one_to_one{$id} ) {
                delete $one_to_one{$id};
            }
            
            # remove from one-to-many mapping if I am taxa
            if ( exists $one_to_many{$id} ) {
                delete $one_to_many{$id};    
            }
            
        }
        return $self;
    }

=item set_link()

Creates link between objects.

 Type    : Method
 Title   : set_link
 Usage   : $mediator->set_link( -one => $obj1, -many => $obj2 );
 Function: Creates link between objects
 Returns : $self
 Args    : -one  => $obj1 (source of a one-to-many relationship)
           -many => $obj2 (target of a one-to-many relationship)
 Comments: This method is called from within, for example, set_taxa
           method calls. A call like $taxa->set_matrix( $matrix ),
           and likewise a call like $matrix->set_taxa( $taxa ), are 
           both internally rerouted to:

           $mediator->set_link( 
                -one  => $taxa, 
                -many => $matrix 
           );

=cut

    sub set_link {
        my $self = shift;
        my %opt  = @_;
        my ( $one, $many ) = ( $opt{'-one'}, $opt{'-many'} );
        my ( $one_id, $many_id ) = ( $one->get_id, $many->get_id );
        $one_to_one{$many_id} = $one_id;
        $one_to_many{$one_id} = {} unless $one_to_many{$one_id};

        # once other objects start referring to the taxon we want
        # these references to keep the taxon "alive" until all other
        # objects pointing to it have gone out of scope, in which
        # case the reference must be weakened again, so that it
        # might get cleaned up also
        if (isweak($object[$one_id]) ) {
            my $strong = $object[$one_id];
            $object[$one_id] = $strong;
        }
        
        $one_to_many{$one_id}->{$many_id} = $many->_type;
        return $self;
    }

=item get_link()

Retrieves link between objects.

 Type    : Method
 Title   : get_link
 Usage   : $mediator->get_link( 
               -source => $obj, 
               -type   => _CONSTANT_,
           );
 Function: Retrieves link between objects
 Returns : Linked object
 Args    : -source => $obj (required, the source of the link)
           -type   => a constant from Bio::Phylo::Util::CONSTANT

           (-type is optional, used to filter returned results in 
           one-to-many query).

 Comments: This method is called from within, for example, get_taxa
           method calls. A call like $matrix->get_taxa()
           and likewise a call like $forest->get_taxa(), are 
           both internally rerouted to:

           $mediator->get_link( 
               -source => $self # e.g. $matrix or $forest           
           );

           A call like $taxa->get_matrices() is rerouted to:

           $mediator->get_link( -source => $taxa, -type => _MATRIX_ );

=cut

    sub get_link {
        my $self = shift;
        my %opt  = @_;
        my $id   = $opt{'-source'}->get_id;

        # have to get many objects,
        # i.e. source was a taxon/taxa
        if ( defined $opt{'-type'} ) {            
            my $type = $opt{'-type'};
            my @ids = grep { $one_to_many{$id}->{$_} == $type } keys %{ $one_to_many{$id} };
            my @result = @object[@ids];
            return \@result;
        }
        
        # have to get one object, i.e. source
        # was something that links to taxon/taxa
        else {
            return exists $one_to_one{$id} ? $object[$one_to_one{$id}] : undef;
        }
    }

=item remove_link()

Removes link between objects.

 Type    : Method
 Title   : remove_link
 Usage   : $mediator->remove_link( -one => $obj1, -many => $obj2 );
 Function: Removes link between objects
 Returns : $self
 Args    : -one  => $obj1 (source of a one-to-many relationship)
           -many => $obj2 (target of a one-to-many relationship)

           (-many argument is optional)

 Comments: This method is called from within, for example, 
           unset_taxa method calls. A call like $matrix->unset_taxa() 
           is rerouted to:

           $mediator->remove_link( -many => $matrix );

           A call like $taxa->unset_matrix( $matrix ); is rerouted to:

           $mediator->remove_link( -one => $taxa, -many => $matrix );


=cut

    sub remove_link {
        my $self = shift;
        my %opt  = @_;
        my ( $one, $many ) = ( $opt{'-one'}, $opt{'-many'} );
        my $many_id = $many->get_id;
        my $one_id;
        if ($one) {
            $one_id = $one->get_id;            
        }
        else {
            my $target = $self->get_link( '-source' => $many );
            $one_id = $target->get_id if $target;
        }
        delete $one_to_many{$one_id}->{$many_id} if $one_id and $one_to_many{$one_id};          
        delete $one_to_one{$many_id};
    }

=back

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

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
