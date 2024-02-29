package Bio::Phylo;
use strict;
use warnings;
use Bio::PhyloRole;
use base 'Bio::PhyloRole';

# don't use Scalar::Util::looks_like_number directly, use wrapped version
use Scalar::Util qw'weaken blessed';
use Bio::Phylo::Util::CONSTANT '/looks_like/';
use Bio::Phylo::Util::IDPool;             # creates unique object IDs
use Bio::Phylo::Util::Exceptions 'throw'; # defines exception classes and throws
use Bio::Phylo::Util::Logger;             # for logging, like log4perl/log4j
use Bio::Phylo::Util::MOP;                # for traversing inheritance trees
use Bio::Phylo::Identifiable;             # for storing unique IDs inside an instance

our ( $logger, $COMPAT ) = Bio::Phylo::Util::Logger->new;
use version 0.77; our $VERSION = qv("v2.0.1");

# mediates one-to-many relationships between taxon and nodes,
# taxon and sequences, taxa and forests, taxa and matrices.
# Read up on the Mediator design pattern to learn how this works.
require Bio::Phylo::Mediators::TaxaMediator;


{
    my $taxamediator = 'Bio::Phylo::Mediators::TaxaMediator';
    my $mop = 'Bio::Phylo::Util::MOP';

    sub import {
        my $class = shift;
        if (@_) {
            my %opt = looks_like_hash @_;
            while ( my ( $key, $value ) = each %opt ) {
                if ( $key =~ qr/^VERBOSE$/i ) {
                    $logger->VERBOSE( '-level' => $value, '-class' => $class );
                }
                elsif ( $key =~ qr/^COMPAT$/i ) {
                    $COMPAT = ucfirst( lc($value) );
                }
                else {
                    throw 'BadArgs' => "'$key' is not a valid argument for import";
                }
            }
        }
        return 1;
    }

    # the following hashes are used to hold state of inside-out objects. For
    # example, $obj->set_name("name") is implemented as $name{ $obj->get_id }
    # = $name. To avoid memory leaks (and subtle bugs, should a new object by
    # the same id appear (though that shouldn't happen)), the hash slots
    # occupied by $obj->get_id need to be reclaimed in the destructor. This
    # is done by recursively calling the $obj->_cleanup methods in all of $obj's
    # superclasses. To make that method easier to write, we create an  array
    # with the local inside-out hashes here, so that we can just iterate over
    # them anonymously during destruction cleanup. Other classes do something
    # like this as well.
    my @fields = \(
        my (
			%guid,
            %desc,
            %score,
            %generic,
            %cache,
            %container,    # XXX weak reference
            %objects       # XXX weak reference
        )
    );

=head1 NAME

Bio::Phylo - Phylogenetic analysis using perl

=head1 SYNOPSIS

 # Actually, you would almost never use this module directly. This is 
 # the base class for other modules.
 use Bio::Phylo;
 
 # sets global verbosity to 'error'
 Bio::Phylo->VERBOSE( -level => Bio::Phylo::Util::Logger::ERROR );
 
 # sets verbosity for forest ojects to 'debug'
 Bio::Phylo->VERBOSE( 
 	-level => Bio::Phylo::Util::Logger::DEBUG, 
 	-class => 'Bio::Phylo::Forest' 
 );
 
 # prints version, including SVN revision number
 print Bio::Phylo->VERSION;
 
 # prints suggested citation
 print Bio::Phylo->CITATION;

=head1 DESCRIPTION

This is the base class for the Bio::Phylo package for phylogenetic analysis using 
object-oriented perl5. In this file, methods are defined that are performed by other 
objects in the Bio::Phylo release that inherit from this base class (which you normally
wouldn't use directly).

For general information on how to use Bio::Phylo, consult the manual
(L<Bio::Phylo::Manual>).

If you come here because you are trying to debug a problem you run into in
using Bio::Phylo, you may be interested in the "exceptions" system as discussed
in L<Bio::Phylo::Util::Exceptions>. In addition, you may find the logging system
in L<Bio::Phylo::Util::Logger> of use to localize problems.

=head1 METHODS

=head2 CONSTRUCTOR

=over

=item new()

The Bio::Phylo root constructor is rarely used directly. Rather, many other 
objects in Bio::Phylo internally go up the inheritance tree to this constructor. 
The arguments shown here can therefore also be passed to any of the child 
classes' constructors, which will pass them on up the inheritance tree. Generally, 
constructors in Bio::Phylo subclasses can process as arguments all methods that 
have set_* in their names. The arguments are named for the methods, but "set_" 
has been replaced with a dash "-", e.g. the method "set_name" becomes the 
argument "-name" in the constructor.

 Type    : Constructor
 Title   : new
 Usage   : my $phylo = Bio::Phylo->new;
 Function: Instantiates Bio::Phylo object
 Returns : a Bio::Phylo object 
 Args    : Optional, any number of setters. For example,
 		   Bio::Phylo->new( -name => $name )
 		   will call set_name( $name ) internally

=cut

    sub new : Constructor {

        # $class could be a child class, called from $class->SUPER::new(@_)
        # or an object, e.g. $node->new(%args) in which case we create a new
        # object that's bless into the same class as the invocant. No, that's
        # not the same thing as a clone.
        my $class = shift;
        if ( my $reference = ref $class ) {
            $class = $reference;
        }

        # happens only and exactly once because this
        # root class is visited from every constructor
        my $self = $class->SUPER::new();

        # register for get_obj_by_id
        my $id = $self->get_id;
        $objects{$id} = $self;
        weaken( $objects{$id} );
		
	# notify user
        $logger->info("constructor called for '$class' - $id");

        # processing arguments
        if ( @_ and @_ = looks_like_hash @_ ) {
	    $logger->info("processing arguments");

            # process all arguments
          ARG: while (@_) {
                my $key   = shift @_;
                my $value = shift @_;

                # this is a bioperl arg, meant to set
                # verbosity at a per class basis. In
                # bioperl, the $verbose argument is
                # subsequently carried around in that
                # class, here we delegate that to the
                # logger, which has roughly the same
                # effect.
                if ( $key eq '-verbose' ) {
                    $logger->VERBOSE(
                        '-level' => $value,
                        '-class' => $class,
                    );
                    next ARG;
                }

                # notify user
                $logger->debug("processing constructor arg '${key}' => '${value}'");

                # don't access data structures directly, call mutators
                # in child classes or __PACKAGE__
                my $mutator = $key;
                $mutator =~ s/^-/set_/;

                # backward compat fixes:
                $mutator =~ s/^set_pos$/set_position/;
                $mutator =~ s/^set_matrix$/set_raw/;
                eval { $self->$mutator($value); };
                if ($@) {
                    if ( blessed $@ and $@->can('rethrow') ) {
                        $@->rethrow;
                    }
                    elsif ( not ref($@) and $@ =~ /^Can't locate object method / ) {
                        throw 'BadArgs' => "The named argument '${key}' cannot be passed to the constructor of ${class}";
                    }
                    else {
                        throw 'Generic' => $@;
                    }
                }
            }
        }
	$logger->info("done processing constructor arguments");

        # register with mediator
        # TODO this is irrelevant for some child classes,
        # so should be re-factored into somewhere nearer the
        # tips of the inheritance tree. The hack where we
        # skip over direct instances of Writable is so that
        # we don't register things like <format> and <matrix> tags
        if ( ref $self ne 'Bio::Phylo::NeXML::Writable' && ! $self->isa('Bio::Phylo::Matrices::Datatype') ) {
	    $logger->info("going to register $self with $taxamediator");
            $taxamediator->register($self);
        }
	$logger->info("done building object");
        return $self;
    }

=back

=head2 MUTATORS

=over

=item set_guid()

Sets invocant GUID.

 Type    : Mutator
 Title   : set_guid
 Usage   : $obj->set_guid($guid);
 Function: Assigns an object's GUID.
 Returns : Modified object.
 Args    : A scalar
 Notes   : This field can be used for storing an identifier that is
           unambiguous within a given content. For example, an LSID,
	   a genbank accession number, etc.

=cut

    sub set_guid : Clonable {
        my ( $self, $guid ) = @_;
        if ( defined $guid ) {
        	$guid{ $self->get_id } = $guid;
        }
        else {
        	delete $guid{ $self->get_id };
        }
        return $self;
    }


=item set_desc()

Sets invocant description.

 Type    : Mutator
 Title   : set_desc
 Usage   : $obj->set_desc($desc);
 Function: Assigns an object's description.
 Returns : Modified object.
 Args    : Argument must be a string.

=cut

    sub set_desc : Clonable {
        my ( $self, $desc ) = @_;
        if ( defined $desc ) {
        	$desc{ $self->get_id } = $desc;
        }
        else {
        	delete $desc{ $self->get_id };
        }
        return $self;
    }

=item set_score()

Sets invocant score.

 Type    : Mutator
 Title   : set_score
 Usage   : $obj->set_score($score);
 Function: Assigns an object's numerical score.
 Returns : Modified object.
 Args    : Argument must be any of
           perl's number formats, or undefined
           to reset score.

=cut

    sub set_score : Clonable {
        my ( $self, $score ) = @_;

        # $score must be a number (or undefined)
        if ( defined $score ) {
            if ( !looks_like_number($score) ) {
                throw 'BadNumber' => "score \"$score\" is a bad number";
            }

            # notify user
            $logger->info("setting score '$score'");
	        $score{ $self->get_id } = $score;            
        }
        else {
            $logger->info("unsetting score");
            delete $score{ $self->get_id };
        }

        return $self;
    }

=item set_generic()

Sets generic key/value pair(s).

 Type    : Mutator
 Title   : set_generic
 Usage   : $obj->set_generic( %generic );
 Function: Assigns generic key/value pairs to the invocant.
 Returns : Modified object.
 Args    : Valid arguments constitute:

           * key/value pairs, for example:
             $obj->set_generic( '-lnl' => 0.87565 );

           * or a hash ref, for example:
             $obj->set_generic( { '-lnl' => 0.87565 } );

           * or nothing, to reset the stored hash, e.g.
                $obj->set_generic( );

=cut

    sub set_generic : Clonable {
        my $self = shift;

        # retrieve id just once, don't call $self->get_id in loops, inefficient
        my $id = $self->get_id;

		# this initializes the hash if it didn't exist yet, or resets it if no args
        if ( !defined $generic{$id} || !@_ ) {
            $generic{$id} = {};
        }

        # have args
        if (@_) {
            my %args;

            # have a single arg, a hash ref
            if ( scalar @_ == 1 && looks_like_instance( $_[0], 'HASH' ) ) {
                %args = %{ $_[0] };
            }

            # multiple args, hopefully even size key/value pairs
            else {
                %args = looks_like_hash @_;
            }

            # notify user
            $logger->info("setting generic key/value pairs %{args}");

            # fill up the hash
            for my $key ( keys %args ) {
                $generic{$id}->{$key} = $args{$key};
            }
        }
        return $self;
    }

=back

=head2 ACCESSORS

=over

=item get_guid()

Gets invocant GUID.

 Type    : Accessor
 Title   : get_guid
 Usage   : my $guid = $obj->get_guid;
 Function: Assigns an object's GUID.
 Returns : Scalar.
 Args    : None
 Notes   : This field can be used for storing an identifier that is
           unambiguous within a given content. For example, an LSID,
	   a genbank accession number, etc.

=cut

    sub get_guid { $guid{ shift->get_id } }

=item get_desc()

Gets invocant description.

 Type    : Accessor
 Title   : get_desc
 Usage   : my $desc = $obj->get_desc;
 Function: Returns the object's description (if any).
 Returns : A string
 Args    : None

=cut

    sub get_desc { $desc{ shift->get_id } }

=item get_score()

Gets invocant's score.

 Type    : Accessor
 Title   : get_score
 Usage   : my $score = $obj->get_score;
 Function: Returns the object's numerical score (if any).
 Returns : A number
 Args    : None

=cut

    sub get_score { $score{ shift->get_id } }

=item get_generic()

Gets generic hashref or hash value(s).

 Type    : Accessor
 Title   : get_generic
 Usage   : my $value = $obj->get_generic($key);
           or
           my %hash = %{ $obj->get_generic() };
 Function: Returns the object's generic data. If an
           argument is used, it is considered a key
           for which the associated value is returned.
           Without arguments, a reference to the whole
           hash is returned.
 Returns : A value or an array reference of values
 Args    : A key (string) or an array reference of keys

=cut

    sub get_generic {
        my ( $self, $key ) = @_;

        # retrieve just once
        my $id = $self->get_id;

        # might not even have a generic hash yet, make one on-the-fly
        if ( not defined $generic{$id} ) {
            $generic{$id} = {};
        }

        # have an argument
        if ( defined $key ) {

			if ( ref($key) eq 'ARRAY' ) {
				my @result = @generic{@$key};
				return \@result;
			}
			else {
				# notify user
				$logger->debug("getting value for key '$key'");
				return $generic{$id}->{$key};
			}
        }

        # no argument, wants whole hash
        else {

            # notify user
            $logger->debug("retrieving generic hash");
            return $generic{$id};
        }
    }

=back

=head2 PACKAGE METHODS

=over

=item get_obj_by_id()

Attempts to fetch an in-memory object by its UID

 Type    : Accessor
 Title   : get_obj_by_id
 Usage   : my $obj = Bio::Phylo->get_obj_by_id($uid);
 Function: Fetches an object from the IDPool cache
 Returns : A Bio::Phylo object 
 Args    : A unique id

=cut

    sub get_obj_by_id {
        my ( $class, $id ) = @_;
        return $objects{$id};
    }

=item get_logger()

Returns a singleton reference to a Bio::Phylo::Util::Logger object

 Type    : Accessor
 Title   : get_logger
 Usage   : my $logger = Bio::Phylo->get_logger
 Function: Returns logger
 Returns : A Bio::Phylo::Util::Logger object 
 Args    : None

=cut
    
    sub get_logger { $logger }

=item VERSION()

Returns the $VERSION string of this Bio::Phylo release

 Type    : Accessor
 Title   : VERSION
 Usage   : my $version = Bio::Phylo->VERSION
 Function: Returns version string
 Returns : A string
 Args    : None

=cut
    
    sub VERSION { $VERSION }

=item clone()

Clones invocant.

 Type    : Utility method
 Title   : clone
 Usage   : my $clone = $object->clone;
 Function: Creates a copy of the invocant object.
 Returns : A copy of the invocant.
 Args    : None.
 Comments: Cloning is currently experimental, use with caution.

=cut

    sub clone {
        my ( $self, $deep ) = @_;
        $deep = 1 unless defined $deep;
	
	# compute and instantiate the constructor nearest to the tips of
	# the inheritance tree
	my $constructors = $mop->get_constructors($self); my $clone =
	$constructors->[0]->{'code'}->(ref $self);

	# keep track of which methods we've done, including overrides
	my %seen;
	
	# do the deep cloning first
	if ( $deep ) {
	    
	    # get the deeply clonable methods
	    my $clonables = $mop->get_deep_clonables($self);
	    for my $setter ( @{ $clonables } ) {
		my $setter_name = $setter->{'name'};
	
		# only do this for the shallowest method with
		# the same name: the others are overrided
		if ( not $seen{$setter_name} ) {
		    $seen{$setter_name}++;
    
		    # pass the output of the getter to the
		    # input of the setter
		    my $output = $self->_get_clonable_output($setter);
		    my $input;
		    if ( ref $output eq 'ARRAY' ) {
			$input = [
			    map { ref $_ ? $_->clone($deep) : $_ }
			    @{ $output }
			];
		    }
		    elsif ( $output and ref $output ) {
			$input = $output->clone($deep);
		    }
		    $setter->{'code'}->($clone,$input);
		}
	    }
	}
		
	# get the clonable methods
	my $clonables = $mop->get_clonables($self);		
	for my $setter ( @{ $clonables } ) {
	    my $setter_name = $setter->{'name'};
    
	    # only do this for the shallowest method with the
	    # same name: the others are overrided
	    if ( not $seen{$setter_name} ) {
		$seen{$setter_name}++;
		my $output = $self->_get_clonable_output($setter);
		$setter->{'code'}->($clone,$output);
	    }		
	}
	return $clone;
    }
    
    sub _get_clonable_output {
	my ( $self, $setter ) = @_;
	my $setter_name = $setter->{'name'};
	
	# assume getter/setter symmetry
	my $getter_name = $setter_name;
	$getter_name =~ s/^(_?)set_/$1get_/;
	my $fqn = $setter->{'package'} . '::' . $getter_name;

	# get the code reference for the fully qualified name of the getter
	my $getter = $mop->get_method($fqn);

	# pass the output of the getter to the input of the setter
	my $output = $getter->($self);
	return $output;
    }

=begin comment

Invocant destructor.

 Type    : Destructor
 Title   : DESTROY
 Usage   : $phylo->DESTROY
 Function: Destroys Phylo object
 Alias   :
 Returns : TRUE
 Args    : none
 Comments: You don't really need this,
           it is called automatically when
           the object goes out of scope.

=end comment

=cut

	sub DESTROY {
		my $self = shift;

		# delete from get_obj_by_id
		my $id;
		if ( defined( $id = $self->get_id ) ) {
			delete $objects{$id};
		}

		# do the cleanups
# 		my @destructors = @{ $mop->get_destructors( $self ) };
# 		for my $d ( @destructors ) {			
# 			$d->{'code'}->( $self );
# 		}
		my @classes = @{ $mop->get_classes($self) };
		for my $class ( @classes ) {
			my $cleanup = "${class}::_cleanup";
			if ( $class->can($cleanup) ) {				
				$self->$cleanup;
			}
		}
		
		# unregister from mediator
		$taxamediator->unregister( $self );

		# done cleaning up, id can be reclaimed
		Bio::Phylo::Util::IDPool->_reclaim( $self );
	}


    # child classes probably should have a method like this,
    # if their objects hold internal state anyway (b/c they'll
    # be inside-out objects).
    sub _cleanup : Destructor {
        my $self = shift;
        my $id = $self->get_id;

        # cleanup local fields
        if ( defined $id ) {
            for my $field (@fields) {
                delete $field->{$id};
            }
        }
    }

=begin comment

 Type    : Internal method
 Title   : _get_container
 Usage   : $phylo->_get_container;
 Function: Retrieves the object that contains the invocant (e.g. for a node,
           returns the tree it is in).
 Returns : Bio::Phylo::* object
 Args    : None

=end comment

=cut

    # this is the converse of $listable->get_entities, i.e.
    # every entity in a listable object holds a reference
    # to its container. We actually use this surprisingly
    # rarely, and because I read somewhere (heh) it's bad
    # to have the objects of a has-a relationship fiddle with
    # their container we hide this method from abuse. Then
    # again, sometimes it's handy ;-)
    sub _get_container { $container{ shift->get_id } }

=begin comment

 Type    : Internal method
 Title   : _set_container
 Usage   : $phylo->_set_container($obj);
 Function: Creates a reference from the invocant to the object that contains
           it (e.g. for a node, creates a reference to the tree it is in).
 Returns : Bio::Phylo::* object
 Args    : A Bio::Phylo::Listable object

=end comment

=cut

    sub _set_container {
        my ( $self, $container ) = @_;
        my $id = $self->get_id;
        if ( blessed $container ) {
            if ( $container->can('can_contain') ) {
                if ( $container->can_contain($self) ) {
                    if ( $container->contains($self) ) {
                        $container{$id} = $container;
                        weaken( $container{$id} );                        
                    }
                    else {
                        throw 'ObjectMismatch' => "'$self' not in '$container'";
                    }
                }
                else {
                    throw 'ObjectMismatch' =>
                      "'$container' cannot contain '$self'";
                }
            }
            else {
                throw 'ObjectMismatch' => "Invalid objects";
            }
        }
        else {
			delete $container{$id};
				#throw 'BadArgs' => "Argument not an object";
		}
		return $self;
    }
    
=item to_js()

Serializes to simple JSON. For a conversion to NeXML/JSON, use C<to_json>.

 Type    : Serializer
 Title   : to_js
 Usage   : my $json = $object->to_js;
 Function: Serializes to JSON
 Returns : A JSON string
 Args    : None.
 Comments: 

=cut

	sub to_js {JSON::to_json(shift->_json_data,{'pretty'=>1}) if looks_like_class 'JSON'}    
    
    sub _json_data {
    	my $self = shift;
    	my %data = %{ $self->get_generic };
    	$data{'guid'}  = $self->get_guid if $self->get_guid;
    	$data{'desc'}  = $self->get_desc if $self->get_desc;
    	$data{'score'} = $self->get_score if $self->get_score;
    	return \%data;
    }

=back

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
