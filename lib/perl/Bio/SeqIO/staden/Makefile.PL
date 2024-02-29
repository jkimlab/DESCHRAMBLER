use ExtUtils::MakeMaker;
use Config;
use Cwd qw(realpath);
use strict;

my $default_staden_location = '/usr/local/staden/io_lib';

my %options = %{       
    {
        'NAME'     => 'Bio::SeqIO::staden::read',
        'VERSION'  => '1.007000'
    }
};

my ($staden_libs_opts, $staden_include_opts );

#
# see if io_lib-config from staden is on the path.
#  

print "Let's see if io_lib-config is on your path\n";
system("io_lib-config --version");

if ( $? ) {   # no io_lib-config on path
  print "Nope, couldn't find io_lib-config on the path\n";

  # try the environment 

  my ($iolibinc, $ioliblib) = @ENV{qw(IOLIB_INC IOLIB_LIB)};

  # try the command line 
  unless ($ioliblib) {
    ($ioliblib) = grep { defined } map { m/^IOLIB_LIB\=(\S+)/o ? $1 : undef } @ARGV;
  }
  unless ($iolibinc) {
    ($iolibinc) = grep { defined } map { m/^IOLIB_INC\=(\S+)/o ? $1 : undef } @ARGV;
  }

  # guess wildly!
  unless( $ioliblib ) {
    my @d;
    for my $test (split(/\s+/, $main::Config{libpth} ) ) { 
        next unless $test;
        eval { local $SIG{__WARN__} = sub { }; @d = ExtUtils::Liblist->ext("-L$test -lread") };
        my ($dir) = split /\s+/, $d[2];
        if ($dir eq "-L$test") {
            $ioliblib = $test;
            warn "Found Staden io_lib \"libread\" in $ioliblib ...\n";
            unless ($iolibinc) {
                $iolibinc = $test;
                $iolibinc =~ s/lib$/include/;
                my $iolibinc_io_lib = File::Spec->catdir($iolibinc, 'io_lib');
                unless (-e File::Spec->catfile($iolibinc_io_lib, 'Read.h')) { 
                    undef $iolibinc;
                } else {
                    warn "Found the Read.h found in $iolibinc but lets see what io_lib-config might think...\n";
                }
            }
            last;
        }
    }
  }

  # try asking for help.

  my $stadenloc;

  unless ( $ioliblib ) {
      $stadenloc = ExtUtils::MakeMaker::prompt("Please tell us where your Staden io_lib resides: ", $default_staden_location );
      $stadenloc = realpath( $stadenloc );
  }
 #
 # use the default if nothing was entered
 #

  $stadenloc = $stadenloc ? $stadenloc 
             : $ioliblib  ? realpath( File::Spec->catdir($ioliblib, '..' ) )
             : $default_staden_location;

  if ( ! -d $stadenloc ) {
      warn "WARNING: directory $stadenloc not found";
  }

  if ( -x File::Spec->catfile( $stadenloc, 'bin', 'io_lib-config' ) ) {
     ($staden_libs_opts, $staden_include_opts ) 
              = get_from_ioconfig( File::Spec->catfile( $stadenloc, 'bin', 'io_lib-config') );
  }
  else{ 
      # 
      # no io_lib-config, try some defaults.
      #
    
    $ioliblib ||= File::Spec->catdir( $stadenloc,'lib' ); 
    unless ( $iolibinc ) {
      $iolibinc = $ioliblib;
      $iolibinc =~ s/lib$/include/;
    }

    $staden_libs_opts = "-L$ioliblib -lz -lm -lread";
    $staden_include_opts = "-I$iolibinc";
  }
}
else { 
  print "Yes, found io_lib-config, using it to set flags for read.c\n";
   ($staden_libs_opts, $staden_include_opts ) 
          = get_from_ioconfig('io_lib-config');
}

$options{INC} = $staden_include_opts;
$options{LIBS} = $staden_libs_opts;

WriteMakefile(%options);

# -- done --

sub get_from_ioconfig {
    my ( $binary ) = @_;

    my $libs = `$binary --libs`;
    my $incs = `$binary --cflags`;

    chomp $libs;
    chomp $incs;

    return( $libs, $incs );
}

# Remove the Makefile dependency. Causes problems on a few systems.
# sub MY::makefile { '' }
