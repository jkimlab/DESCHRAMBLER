package Bio::Phylo::ListableRole;
use strict;
use warnings;
use Bio::Phylo::Util::MOP;
use base 'Bio::Phylo::NeXML::Writable';
use Scalar::Util qw'blessed';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw':all';

{
    my $logger = __PACKAGE__->get_logger;
    my ( $DATUM, $NODE, $MATRIX, $TREE ) =
      ( _DATUM_, _NODE_, _MATRIX_, _TREE_ );

=head1 NAME

Bio::Phylo::ListableRole - Extra functionality for things that are lists

=head1 SYNOPSIS

 No direct usage, parent class. Methods documented here 
 are available for all objects that inherit from it.

=head1 DESCRIPTION

A listable object is an object that contains multiple smaller objects of the
same type. For example: a tree contains nodes, so it's a listable object.

This class contains methods that are useful for all listable objects: Matrices
(i.e. sets of matrix objects), individual Matrix objects, Datum objects (i.e.
character state sequences), Taxa, Forest, Tree and Node objects.

=head1 METHODS

=head2 ARRAY METHODS

=over

=item prune_entities()

Prunes the container's contents specified by an array reference of indices.

 Type    : Mutator
 Title   : prune_entities
 Usage   : $list->prune_entities([9,7,7,6]);
 Function: Prunes a subset of contents
 Returns : A Bio::Phylo::Listable object.
 Args    : An array reference of indices

=cut

    sub prune_entities {
        my ( $self, @indices ) = @_;
        my %indices = map { $_ => 1 } @indices;
        my $last_index = $self->last_index;
        my @keep;
        for my $i ( 0 .. $last_index ) {
            push @keep, $i if not exists $indices{$i};
        }
        return $self->keep_entities( \@keep );
    }

=item get_index_of()

Returns the index of the argument in the list,
or undef if the list doesn't contain the argument

 Type    : Accessor
 Title   : get_index_of
 Usage   : my $i = $listable->get_index_of($obj)
 Function: Returns the index of the argument in the list,
           or undef if the list doesn't contain the argument
 Returns : An index or undef
 Args    : A contained object

=cut

    sub get_index_of {
        my ( $self, $obj ) = @_;
        my $id = $obj->get_id;
        my $i  = 0;
        for my $ent ( @{ $self->get_entities } ) {
            return $i if $ent->get_id == $id;
            $i++;
        }
        return;
    }

=item get_by_index()

Gets element at index from container.

 Type    : Accessor
 Title   : get_by_index
 Usage   : my $contained_obj = $obj->get_by_index($i);
 Function: Retrieves the i'th entity 
           from a listable object.
 Returns : An entity stored by a listable 
           object (or array ref for slices).
 Args    : An index or range. This works 
           the way you dereference any perl
           array including through slices, 
           i.e. $obj->get_by_index(0 .. 10)>
           $obj->get_by_index(0, -1) 
           and so on.
 Comments: Throws if out-of-bounds

=cut

    sub get_by_index {
        my $self     = shift;
        my $entities = $self->get_entities;
        my @range    = @_;
        if ( scalar @range > 1 ) {
            my @returnvalue;
            eval { @returnvalue = @{$entities}[@range] };
            if ($@) {
                throw 'OutOfBounds' => 'index out of bounds';
            }
            return \@returnvalue;
        }
        else {
            my $returnvalue;
            eval { $returnvalue = $entities->[ $range[0] ] };
            if ($@) {
                throw 'OutOfBounds' => 'index out of bounds';
            }
            return $returnvalue;
        }
    }

=item get_by_regular_expression()

Gets elements that match regular expression from container.

 Type    : Accessor
 Title   : get_by_regular_expression
 Usage   : my @objects = @{ 
               $obj->get_by_regular_expression(
                    -value => $method,
                    -match => $re
            ) };
 Function: Retrieves the data in the 
           current Bio::Phylo::Listable 
           object whose $method output 
           matches $re
 Returns : A list of Bio::Phylo::* objects.
 Args    : -value => any of the string 
                     datum props (e.g. 'get_type')
           -match => a compiled regular 
                     expression (e.g. qr/^[D|R]NA$/)

=cut

    sub get_by_regular_expression {
        my $self = shift;
        my %o    = looks_like_hash @_;
        my @matches;
        for my $e ( @{ $self->get_entities } ) {
            if ( $o{-match} && looks_like_instance( $o{-match}, 'Regexp' ) ) {
                if (   $e->get( $o{-value} )
                    && $e->get( $o{-value} ) =~ $o{-match} )
                {
                    push @matches, $e;
                }
            }
            else {
                throw 'BadArgs' => 'need a regular expression to evaluate';
            }
        }
        return \@matches;
    }

=item get_by_value()

Gets elements that meet numerical rule from container.

 Type    : Accessor
 Title   : get_by_value
 Usage   : my @objects = @{ $obj->get_by_value(
              -value => $method,
              -ge    => $number
           ) };
 Function: Iterates through all objects 
           contained by $obj and returns 
           those for which the output of 
           $method (e.g. get_tree_length) 
           is less than (-lt), less than 
           or equal to (-le), equal to 
           (-eq), greater than or equal to 
           (-ge), or greater than (-gt) $number.
 Returns : A reference to an array of objects
 Args    : -value => any of the numerical 
                     obj data (e.g. tree length)
           -lt    => less than
           -le    => less than or equals
           -eq    => equals
           -ge    => greater than or equals
           -gt    => greater than

=cut

    sub get_by_value {
        my $self = shift;
        my %o    = looks_like_hash @_;
        my @results;
        for my $e ( @{ $self->get_entities } ) {
            if ( $o{-eq} ) {
                if (   $e->get( $o{-value} )
                    && $e->get( $o{-value} ) == $o{-eq} )
                {
                    push @results, $e;
                }
            }
            if ( $o{-le} ) {
                if (   $e->get( $o{-value} )
                    && $e->get( $o{-value} ) <= $o{-le} )
                {
                    push @results, $e;
                }
            }
            if ( $o{-lt} ) {
                if (   $e->get( $o{-value} )
                    && $e->get( $o{-value} ) < $o{-lt} )
                {
                    push @results, $e;
                }
            }
            if ( $o{-ge} ) {
                if (   $e->get( $o{-value} )
                    && $e->get( $o{-value} ) >= $o{-ge} )
                {
                    push @results, $e;
                }
            }
            if ( $o{-gt} ) {
                if (   $e->get( $o{-value} )
                    && $e->get( $o{-value} ) > $o{-gt} )
                {
                    push @results, $e;
                }
            }
        }
        return \@results;
    }

=item get_by_name()

Gets first element that has argument name

 Type    : Accessor
 Title   : get_by_name
 Usage   : my $found = $obj->get_by_name('foo');
 Function: Retrieves the first contained object
           in the current Bio::Phylo::Listable 
           object whose name is 'foo'
 Returns : A Bio::Phylo::* object.
 Args    : A name (string)

=cut

    sub get_by_name {
        my ( $self, $name ) = @_;
        if ( not defined $name or ref $name ) {
            throw 'BadString' => "Can't search on name '$name'";
        }
        for my $obj ( @{ $self->get_entities } ) {
            my $obj_name = $obj->get_name;
            if ( $obj_name and $name eq $obj_name ) {
                return $obj;
            }
        }
        return;
    }

=back

=head2 VISITOR METHODS

=over

=item visit()

Iterates over objects contained by container, executes argument
code reference on each.

 Type    : Visitor predicate
 Title   : visit
 Usage   : $obj->visit( 
               sub{ print $_[0]->get_name, "\n" } 
           );
 Function: Implements visitor pattern 
           using code reference.
 Returns : The container, possibly modified.
 Args    : a CODE reference.

=cut

    sub visit {
        my ( $self, $code ) = @_;
        if ( looks_like_instance( $code, 'CODE' ) ) {
            for ( @{ $self->get_entities } ) {
                $code->($_);
            }
        }
        else {
            throw 'BadArgs' => "\"$code\" is not a CODE reference!";
        }
        return $self;
    }

=back

=head2 TESTS

=over

=item contains()

Tests whether the container object contains the argument object.

 Type    : Test
 Title   : contains
 Usage   : if ( $obj->contains( $other_obj ) ) {
               # do something
           }
 Function: Tests whether the container object 
           contains the argument object
 Returns : BOOLEAN
 Args    : A Bio::Phylo::* object

=cut

    sub contains {
        my ( $self, $obj ) = @_;
        if ( blessed $obj ) {
            my $id = $obj->get_id;
            for my $ent ( @{ $self->get_entities } ) {
                next if not $ent;
                return 1 if $ent->get_id == $id;
            }
            return 0;
        }
        else {
            for my $ent ( @{ $self->get_entities } ) {
                next if not $ent;
                return 1 if $ent eq $obj;
            }
        }
    }

=item can_contain()

Tests if argument can be inserted in container.

 Type    : Test
 Title   : can_contain
 Usage   : &do_something if $listable->can_contain( $obj );
 Function: Tests if $obj can be inserted in $listable
 Returns : BOOL
 Args    : An $obj to test

=cut

    sub can_contain {
        my ( $self, @obj ) = @_;
        for my $obj (@obj) {
            my ( $self_type, $obj_container );
            eval {
                $self_type     = $self->_type;
                $obj_container = $obj->_container;
            };
            if ( $@ or $self_type != $obj_container ) {
                if ( not $@ ) {
                    $logger->info(" $self $self_type != $obj $obj_container");
                }
                else {
                    $logger->info($@);
                }
                return 0;
            }
        }
        return 1;
    }

=back

=head2 UTILITY METHODS

=over

=item cross_reference()

The cross_reference method links node and datum objects to the taxa they apply
to. After crossreferencing a matrix with a taxa object, every datum object has
a reference to a taxon object stored in its C<$datum-E<gt>get_taxon> field, and
every taxon object has a list of references to datum objects stored in its
C<$taxon-E<gt>get_data> field.

 Type    : Generic method
 Title   : cross_reference
 Usage   : $obj->cross_reference($taxa);
 Function: Crossreferences the entities 
           in the container with names 
           in $taxa
 Returns : string
 Args    : A Bio::Phylo::Taxa object
 Comments:

=cut

    sub cross_reference {
        my ( $self, $taxa ) = @_;
        my ( $selfref, $taxref ) = ( ref $self, ref $taxa );
        if ( looks_like_implementor( $taxa, 'get_entities' ) ) {
            my $ents = $self->get_entities;
            if ( $ents && @{$ents} ) {
                foreach ( @{$ents} ) {
                    if (   looks_like_implementor( $_, 'get_name' )
                        && looks_like_implementor( $_, 'set_taxon' ) )
                    {
                        my $tax = $taxa->get_entities;
                        if ( $tax && @{$tax} ) {
                            foreach my $taxon ( @{$tax} ) {
                                if ( not $taxon->get_name or not $_->get_name )
                                {
                                    next;
                                }
                                if ( $taxon->get_name eq $_->get_name ) {
                                    $_->set_taxon($taxon);
                                    if ( $_->_type == $DATUM ) {
                                        $taxon->set_data($_);
                                    }
                                    if ( $_->_type == $NODE ) {
                                        $taxon->set_nodes($_);
                                    }
                                }
                            }
                        }
                    }
                    else {
                        throw 'ObjectMismatch' =>
                          "$selfref can't link to $taxref";
                    }
                }
            }
            if ( $self->_type == $TREE ) {
                $self->_get_container->set_taxa($taxa);
            }
            elsif ( $self->_type == $MATRIX ) {
                $self->set_taxa($taxa);
            }
            return $self;
        }
        else {
            throw 'ObjectMismatch' => "$taxref does not contain taxa";
        }
    }

=item alphabetize()

Sorts the contents alphabetically by their name.

 Type    : Generic method
 Title   : alphabetize
 Usage   : $obj->alphabetize;
 Function: Sorts the contents alphabetically by their name.
 Returns : $self
 Args    : None
 Comments:

=cut
    
    sub alphabetize {
        my $self = shift;
        my @sorted = map { $_->[0] }
                     sort { $_->[1] cmp $_->[1] }
                     map { [ $_, $_->get_internal_name ] }
                     @{ $self->get_entities };
        $self->clear;
        $self->insert($_) for @sorted;
        return $self;
    }
    
=back

=head2 SETS MANAGEMENT

Many Bio::Phylo objects are segmented, i.e. they contain one or more subparts 
of the same type. For example, a matrix contains multiple rows; each row 
contains multiple cells; a tree contains nodes, and so on. (Segmented objects
all inherit from Bio::Phylo::Listable, i.e. the class whose documentation you're
reading here.) In many cases it is useful to be able to define subsets of the 
contents of segmented objects, for example sets of taxon objects inside a taxa 
block. The Bio::Phylo::Listable object allows this through a number of methods 
(add_set, remove_set, add_to_set, remove_from_set etc.). Those methods delegate 
the actual management of the set contents to the L<Bio::Phylo::Set> object. 
Consult the documentation for L<Bio::Phylo::Set> for a code sample.

=over

=item sets_to_xml()

Returns string representation of sets

 Type    : Accessor
 Title   : sets_to_xml
 Usage   : my $str = $obj->sets_to_xml;
 Function: Gets xml string
 Returns : Scalar
 Args    : None

=cut

    sub sets_to_xml {
        my $self = shift;
        my $xml = '';
        if ( $self->can('get_sets') ) {
            for my $set ( @{ $self->get_sets } ) {
                my %contents;
                for my $ent ( @{ $self->get_entities } ) {
                    if ( $self->is_in_set($ent,$set) ) {
                        my $tag = $ent->get_tag;
                        $contents{$tag} = [] if not $contents{$tag};
                        push @{ $contents{$tag} }, $ent->get_xml_id;
                    }
                }
                for my $key ( keys %contents ) {
                    my @ids = @{ $contents{$key} };
                    $contents{$key} = join ' ', @ids;
                }
                $set->set_attributes(%contents);
                $xml .= "\n" . $set->to_xml;
            }
        }
        return $xml;
    }

=back

=cut

    # podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

Also see the manual: L<Bio::Phylo::Manual> and L<http://rutgervos.blogspot.com>.

=head2 Objects inheriting from Bio::Phylo::Listable

=over

=item L<Bio::Phylo::Forest>

Iterate over a set of trees.

=item L<Bio::Phylo::Forest::Tree>

Iterate over nodes in a tree.

=item L<Bio::Phylo::Forest::Node>

Iterate of children of a node.

=item L<Bio::Phylo::Matrices>

Iterate over a set of matrices.

=item L<Bio::Phylo::Matrices::Matrix>

Iterate over the datum objects in a matrix.

=item L<Bio::Phylo::Matrices::Datum>

Iterate over the characters in a datum.

=item L<Bio::Phylo::Taxa>

Iterate over a set of taxa.

=back

=head2 Superclasses

=over

=item L<Bio::Phylo::NeXML::Writable>

This object inherits from L<Bio::Phylo::NeXML::Writable>, so methods
defined there are also applicable here.

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
