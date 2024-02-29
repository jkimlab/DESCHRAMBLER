package Bio::Phylo::Util::StackTrace;
use strict;
use warnings;

=head1 NAME

Bio::Phylo::Util::StackTrace - Stack traces for exceptions

=head1 SYNOPSIS

 use Bio::Phylo::Util::StackTrace;
 my $trace = Bio::Phylo::Util::StackTrace->new;
 print $trace->as_string;

=head1 DESCRIPTION

This is a simple stack trace object that is used by
L<Bio::Phylo::Util::Exceptions>. At the moment of its instantiation,
it creates a full list of all frames in the call stack (except those
originating from with the exceptions class). These can subsequently
be stringified by calling as_string().

(If you have no idea what any of this means, don't worry: this class
is mostly for internal usage. You can probably ignore this safely.)

=head1 METHODS

=head2 CONSTRUCTOR

=over

=item new()

Stack trace object constructor.

 Type    : Constructor
 Title   : new
 Usage   : my $trace = Bio::Phylo::Util::StackTrace->new
 Function: Instantiates a Bio::Phylo::Util::StackTrace
           object.
 Returns : A Bio::Phylo::Util::StackTrace.
 Args    : None

=cut

sub new {
    my $class = shift;
    my $self  = [];
    my $i     = 0;
    my $j     = 0;

    package DB;    # to get @_ stack from previous frames, see perldoc -f caller
    while ( my @frame = caller($i) ) {
        my $package = $frame[0];
        if ( not Bio::Phylo::Util::StackTrace::_skip_me($package) ) {
            my @args = @DB::args;
            $self->[ $j++ ] = [ @frame, @args ];
        }
        $i++;
    }

    package Bio::Phylo::Util::StackTrace;
    shift @$self;    # to remove "throw" frame
    return bless $self, $class;
}

sub _skip_me {
    my $class = shift;
    my $skip  = 0;
    if ( $class->isa('Bio::Phylo::Util::Exceptions') ) {
        $skip++;
    }
    if ( $class->isa('Bio::Phylo::Util::ExceptionFactory') ) {
        $skip++;
    }
    return $skip;
}

=back

=head2 SERIALIZERS

=over

=item as_string()

Creates a string representation of the stack trace

 Type    : Serializer
 Title   : as_string
 Usage   : print $trace->as_string
 Function: Creates a string representation of the stack trace
 Returns : String
 Args    : None

=cut

=begin comment

fields in frame:
 [
 0   'main',
+1   '/Users/rvosa/Desktop/exceptions.pl',
+2   102,
+3   'Object::this_dies',
 4   1,
 5   undef,
 6   undef,
 7   undef,
 8   2,
 9   'UUUUUUUUUUUU',
+10  bless( {}, 'Object' ),
+11  'very',
+12  'violently'
 ],

=end comment

=cut

sub as_string {
    my $self   = shift;
    my $string = "";
    for my $frame (@$self) {
        my $method = $frame->[3];
        my @args;
        for my $i ( 10 .. $#{$frame} ) {
            push @args, $frame->[$i];
        }
        my $file = $frame->[1];
        my $line = $frame->[2];
        $string .=
            $method . "("
          . join( ', ', map { "'$_'" } grep { $_ } @args )
          . ") called at $file line $line\n";
    }
    return $string;
}

=back

=cut

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::Util::Exceptions>

The stack trace object is used internally by the exception classes.

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
