package Bio::Phylo::Util::Logger;
use strict;
use warnings;
use base 'Exporter';
use Term::ANSIColor;
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw'/looks_like/';

our ( %VERBOSITY, $PREFIX, %STYLE );
our $STYLE       = 'detailed';
our $COLORED     = 1; # new default: we use colors
our $TRACEBACK   = 0;
our @EXPORT_OK   = qw(DEBUG INFO WARN ERROR FATAL VERBOSE);
our %EXPORT_TAGS = ( 'simple' => [@EXPORT_OK], 'levels' => [@EXPORT_OK] );
our %COLORS      = (
	'DEBUG' => 'blue', 
	'INFO'  => 'green',
	'WARN'  => 'yellow',
	'ERROR' => 'bold red',
	'FATAL' => 'red',
);

BEGIN {
    
    # compute the path to the root of Bio::Phylo,
    # use that as the default prefix
    my $package = __PACKAGE__;
    my $file    = __FILE__;
    $package    =~ s/::/\//g;
    $package   .= '.pm';
    $file       =~ s/\Q$package\E$//;
    $PREFIX     = $file;
    
    # set verbosity to 2, i.e. warn
    $VERBOSITY{'*'} = $ENV{'BIO_PHYLO_VERBOSITY'} || 2;
    
    # define verbosity styles
    %STYLE = (
    	'simple'   => '${level}: $message',
    	'detailed' => '$level $sub [$file $line] - $message',    
    );
}

