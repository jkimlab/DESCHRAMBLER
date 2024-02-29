package Bio::Phylo::Util::MOP;
use strict;
use warnings;
use attributes;
use Attribute::Handlers;
use Data::Dumper;
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::Logger ':levels';
use Scalar::Util qw( refaddr );

=head1 NAME

Bio::Phylo::Util::MOP - Meta-object programming, no serviceable parts inside

=cut

# this will be populated when the attribute handlers are triggered
my %methods;

# this will progressively store/memoize all superclasses for given classes
my %classes;

# this will progressively store/memoize the methods for given classes
my %class_methods;

# this might be used to check the interface of alien subclasses
sub import {
    
}

# my %sims = $mop->get_symtable('Bio::Phylo');
sub get_symtable {
    my ( $self, $package ) = @_;
    my %symtable;
    {
        no strict 'refs';
        %symtable = %{"${package}::"};
        use strict;
    }
    return \%symtable;    
}

# $mop->get_method('Bio::Phylo::new')->()
sub get_method {
    my ( $self, $fqn ) = @_;
    my $coderef;
    eval {
        no strict 'refs';
        $coderef = \&{"${fqn}"};
        use strict;
    };
    return $coderef;
}

# @methods = @{ $mop->get_implementations( 'new', $obj || $package ) };
sub get_implementations {
	my ( $self, $method, $obj ) = @_;
	my @methods = grep { $_->{'name'} eq $method } @{ $self->get_methods($obj) };
	return \@methods;
}

# my @classes = @{ $mop->get_classes($obj) }
sub get_classes {
    my ( $self, $obj, $all ) = @_;
    my $class = ref $obj || $obj;
    
    # return if already cached
    if ( $classes{$class} ) {
    	return $classes{$class};
    }
    
    # compute, cache, return
    else {
    	my ( $seen, $isa ) = ( {}, [] );
	    _recurse_isa($class, $isa, $seen, $all);
	    $classes{$class} = $isa;
    	return $isa;
    }
}

# starting from $class, push all superclasses (+$class) into @$isa,
# %$seen is just a helper to avoid getting stuck in cycles
sub _recurse_isa {
    my ( $class, $isa, $seen, $all ) = @_;
    if ( not $seen->{$class} ) {
        $seen->{$class} = 1;
        if ( ( $class ne 'Exporter' and $class ne 'DynaLoader' ) or $all ) {
            push @{$isa}, $class;
        }
        my @isa;
        {
            no strict 'refs';
            @isa = @{"${class}::ISA"};
            use strict;
        }
        _recurse_isa( $_, $isa, $seen, $all ) for @isa;
    }
}

# my @methods = @{ $mop->get_methods($obj) };
sub get_methods {
    my ( $self, $obj ) = @_;
    my $class = ref $obj || $obj;
    
    # return if already cached
    if ( $class_methods{$class} ) {
    	return $class_methods{$class};
    }
    
    # compute, cache, return
    else {
		my $isa = $self->get_classes($obj);
		my @methods;
		for my $package ( @{ $isa } ) {

			my %symtable = %{ $self->get_symtable($package) };		
		
			# at this point we have lots of things, we just want methods
			for my $entry ( keys %symtable ) {
			
				# check if entry is a CODE reference
				my $can = $package->can( $entry );
				if ( ref $can eq 'CODE' ) {
					push @methods, {
						'package'    => $package,
						'name'       => $entry,
						'glob'       => $symtable{$entry},
						'code'       => $can,
					};
				}
			}
		}
		$class_methods{$class} = \@methods;
		return \@methods;  
	}      
}

sub get_methods_by_attribute {
    my ( $self, $obj, $attribute ) = @_;
    my $isa = $self->get_classes($obj);
    my $methods = $methods{$attribute};
    my @return;
    for my $class ( @{ $isa } ) {
	if ( $methods->{$class} ) {
	    for my $key ( keys %{ $methods->{$class} } ) {
		push @return, {
		    'package' => $class,
		    'name'    => $key,
		    'code'    => $methods->{$class}->{$key}
		};
	    }
	}
    }
    return \@return;
}

sub get_accessors {
    my ( $self, $obj ) = @_;
    return $self->get_methods_by_attribute($obj,'Accessor');
}

sub get_mutators {
    my ( $self, $obj ) = @_;
    return $self->get_methods_by_attribute($obj,'Mutator');
}

sub get_abstracts {
    my ( $self, $obj ) = @_;
    return $self->get_methods_by_attribute($obj,'Abstract');
}

