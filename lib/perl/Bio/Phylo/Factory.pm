package Bio::Phylo::Factory;
use strict;
use warnings;
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw'looks_like_hash looks_like_class';
our $AUTOLOAD;
my %class = (
    'taxa'        => 'Bio::Phylo::Taxa',
    'taxon'       => 'Bio::Phylo::Taxa::Taxon',
    'datum'       => 'Bio::Phylo::Matrices::Datum',
    'matrix'      => 'Bio::Phylo::Matrices::Matrix',
    'characters'  => 'Bio::Phylo::Matrices::Characters',
    'character'   => 'Bio::Phylo::Matrices::Character',
    'datatype'    => 'Bio::Phylo::Matrices::Datatype',
    'forest'      => 'Bio::Phylo::Forest',
    'node'        => 'Bio::Phylo::Forest::Node',
    'tree'        => 'Bio::Phylo::Forest::Tree',
    'logger'      => 'Bio::Phylo::Util::Logger',
    'drawer'      => 'Bio::Phylo::Treedrawer',
    'treedrawer'  => 'Bio::Phylo::Treedrawer',
    'project'     => 'Bio::Phylo::Project',
    'annotation'  => 'Bio::Phylo::Annotation',
    'set'         => 'Bio::Phylo::Set',
    'generator'   => 'Bio::Phylo::Generator',
    'xmlwritable' => 'Bio::Phylo::NeXML::Writable',
    'xmlliteral'  => 'Bio::Phylo::NeXML::Meta::XMLLiteral',
    'meta'        => 'Bio::Phylo::NeXML::Meta',
    'dom'         => 'Bio::Phylo::NeXML::DOM',
    'document'    => 'Bio::Phylo::NeXML::DOM::Document',
    'element'     => 'Bio::Phylo::NeXML::DOM::Element',
    'client'      => 'Bio::Phylo::PhyloWS::Client',
    'server'      => 'Bio::Phylo::PhyloWS::Server',
    'resource'    => 'Bio::Phylo::PhyloWS::Resource',
    'description' => 'Bio::Phylo::PhyloWS::Resource::Description',
);

sub import {
    my $package = shift;
    $package->register_class(@_) if @_;
}

=head1 NAME

Bio::Phylo::Factory - Creator of objects, reduces hardcoded class names in code

=head1 SYNOPSIS

 use Bio::Phylo::Factory;
 my $fac = Bio::Phylo::Factory->new;
 my $node = $fac->create_node( '-name' => 'node1' );

 # probably prints 'Bio::Phylo::Forest::Node'?
 print ref $node;

=head1 DESCRIPTION

The factory module is used to create other objects without having to 'use' 
their classes. This allows for greater flexibility in Bio::Phylo's design,
as class names are no longer hard-coded all over the place.

=head1 METHODS

=head2 CONSTRUCTOR

=over

=item new()

Factory constructor.

 Type    : Constructor
 Title   : new
 Usage   : my $fac = Bio::Phylo::Factory->new;
 Function: Initializes a Bio::Phylo::Factory object.
 Returns : A Bio::Phylo::Factory object.
 Args    : (optional) a hash keyed on short names, with
           class names for values. For example, 
           'node' => 'Bio::Phylo::Forest::Node', which 
           will allow you to subsequently call $fac->create_node,
           which will return a Bio::Phylo::Forest::Node object.
           (Note that this example is enabled by default, so you
           don't need to specify it.)

=cut

sub new {
    my $class = shift;
    if (@_) {
        my %args = looks_like_hash @_;
        while ( my ( $key, $value ) = each %args ) {
            if ( looks_like_class $value ) {
                $class{$key} = $value;
            }
        }
    }
    bless \$class, $class;
}

=back

=head2 FACTORY METHODS

=over

=item create($class, %args)

 Type    : Factory methods
 Title   : create
 Usage   : my $foo = $fac->create('Foo::Class');
 Function: Creates an instance of $class, with constructor arguments %args
 Returns : A Bio::Phylo::* object.
 Args    : $class, a class name (required),
           %args, constructor arguments (optional)

=cut

sub create {
    my $self  = shift;
    my $class = shift;
    if ( looks_like_class $class ) {
        return $class->new(@_);
    }
}

=item register_class()

Registers the argument class name such that subsequently
the factory can instantiates objects of that class. For
example, if you register Foo::Bar, the factory will be 
able to instantiate objects through the create_bar()
method. 

 Type    : Factory methods
 Title   : register_class
 Usage   : $fac->register_class('Foo::Bar');
 Function: Registers a class name for instantiation
 Returns : Invocant
 Args    : $class, a class name (required), or
           'bar' => 'Foo::Bar', such that you
           can subsequently call $fac->create_bar()

=cut

sub register_class {
    my ( $self, @args ) = @_;
    my ( $short, $class );
    if ( @args == 1 ) {
        $class = $args[0];
    }
    else {
        ( $short, $class ) = @args;
    }
    my $path = $class;
    $path =~ s|::|/|g;
    $path .= '.pm';
    if ( not $INC{$path} ) {
        eval { require $path };
        if ($@) {
            throw 'ExtensionError' => "Can't register $class - $@";
        }
    }
    if ( not defined $short ) {
        $short = $class;
        $short =~ s/.*://;
        $short = lc $short;
    }
    $class{$short} = $class;
    return $self;
}

# need empty destructor here so we don't autoload it
sub DESTROY {}

sub AUTOLOAD {
    my $self   = shift;
    my $method = $AUTOLOAD;
    $method =~ s/.*://;
    my $type = $method;
    $type =~ s/^create_//;
    if ( exists $class{$type} ) {
        my $class = $class{$type};
        my $path  = $class;
        $path =~ s|::|/|g;
        $path .= '.pm';
        if ( not $INC{$path} ) {
            
            # here we need to do a string eval use so that the
            # entire symbol table is populated
            require $path;
        }
        return $class{$type}->new(@_);
    }
    elsif ( $method =~ qr/^[A-Z]+$/ ) {
        return;
    }
    else {
        throw 'UnknownMethod' => "No such method: $method";
    }
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

1;