{
    my %levels = ( FATAL => 0, ERROR => 1, WARN => 2, INFO => 3, DEBUG => 4 );
    my @listeners = ( sub {
    	my ( $string, $level ) = @_;
    	if ( $COLORED and -t STDERR ) {
    		print STDERR colored( $string, $COLORS{$level} ); 
    	}
    	else {
    		print STDERR $string;
    	}
    } ); # default

    # dummy constructor that dispatches to VERBOSE(),
    # then returns the package name
    sub new {
        my $class = shift;
        $class->VERBOSE(@_) if @_;
        return $class;
    }

    # set additional listeners
    sub set_listeners {
        my ( $class, @args ) = @_;
        for my $arg (@args) {
            if ( looks_like_instance $arg, 'CODE' ) {
                push @listeners, $arg;
            }
            else {
                throw 'BadArgs' => "$arg not a CODE reference";
            }
        }
        return $class;
    }
    
    # this is never called directly. rather, messages are dispatched here
    # by the DEBUG() ... FATAL() subs below
    sub LOG ($$) {
        my ( $message, $level ) = @_;
        
        # probe the call stack
        my ( $pack2, $file2, $line2, $sub  ) = caller( $TRACEBACK + 2 );
        my ( $pack1, $file,  $line,  $sub1 ) = caller( $TRACEBACK + 1 );
        
        # cascade verbosity from global to local
        my $verbosity = $VERBOSITY{'*'}; # global
        $verbosity = $VERBOSITY{$pack1} if exists $VERBOSITY{$pack1}; # package
        $verbosity = $VERBOSITY{$sub}  if $sub and exists $VERBOSITY{$sub}; # sub
        
        # verbosity is higher than the current caller, proceed
        if ( $verbosity >= $levels{$level} ) {            

            # strip the prefix from the calling file's path
            if ( index($file, $PREFIX) == 0 ) {
                $file =~ s/^\Q$PREFIX\E//;
            }
            
            # select one of the templates
            my $string;
            my $s = $STYLE{$STYLE};
            $string = eval "qq[$s\n]";
            
            # dispatch to the listeners
            $_->( $string, $level, $sub, $file, $line, $message ) for @listeners;
        }       
    }
    
    # these subs both return their verbosity constants and, if
    # provided with a message, dispatch the message to LOG()
    sub FATAL (;$) { LOG $_[0], 'FATAL' if $_[0]; $levels{'FATAL'} } 
    sub ERROR (;$) { LOG $_[0], 'ERROR' if $_[0]; $levels{'ERROR'} }
    sub WARN  (;$) { LOG $_[0], 'WARN'  if $_[0]; $levels{'WARN'}  }
    sub INFO  (;$) { LOG $_[0], 'INFO'  if $_[0]; $levels{'INFO'}  }
    sub DEBUG (;$) { LOG $_[0], 'DEBUG' if $_[0]; $levels{'DEBUG'} } 

    sub PREFIX {
        my ( $class, $prefix ) = @_;
        $PREFIX = $prefix if $prefix;
        return $PREFIX;
    }

    sub VERBOSE {
        shift if ref $_[0] or $_[0] eq __PACKAGE__;
        if (@_) {
            my %opt = looks_like_hash @_;
            my $level = $opt{'-level'};
            
            # verbosity is specified
            if ( defined $level ) {

                # check validity
                if ( $level > 4 xor $level < 0 ) {
                    throw 'OutOfBounds' => "'-level' can be between 0 and 4, not $level";
                }
                
                # verbosity is specified for one or more packages
                if ( my $class = $opt{'-class'} ) {
                    if ( ref $class eq 'ARRAY' ) {
                        for my $c ( @{ $class } ) {
                            $VERBOSITY{$c} = $level;
                            INFO "Changed verbosity for class $c to $level";
                        }
                    }
                    else {
                        $VERBOSITY{$class} = $level;
                        INFO "Changed verbosity for class $class to $level";
                    }
                }
                
                # verbosity is specified for one or more methods
                elsif ( my $method = $opt{'-method'} ) {
                    if ( ref $method eq 'ARRAY' ) {
                        for my $m ( @{ $method } ) {
                            $VERBOSITY{$m} = $level;
                            INFO "Changed verbosity for method $m to $level";
                        }
                    }
                    else {
                        $VERBOSITY{$method} = $level;
                        INFO "Changed verbosity for method $method to $level";
                    }
                }
                
                # verbosity is set globally
                else {
                    $VERBOSITY{'*'} = $level;
                    INFO "Changed global verbosity to $VERBOSITY{'*'}";
                }
            }
            
            # log to a file
            if ( $opt{'-file'} ) {
                open my $fh, '>>', $opt{'-file'} or throw 'FileError' => $!;
                __PACKAGE__->set_listeners(sub { print $fh shift });
            }
            
            # log to a handle
            if ( $opt{'-handle'} ) {
                my $fh = $opt{'-handle'};
                __PACKAGE__->set_listeners(sub { print $fh shift });
            }
            
            # log to listeners
            if ( $opt{'-listeners'} ) {
                __PACKAGE__->set_listeners(@{$opt{'-listeners'}});
            }
            
            # update the prefix
            if ( $opt{'-prefix'} ) {
                __PACKAGE__->PREFIX($opt{'-prefix'});
            }
            
            # set logstyle
            if ( $opt{'-style'} ) {
            	my $s = lc $opt{'-style'};
            	if ( exists $STYLE{$s} ) {
            		$STYLE = $s;
            	}
            } 
            
            # turn colors on/off. default is on.
            $COLORED = !!$opt{'-colors'} if defined $opt{'-colors'};
        }
        return $VERBOSITY{'*'};
    }
    
    # Change the terminal to a predefined color. For example to make sure that
    # an entire exception (or part of it) is marked up as FATAL, or so that the
    # output from an external command is marked up as DEBUG.
    sub start_color {
    	my ( $self, $level, $handle ) = @_;
    	$handle = \*STDERR if not $handle;    	
    	if ( $COLORED and -t $handle ) {
    		print $handle color $COLORS{$level}; 
    	}
    	return $COLORS{$level};
    }
    
    sub stop_color {
    	my ( $self, $handle ) = @_;
    	$handle = \*STDERR if not $handle;    	
    	if ( $COLORED and -t $handle ) {
    		print $handle color 'reset'; 
    	} 
    	return $self;   
    }    
    
    # aliases for singleton methods
    sub fatal {
		my $self = shift;
		$TRACEBACK++;
		FATAL shift;
		$TRACEBACK--;
	}
    sub error {
		my $self = shift;
		$TRACEBACK++;
		ERROR shift;
		$TRACEBACK--;
	}
	sub warn {
		my $self = shift;
		$TRACEBACK++;
		WARN shift;
		$TRACEBACK--;
	}
	sub info {
		my $self = shift;
		$TRACEBACK++;
		INFO shift;
		$TRACEBACK--;
	}
	sub debug {
		my $self = shift;
		$TRACEBACK++;
		DEBUG shift;
		$TRACEBACK--;
	}
    
    # empty destructor so we don't go up inheritance tree at the end
    sub DESTROY {}  
}
1;

=head1 NAME

Bio::Phylo::Util::Logger - Logger of internal messages of several severity
levels 