sub get_constructors {
    my ( $self, $obj ) = @_;
    return $self->get_methods_by_attribute($obj,'Constructor');
}

sub get_clonables {
    my ( $self, $obj ) = @_;
    return $self->get_methods_by_attribute($obj,'Clonable');
}

sub get_deep_clonables {
    my ( $self, $obj ) = @_;
    return $self->get_methods_by_attribute($obj,'DeepClonable');
}

sub get_destructors {
    my ( $self, $obj ) = @_;
    return $self->get_methods_by_attribute($obj,'Destructor');
}

sub get_privates {
    my ( $self, $obj ) = @_;
    return $self->get_methods_by_attribute($obj,'Private');
}

sub get_statics {
    my ( $self, $obj ) = @_;
    return $self->get_methods_by_attribute($obj,'Static');
}

sub get_serializers {
    my ( $self, $obj ) = @_;
    return $self->get_methods_by_attribute($obj,'Serializer');
}

sub _handler {
    eval {
        my ($package, $symbol, $referent, $attr, $data) = @_;
        return if $symbol eq 'ANON';
        my $name = *$symbol;
        $name =~ s/.*://;
        $methods{$attr} = {} unless $methods{$attr};
        $methods{$attr}->{$package} = {} unless $methods{$attr}->{$package};
        $methods{$attr}->{$package}->{$name} = $referent;
    };
    if ( $@ ) {
        throw 'API' => $@;
    }
}

sub UNIVERSAL::Accessor : ATTR(CODE) {
	my ($package, $symbol, $referent, $attr, $data) = @_;
    _handler(@_);
}

sub UNIVERSAL::Private : ATTR(CODE) {
	my ($package, $symbol, $referent, $attr, $data) = @_;
    no warnings 'redefine';
    return if $symbol eq 'ANON';
    *$symbol = sub {
        my ($calling_package) = caller;
        my $symname = *$symbol;
        $symname =~ s/^\*//;
        $symname =~ s/::[^:]+$//;
        if ( $symname ne $package ) {
            throw 'API' => "Attempt to call Private method from outside package";
        }
        $referent->(@_);
    };
    _handler(@_);
}

sub UNIVERSAL::Protected : ATTR(CODE) {
	my ($package, $symbol, $referent, $attr, $data) = @_;
    no warnings 'redefine';
    return if $symbol eq 'ANON';
    *$symbol = sub {
        my ($calling_package) = caller;
        my $symname = *$symbol;
        my $method = $symname;
        $symname =~ s/^\*//;
        $symname =~ s/::[^:]+$//;
        my @package_names = split /::/, $package;
        my @calling_names = split /::/, $calling_package;
        my $seen_class = $package_names[0] eq $calling_names[0];
        if ( not $seen_class ) {
            throw 'API' => "Attempt to call Protected method $method from outside of top-level namespace";
        }
        $referent->(@_);
    };
    _handler(@_);
}

sub UNIVERSAL::Constructor : ATTR(CODE) {
	my ($package, $symbol, $referent, $attr, $data) = @_;
    _handler(@_);
}

sub UNIVERSAL::Destructor : ATTR(CODE) {
	my ($package, $symbol, $referent, $attr, $data) = @_;
    _handler(@_);
}

sub UNIVERSAL::Static : ATTR(CODE) {
	my ($package, $symbol, $referent, $attr, $data) = @_;
    _handler(@_);
}

sub UNIVERSAL::Mutator : ATTR(CODE) {
	my ($package, $symbol, $referent, $attr, $data) = @_;
    _handler(@_);
}

sub UNIVERSAL::Abstract : ATTR(CODE) {
	my ($package, $symbol, $referent, $attr, $data) = @_;
    _handler(@_);
    return if $symbol eq 'ANON';
    no warnings 'redefine';
	*$symbol = sub { throw 'NotImplemented' => "Abstract method, can't call $symbol" };
}

sub UNIVERSAL::Clonable : ATTR(CODE) {
	my ($package, $symbol, $referent, $attr, $data) = @_;
    _handler(@_);  
}

sub UNIVERSAL::DeepClonable : ATTR(CODE) {
	my ($package, $symbol, $referent, $attr, $data) = @_;
    _handler(@_);  
}

sub UNIVERSAL::Serializer : ATTR(CODE) {
	my ($package, $symbol, $referent, $attr, $data) = @_;
    _handler(@_);  
}

1;