=head1 SYNOPSIS

 use strict;
 use Bio::Phylo::Util::Logger ':levels'; # import level constants
 use Bio::Phylo::IO 'parse';
 use Bio::Phylo::Factory; 
 
 # Set the verbosity level of the tree class.
 # "DEBUG" is the most verbose level. All log messages
 # emanating from the tree class will be 
 # transmitted. For this to work the level constants
 # have to have been imported!
 use Bio::Phylo::Forest::Tree 'verbose' => DEBUG; # note: DEBUG is not quoted!
 
 # Create a file handle for logger to write to.
 # This is not necessary, by default the logger
 # writes to STDERR, but sometimes you will want
 # to write to a file, as per this example.
 open my $fh, '>', 'parsing.log' or die $!;
 
 # Create a logger object.
 my $fac = Bio::Phylo::Factory->new;
 my $logger = $fac->create_logger;
 
 # Set the verbosity level of the set_name
 # method in the base class. Messages coming
 # from this method will be transmitted.
 $logger->VERBOSE( 
     '-level'  => DEBUG, # note, not quoted, this is a constant!
     '-method' => 'Bio::Phylo::set_name', # quoted, otherwise bareword error!
 );
 
 # 'Listeners' are subroutine references that
 # are executed when a message is transmitted.
 # The first argument passed to these subroutines
 # is the log message. This particular listener
 # will write the message to the 'parsing.log'
 # file, if the $fh file handle is still open.
 $logger->set_listeners(
     sub {
         my ($msg) = @_;
         if ( $fh->opened ) {
             print $fh $msg;
         }
     }
 );

 # Now parse a tree, and see what is logged.
 my $tree = parse( 
     '-format' => 'newick', 
     '-string' => do { local $/; <DATA> },
 )->first;

 # Cleanly close the log handle.
 close $fh;
 
 __DATA__
 ((((A,B),C),D),E);

The example above will write something like the following to the log file:

 INFO Bio::Phylo::Forest::Tree::new [Bio/Phylo/Forest/Tree.pm, 99] - constructor called for 'Bio::Phylo::Forest::Tree'
 INFO Bio::Phylo::set_name [Bio/Phylo.pm, 281] - setting name 'A'
 INFO Bio::Phylo::set_name [Bio/Phylo.pm, 281] - setting name 'B'
 INFO Bio::Phylo::set_name [Bio/Phylo.pm, 281] - setting name 'C'
 INFO Bio::Phylo::set_name [Bio/Phylo.pm, 281] - setting name 'D'
 INFO Bio::Phylo::set_name [Bio/Phylo.pm, 281] - setting name 'E'

=head1 DESCRIPTION

This class defines a logger, a utility object for logging messages.
The other objects in Bio::Phylo use this logger to give detailed feedback
about what they are doing at per-class, per-method, user-configurable log levels
(DEBUG, INFO, WARN, ERROR and FATAL). These log levels are constants that are
optionally exported by this class by passing the ':levels' argument to your
'use' statement, like so:

 use Bio::Phylo::Util::Logger ':levels';

If for some reason you don't want this behaviour (i.e. because there is
something else by these same names in your namespace) you must use the fully
qualified names for these levels, i.e. Bio::Phylo::Util::Logger::DEBUG and
so on.

The least verbose is level FATAL, in which case only 'fatal' messages are shown. 
The most verbose level, DEBUG, shows debugging messages, including from internal 
methods (i.e. ones that start with underscores, and special 'ALLCAPS' perl 
methods like DESTROY or TIEARRAY). For example, to monitor what the root class 
is doing, you would say:

 $logger->( -class => 'Bio::Phylo', -level => DEBUG )

To define global verbosity you can omit the -class argument. To set verbosity
at a more granular level, you can use the -method argument, which takes a 
fully qualified method name such as 'Bio::Phylo::set_name', such that messages
originating from within that method's body get a different verbosity level.

=head1 METHODS

=head2 CONSTRUCTOR

=over

=item new()

Constructor for Logger.

 Type    : Constructor
 Title   : new
 Usage   : my $logger = Bio::Phylo::Util::Logger->new;
 Function: Instantiates a logger
 Returns : a Bio::Phylo::Util::Logger object
 Args    : -level  => Bio::Phylo::Util::Logger::INFO (DEBUG/INFO/WARN/ERROR/FATAL)
           -class  => a package (or array ref) for which to set verbosity (optional)
           -method => a sub name (or array ref) for which to set verbosity (optional)
           -file   => a file to which to append logging messages
           -listeners => array ref of subs that handle logging messages
           -prefix    => a path fragment to strip from the paths in logging messages
           

=back

=head2 VERBOSITY LEVELS

=over

=item FATAL

Rarely happens, usually an exception is thrown instead.

=item ERROR

If this happens, something is seriously wrong that needs to be addressed.

=item WARN

If this happens, something is seriously wrong that needs to be addressed.

=item INFO

If something weird is happening, turn up verbosity to this level as it might
explain some of the assumptions the code is making.

=item DEBUG

This is very verbose, probably only useful if you write core Bio::Phylo code.

=back

=head2 LOGGING METHODS

=over

=item debug()

Prints argument debugging message, depending on verbosity.

 Type    : logging method
 Title   : debug
 Usage   : $logger->debug( "debugging message" );
 Function: prints debugging message, depending on verbosity
 Returns : invocant
 Args    : logging message

=item info()

Prints argument informational message, depending on verbosity.

 Type    : logging method
 Title   : info
 Usage   : $logger->info( "info message" );
 Function: prints info message, depending on verbosity
 Returns : invocant
 Args    : logging message

=item warn()

Prints argument warning message, depending on verbosity.

 Type    : logging method
 Title   : warn
 Usage   : $logger->warn( "warning message" );
 Function: prints warning message, depending on verbosity
 Returns : invocant
 Args    : logging message

=item error()

Prints argument error message, depending on verbosity.

 Type    : logging method
 Title   : error
 Usage   : $logger->error( "error message" );
 Function: prints error message, depending on verbosity
 Returns : invocant
 Args    : logging message

=item fatal()

Prints argument fatal message, depending on verbosity.

 Type    : logging method
 Title   : fatal
 Usage   : $logger->fatal( "fatal message" );
 Function: prints fatal message, depending on verbosity
 Returns : invocant
 Args    : logging message

=item set_listeners()

Adds listeners to send log messages to.

 Type    : Mutator
 Title   : set_listeners()
 Usage   : $logger->set_listeners( sub { warn shift } )
 Function: Sets additional listeners to log to (e.g. a file)
 Returns : invocant
 Args    : One or more code references
 Comments: On execution of the listeners, the @_ arguments are:
           $log_string, # the formatted log string
           $level,      # log level, i.e DEBUG, INFO, WARN, ERROR or FATAL
           $subroutine, # the calling subroutine
           $filename,   # filename where log method was called
           $line,       # line where log method was called
           $msg         # the unformatted message

=item start_color()

Changes color of output stream to that of specified logging level. This so that for 
example all errors are automatically marked up as 'FATAL', or all output generated
by an external program is marked up as 'DEBUG'

 Type    : Mutator
 Title   : start_color()
 Usage   : $logger->start_color( 'DEBUG', \*STDOUT )
 Function: Changes color of output stream
 Returns : color name
 Args    : Log level whose color to use, 
           (optional) which stream to change, default is STDERR

=item stop_color()

Resets the color initiated by start_color()

 Type    : Mutator
 Title   : stop_color()
 Usage   : $logger->stop_color( \*STDOUT )
 Function: Changes color of output stream
 Returns : color name
 Args    : (Optional) which stream to reset, default is STDERR


=item PREFIX()

Getter and setter of path prefix to strip from source file paths in messages.
By default, messages will have a field such as C<[$PREFIX/Bio/Phylo.pm, 280]>,
which indicates the message was sent from line 280 in file Bio/Phylo.pm inside
path $PREFIX. This is done so that your log won't be cluttered with 
unnecessarily long paths. To find out what C<$PREFIX> is set to, call the 
PREFIX() method on the logger, and to change it provide a path argument 
relative to which the paths to source files will be constructed.

 Type    : Mutator/Accessor
 Title   : PREFIX()
 Usage   : $logger->PREFIX( '/path/to/bio/phylo' )
 Function: Sets/gets $PREFIX
 Returns : Verbose level
 Args    : Optional: a path
 Comments:

=item VERBOSE()

Setter for the verbose level. This comes in five levels: 

    FATAL = only fatal messages (though, when something fatal happens, you'll most 
    likely get an exception object), 
    
    ERROR = errors (hopefully recoverable), 
    
    WARN = warnings (recoverable), 
    
    INFO = info (useful diagnostics), 
    
    DEBUG = debug (almost every method call)

Without additional arguments, i.e. by just calling VERBOSE( -level => $level ),
you set the global verbosity level. By default this is 2. By increasing this
level, the number of messages quickly becomes too great to make sense out of.
To focus on a particular class, you can add the -class => 'Some::Class' 
(where 'Some::Class' stands for any of the class names in the Bio::Phylo 
release) argument, which means that messages originating from that class will 
have a different (presumably higher) verbosity level than the global level. 
By adding the -method => 'Fully::Qualified::method_name' (say, 
'Bio::Phylo::set_name'), you can change the verbosity of a specific method. When
evaluating whether or not to transmit a message, the method-specific verbosity
level takes precedence over the class-specific level, which takes precedence
over the global level.

 Type    : Mutator
 Title   : VERBOSE()
 Usage   : $logger->VERBOSE( -level => $level )
 Function: Sets/gets verbose level
 Returns : Verbose level
 Args    : -level   => 4 # or lower
 
           # optional, or any other class 
           -class   => 'Bio::Phylo' 
           
           # optional, fully qualified method name
           -method' => 'Bio::Phylo::set_name' 

=back

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

Also see the manual: L<Bio::Phylo::Manual> and L<http://rutgervos.blogspot.com>.

=head1 CITATION

If you use Bio::Phylo in published research, please cite it:

B<Rutger A Vos>, B<Jason Caravas>, B<Klaas Hartmann>, B<Mark A Jensen>
and B<Chase Miller>, 2011. Bio::Phylo - phyloinformatic analysis using Perl.
I<BMC Bioinformatics> B<12>:63.
L<http://dx.doi.org/10.1186/1471-2105-12-63>

=cut