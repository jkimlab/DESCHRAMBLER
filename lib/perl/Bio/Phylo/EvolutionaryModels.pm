package Bio::Phylo::EvolutionaryModels;
use strict;
use warnings;
use base 'Exporter';
use Bio::Phylo::Forest::Tree;
use Bio::Phylo::Forest;
use Math::CDF qw'qnorm qbeta';
use List::Util qw'min max';
use POSIX qw'ceil floor';
use Config;    #Use to check whether multi-threading is available

BEGIN {

    use Bio::Phylo;
    our @EXPORT_OK =
      qw(&sample &constant_rate_birth &constant_rate_birth_death &clade_shifts);
}

=head1 NAME

Bio::Phylo::EvolutionaryModels - Evolutionary models for phylogenetic trees and methods to sample these
Klaas Hartmann, September 2007

=head1 SYNOPSIS

 #For convenience we import the sample routine (so we can write sample(...) instead of
 #Bio::Phylo::EvolutionaryModels::sample(...).
 use Bio::Phylo::EvolutionaryModels qw (sample);
 
 #Example#A######################################################################
 #Simulate a single tree with ten species from the constant rate birth model with parameter 0.5
 my $tree = Bio::Phylo::EvolutionaryModels::constant_rate_birth(birth_rate => .5, tree_size => 10);
 
 #Example#B######################################################################
 #Sample 5 trees with ten species from the constant rate birth model using the b algorithm
 my ($sample,$stats) = sample(sample_size =>5,
                              tree_size => 10,
                              algorithm => 'b',
                              algorithm_options => {rate => 1},
                              model => \&Bio::Phylo::EvolutionaryModels::constant_rate_birth,
                              model_options => {birth_rate=>.5});

                              
 #Print a newick string for the 4th sampled tree                              
 print $sample->[3]->to_newick."\n";            
 
 #Example#C######################################################################
 #Sample 5 trees with ten species from the constant rate birth and death model using 
 #the bd algorithm and two threads (useful for dual core processors)
 #NB: we must specify an nstar here, an appropriate choice will depend on the birth_rate
 #    and death_rate we are giving the model    
               
 my ($sample,$stats) = sample(sample_size =>5,
                              tree_size => 10,
                              threads => 2,
                              algorithm => 'bd',
                              algorithm_options => {rate => 1, nstar => 30},
                              model => \&Bio::Phylo::EvolutionaryModels::constant_rate_birth_death,
                              model_options => {birth_rate=>1,death_rate=>.8});
                               
 #Example#D######################################################################
 #Sample 5 trees with ten species from the constant rate birth and death model using 
 #incomplete taxon sampling
 #
 #sampling_probability is set so that the true tree has 10 species with 50% probability,
 #11 species with 30% probability and 12 species with 20% probability
 #
 #NB: we must specify an mstar here this will depend on the model parameters and the 
 #    incomplete taxon sampling parameters

 my $algorithm_options = {rate => 1, 
                          nstar => 30, 
                          mstar => 12,     
                          sampling_probability => [.5, .3, .2]};
                   
 my ($sample,$stats) = sample(sample_size =>5,
                              tree_size => 10,
                              algorithm => 'incomplete_sampling_bd',
                              algorithm_options => $algorithm_options,
                              model => \&Bio::Phylo::EvolutionaryModels::constant_rate_birth_death,
                              model_options => {birth_rate=>1,death_rate=>.8});

 #Example#E######################################################################
 #Sample 5 trees with ten species from a Yule model using the memoryless_b algorithm
 
 #First we define the random function for the shortest pendant edge for a Yule model
 my $random_pendant_function = sub { 
     %options = @_;
     return -log(rand)/$options{birth_rate}/$options{tree_size};
 };
 
 #Then we produce our sample
 my ($sample,$stats) = sample(sample_size =>5,
                              tree_size => 10,
                              algorithm => 'memoryless_b',
                              algorithm_options => {pendant_dist => $random_pendant_function},
                              model => \&Bio::Phylo::EvolutionaryModels::constant_rate_birth,
                              model_options => {birth_rate=>1});

 #Example#F#######################################################################
 #Sample 5 trees with ten species from a constant birth death rate model using the 
 #constant_rate_bd algorithm
 my ($sample) = sample(sample_size => 5,
                       tree_size => 10,
                       algorithm => 'constant_rate_bd',
                       model_options => {birth_rate=>1,death_rate=>.8});

=head1 DESCRIPTION

This package contains evolutionary models for phylogenetic trees and 
algorithms for sampling from these models. It is a non-OO module that 
optionally exports the 'sample', 'constant_rate_birth' and 
'constant_rate_birth_death' subroutines into the caller's namespace, 
using the C<< use Bio::Phylo::EvolutionaryModels qw(sample constant_rate_birth constant_rate_birth_death); >> 
directive. Alternatively, you can call the subroutines as class methods, 
as in the synopsis.  

The initial set of algorithms available in this package corresponds to those in:

Sampling trees from evolutionary models
Klaas Hartmann, Dennis Wong, Tanja Gernhard
Systematic Biology, in press

Some comments and code refers back to this paper. 
Further algorithms and evolutionary are encouraged
and welcome. 

To make this code as straightforward as possible to read some of the 
algorithms have been implemented in a less than optimal manner. The code
also follows the structure of an earlier version of the manuscript so 
there is some redundancy (eg. the birth algorithm is just a specific 
instance of the birth_death algorithm)

=head1 SAMPLING 

All sampling algorithms should be accessed through the generic sample 
interface.

=head2 Generic sampling interface: sample()

 Type    : Interface
 Title   : sample
 Usage   : see SYNOPSIS
 Function: Samples phylogenetic trees from an evolutionary model
 Returns : A sample of phylogenetic trees and statistics from the
           sampling algorithm
 Args    : Sampling parameters in a hash

This method acts as a gateway to the various sampling algorithms. The 
argument is a single hash containing the options for the sampling run.


Sampling parameters (* denotes optional parameters):
    
 sample_size    The number of trees to return (more trees may be returned)  
 tree_size      The size that returned trees should be
 model          The evolutionary model (should be a function reference)
 model_options  A hash pointer for model options (see individual models)
 algorithm      The algorithm to use (omit the preceding sample_)
 algorithm_options A hash pointer for options for the algorithm (see individual algorithms for details)
 threads*       The number of threads to use (default is 1)
 output_format* Set to newick for newick trees (default is Bio::Phylo::Forest::Tree)
 remove_extinct Set to true to remove extinct species



Available algorithms (algorithm names in the paper are given in brackets):

 b                       For all pure birth models (simplified GSA)
 bd                      For all birth and death models (GSA)
 incomplete_sampling_bd  As above, with incomplete taxon sampling (extended GSA)
 memoryless_b            For memoryless pure birth models (PBMSA)
 constant_rate_bd        For birth and death models with constant rates (BDSA)


Model

If you create your own model it must accept an options hash as its input. 
This options hash can contain any parameters you desire. Your model should
simulate a tree until it becomes extinct or the size/age limit as specified
in the options has been reached. Respectively these options are tree_size 
and tree_age.


Multi-threading

Multi-thread support is very simplistic. The number of threads you specify 
are created and each is assigned the task of finding sample_size/threads 
samples. I had problems with using Bio::Phylo::Forest::Tree in a multi-
threaded setting. Hence the sampled trees are returned as newick strings to
the main routine where (if required) Tree objects are recreated from the 
strings. For most applications this overhead seems negligible in contrast
to the sampling times.


From a code perspective this function (sample):

 Checks input arguments
 Handles multi-threading
 Calls the individual algorithms to perform sampling
 Reformats data

=cut

my @threads;

sub sample {
    my %options         = @_;
    my %methods_require = (
        b  => ['rate'],
        bd => [ 'rate', 'nstar' ],
        incomplete_sampling_bd =>
          [ 'rate', 'nstar', 'mstar', 'sampling_probability' ],
        memoryless_b     => ['pendant_dist'],
        constant_rate_bd => [],
    );

    #Default is to sample a single tree
    $options{sample_size} = 1 unless defined $options{sample_size};

    #Default is to use a single thread
    $options{threads} = 1 unless defined $options{threads};

    #Check that multiple threads are actually supported
    if ( $options{threads} > 1 && !$Config{useithreads} ) {
        Bio::Phylo::Util::Exceptions::BadArgs->throw( 'error' =>
              "your perl installation does not support multiple threads" );
    }

    #Check an algorithm was specified
    unless ( defined $options{algorithm} ) {
        Bio::Phylo::Util::Exceptions::BadArgs->throw(
            'error' => "an algorithm type must be specified" );
    }

    #Check the algorithm type is valid
    unless ( defined $methods_require{ $options{algorithm} } ) {
        Bio::Phylo::Util::Exceptions::BadFormat->throw(
            'error' => "'$options{algorithm}' is not a valid algorithm" );
    }

    #Check the algorithm options
    foreach ( @{ $methods_require{ $options{algorithm} } } ) {
        unless ( defined $options{algorithm_options}->{$_} ) {
            Bio::Phylo::Util::Exceptions::BadArgs->throw( 'error' =>
"'$_' must be specified for the '$options{algorithm}' algorithm"
            );
        }
    }

#If we are doing incomplete taxon sampling the sampling probability must be specified
    if (   defined $options{incomplete_sampling}
        && $options{incomplete_sampling}
        && !( defined $options{algorithm_options}->{sampling_probability} ) )
    {
        Bio::Phylo::Util::Exceptions::BadArgs->throw( 'error' =>
"'sampling_probability' must be specified for post hoc incomplete sampling to be applied"
        );
    }

    #Check that a model has been specified
    unless ( defined $options{model}
        || $options{algorithm} eq 'constant_rate_bd' )
    {
        Bio::Phylo::Util::Exceptions::BadArgs->throw(
            'error' => "a model must be specified" );
    }

    #Get a function pointer for the algorithm
    my $algorithm = 'sample_' . $options{algorithm};
    $algorithm = \&$algorithm;
    my @output;

    #Run the algorithm, different method for multiple threads
    if ( $options{threads} > 1 ) {
        require threads;
        require threads::shared;
        @output = ( [], [] );
        $SIG{'KILL'} = sub {
            foreach (@threads) { $_->kill('KILL')->detach(); }
            threads->exit();
        };

        #Start the threads
        for ( ( 1 .. $options{threads} ) ) {
            @_ = ();

            #Note the list context of the return argument here determines
            #the data type returned from the thread.
            ( $threads[ $_ - 1 ] ) = threads->new( \&_sample_newick, %options,
                sample_size => ceil( $options{sample_size} / $options{threads} )
            );
        }

        #Wait for them to finish and combine the data
        for ( ( 1 .. $options{threads} ) ) {
            until ( $threads[ $_ - 1 ]->is_joinable() ) { sleep(0.1); }
            my @thread_data = $threads[ $_ - 1 ]->join;
            for ( my $index = 0 ; $index < scalar @thread_data ; $index++ ) {
                $output[$index] = [] if scalar @output < $index;
                $output[$index] =
                  [ @{ $output[$index] }, @{ $thread_data[$index] } ];
            }
        }

        #Turn newick strings back into tree objects
        unless ( defined $options{output_format}
            && $options{output_format} eq 'newick' )
        {

            #Convert to newick trees
            for ( my $index = 0 ; $index < scalar @{ $output[0] } ; $index++ ) {
                $output[0]->[$index] = Bio::Phylo::IO->parse(
                    -format => 'newick',
                    -string => $output[0]->[$index]
                )->first;
            }
        }
    }
    else {

        #Get the samples
        @output = &$algorithm(%options);

        #Turn into newick trees if requested
        if ( defined $options{output_format}
            && $options{output_format} eq 'newick' )
        {

            #Convert to newick trees
            for ( my $index = 0 ; $index < scalar @{ $output[0] } ; $index++ ) {
                $output[0]->[$index] =
                  $output[0]->[$index]->to_newick( '-nodelabels' => 1 );
            }
        }
        elsif ( defined $options{output_format}
            && $options{output_format} eq 'forest' )
        {

            # save as a forest
            my $forest = Bio::Phylo::Forest->new;
            for ( my $index = 0 ; $index < scalar @{ $output[0] } ; $index++ ) {
                $forest->insert( $output[0]->[$index] );
            }
            $output[0] = $forest;
        }
    }
    return @output;
}

=begin comment

 Type    : Internal method
 Title   : _sample_newick
 Usage   : ($thread) = threads->new(\&_sample_newick, %options);
           @thread_output = $thread->join; 
 Function: Wrapper for sampling routines used for multi-threading
 Returns : Output from sampling algorithms with trees replaced by newick strings
 Args    : %options to pass to sampling algorithm

=end comment

=cut 

sub _sample_newick {
    my %options   = @_;
    my $algorithm = 'sample_' . $options{algorithm};

    # Thread 'cancellation' signal handler
    $SIG{'KILL'} = sub { threads->exit(); };
    $algorithm = \&$algorithm;

    #Perform the sampling
    my @output = ( &$algorithm(%options) );

    #Convert to newick trees
    for ( my $index = 0 ; $index < scalar @{ $output[0] } ; $index++ ) {
        $output[0]->[$index] =
          $output[0]->[$index]->to_newick( '-nodelabels' => 1 );
    }
    return @output;
}

=head2 Sampling algorithms

These algorithms should be accessed through the sampling interface (sample()).
Additional parameters need to be passed to these algorithms as described for 
each algorithm.

=over

=item sample_b()

Sample from any birth model

 Type    : Sampling algorithm
 Title   : sample_b
 Usage   : see sample
 Function: Samples trees from a pure birth model
 Returns : see sample
 Args    : %algorithm_options requires the field:
           rate => sampling rate 

=cut

sub sample_b {
    my %options = @_;

    #The sample of trees
    my @sample;

    #A list of the expected number of samples
    my @expected_summary;
    my $model = $options{model};
    my $rate  = $options{algorithm_options}->{rate};

    #While we have insufficient samples
    while ( scalar @sample < $options{sample_size} ) {

        #Generate a candidate model run
        my $candidate = &$model( %{ $options{model_options} },
            tree_size => $options{tree_size} );

        #Check that the tree has no extinctions
        unless ( $candidate->is_ultrametric(1e-6) ) {
            Bio::Phylo::Util::Exceptions::BadFormat->throw(
                'error' => "the model must be a pure birth process" );
        }

        #Get the lineage through time data
        my ( $time, $count ) = lineage_through_time($candidate);

        #The expected number of samples we want
        my $expected_samples = $rate * ( $time->[-1] - $time->[-2] );
        push( @expected_summary, $expected_samples );

        #Get the random number of samples from this candidate tree
        while ( $expected_samples > 0 ) {

            #If the number of samples remaining is greater than one
            #we take a sample, otherwise we take a sample with probability
            #according to the remaining number of samples
            if ( $expected_samples > 1 || rand(1) < $expected_samples ) {
                my $tree = copy_tree($candidate);

      #Truncate the tree at a random point during which it had tree_size species
                truncate_tree_time( $tree,
                    ( $time->[-1] - $time->[-2] ) * rand(1) + $time->[-2] );

                #Add the tree to our sample
                push( @sample, $tree );

 #Update the sample counter (for GUI or other applications that want to know how
 #many samples have been obtained)
                if ( defined $options{counter} ) {
                    my $counter = $options{counter};
                    &$counter(1);
                }
            }
            $expected_samples--;
        }
    }
    return ( \@sample, \@expected_summary );
}

=item sample_bd()

Sample from any birth and death model for which nstar exists

 Type    : Sampling algorithm
 Title   : sample_bd
 Usage   : see sample
 Function: Samples trees from a birth and death model
 Returns : see sample
 Args    : %algorithm_options requires the fields:
           nstar => once a tree has nstar species there should be
           a negligible chance of returning to tree_size species
           rate => sampling rate 

=cut

sub sample_bd {
    my %options = @_;

    #The sample of trees
    my @sample;

    #A list of the expected number of samples
    my @expected_summary;

    #Convenience variables
    my $model = $options{model};
    my $nstar = $options{algorithm_options}->{nstar};
    my $rate  = $options{algorithm_options}->{rate};

    #While we have insufficient samples
    while ( scalar @sample < $options{sample_size} ) {

        #Generate a candidate model run
        my $candidate =
          &$model( %{ $options{model_options} }, tree_size => $nstar );

        #Get the lineage through time data
        my ( $time, $count ) = lineage_through_time($candidate);

#Reorganise the lineage through time data
#@duration contains the length of the intervals with the right number of species
#@start contains the starting times of these intervals
#@prob contains the cumulative probability of each interval being selected
#$total_duration contains the sum of the interval lengths
        my ( @duration, @start, @prob, $total_duration );
        for ( my $index = 0 ; $index < scalar @{$time} - 1 ; $index++ ) {
            if ( $count->[$index] == $options{tree_size} ) {
                push( @duration, $time->[ $index + 1 ] - $time->[$index] );
                push( @start,    $time->[$index] );
                $total_duration += $duration[-1];
                push( @prob, $total_duration );
            }
        }
        no warnings 'uninitialized';    # FIXME
        next if $total_duration == 0;
        use warnings;
        for ( my $index = 0 ; $index < scalar @prob ; $index++ ) {
            $prob[$index] /= $total_duration;
        }

        #The expected number of samples we want
        my $expected_samples = $rate * $total_duration;
        push( @expected_summary, $expected_samples );

        #Get the random number of samples from this candidate tree
        while ( $expected_samples > 0 ) {

            #If the number of samples remaining is greater than one
            #we take a sample, otherwise we take a sample with probability
            #according to the remaining number of samples
            if ( $expected_samples > 1 || rand(1) < $expected_samples ) {
                my $tree = copy_tree($candidate);

                #Get a random interval
                my $interval_choice = rand(1);
                my $interval;
                for (
                    $interval = 0 ;
                    $interval_choice > $prob[$interval] ;
                    $interval++
                  )
                {
                }

                #Truncate the tree at a random point during this interval
                truncate_tree_time( $tree,
                    $duration[$interval] * rand(1) + $start[$interval] );

                #Add the tree to our sample
                push( @sample, $tree );

 #Update the sample counter (for GUI or other applications that want to know how
 #many samples have been obtained)
                if ( defined $options{counter} ) {
                    my $counter = $options{counter};
                    &$counter(1);
                }
            }
            $expected_samples--;
        }
    }
    return ( \@sample, \@expected_summary );
}

=item sample_incomplete_sampling_bd()

Sample from any birth and death model with incomplete taxon sampling

 Type    : Sampling algorithm
 Title   : sample_incomplete_sampling_bd
 Usage   : see sample
 Function: Samples trees from a birth and death model with incomplete taxon sampling
 Returns : see sample
 Args    : %algorithm_options requires the fields:
           rate => sampling rate 
           nstar => once a tree has nstar species there should be
           a negligible chance of returning to mstar species
           mstar => trees with more than mstar species form a negligible 
           contribution to the final sample.
           sampling_probability => see below.
           
sampling_probability

 vector: must have length (mstar-tree_size+1) The ith element gives the probability
         of not sampling i species.             
 scalar: the probability of sampling any individual species. Is used to calculate
         a vector as discussed in the paper.

=cut

sub sample_incomplete_sampling_bd {
    my %options = @_;

    #    %options = (%options, %{$options{algorithm_options}});
    #The sample of trees
    my @sample;

    #A list of the expected number of samples
    my @expected_summary;

    #     #Convenience variables
    my $model = $options{model};
    my $nstar = $options{algorithm_options}->{nstar};
    my $mstar = $options{algorithm_options}->{mstar};
    my $rate  = $options{algorithm_options}->{rate};
    my $sampling_probability =
      $options{algorithm_options}->{sampling_probability};

    #If sampling_probability is a list check it's length
    if ( ref $sampling_probability
        && scalar @{$sampling_probability} !=
        ( $mstar - $options{tree_size} + 1 ) )
    {
        Bio::Phylo::Util::Exceptions::BadArgs->throw( 'error' =>
"'sampling_probability' must be a scalar or a list with m_star-tree_size+1 items"
        );
    }

    #If a single sampling probability was given we calculate the
    #probability of sub-sampling given numbers of species.
    unless ( ref $sampling_probability ) {
        my $p = $sampling_probability;
        my @vec;
        my $total = 0;
        foreach ( ( $options{tree_size} .. $mstar ) ) {

#The probability of sampling tree_size species from a tree containing $_ species
            push( @vec,
                nchoosek( $_, $options{tree_size} ) *
                  ( $p**$options{tree_size} ) *
                  ( ( 1 - $p )**( $_ - $options{tree_size} ) ) );
            $total += $vec[-1];
        }
        for ( my $ii = 0 ; $ii < scalar @vec ; $ii++ ) { $vec[$ii] /= $total; }
        $sampling_probability = \@vec;
    }

    #We now normalise the sampling_probability list so that it sums to unity
    #this allows comparable sampling rates to be used here and in sample_bd
    my $total_sp = 0;
    foreach ( @{$sampling_probability} ) { $total_sp += $_; }
    no warnings;    # FIXME
    foreach ( my $index = 1 .. scalar @{$sampling_probability} ) {
        no warnings;    # FIXME
        $sampling_probability->[ $index - 1 ] /= $total_sp;
        use warnings;
    }
    use warnings;

    #While we have insufficient samples
    while ( scalar @sample < $options{sample_size} ) {

        #Generate a candidate model run
        my $candidate =
          &$model( %{ $options{model_options} }, tree_size => $nstar );

        #Get the lineage through time data
        my ( $time, $count ) = lineage_through_time($candidate);
        my @size_stats;
        for ( my $index = 0 ; $index < scalar @{$time} - 1 ; $index++ ) {
            no warnings 'uninitialized';    # FIXME
            if ( $count->[$index] >= $options{tree_size} ) {
                $size_stats[ $count->[$index] - $options{tree_size} ] +=
                  $time->[$index] *
                  $sampling_probability->[ $count->[$index] -
                  $options{tree_size} ];
            }
        }

    #Reorganise the lineage through time data
    #@duration contains the length of intervals with more than tree_size species
    #@start contains the starting times of these intervals
    #@prob contains the cumulative probability of each interval being selected
    #$total_prob contains the sum of @prob before normalisation
        my ( @duration, @start, @prob, $total_prob );
        $total_prob = 0;
        for ( my $index = 0 ; $index < scalar @{$time} - 1 ; $index++ ) {
            if ( $count->[$index] >= $options{tree_size} ) {
                push( @duration, $time->[ $index + 1 ] - $time->[$index] );
                push( @start,    $time->[$index] );
                no warnings 'uninitialized';    # FIXME
                $total_prob +=
                  $duration[-1] *
                  $sampling_probability->[ $count->[$index] -
                  $options{tree_size} ];
                push( @prob, $total_prob );
            }
        }
        next if $total_prob == 0;
        for ( my $index = 0 ; $index < scalar @prob ; $index++ ) {
            $prob[$index] /= $total_prob;
        }

        #The expected number of samples we want
        my $expected_samples = $rate * $total_prob;
        push( @expected_summary, $expected_samples );
        $expected_samples = $options{sample_size} - scalar @sample
          if $expected_samples > $options{sample_size} - scalar @sample;

        #Get the random number of samples from this candidate tree
        while ( $expected_samples > 0 ) {

            #If the number of samples remaining is greater than one
            #we take a sample, otherwise we take a sample with probability
            #according to the remaining number of samples
            if ( $expected_samples > 1 || rand(1) < $expected_samples ) {
                my $tree = copy_tree($candidate);

                #Get a random interval
                my $interval_choice = rand(1);
                my $interval;
                for (
                    $interval = 0 ;
                    $interval_choice > $prob[$interval] ;
                    $interval++
                  )
                {
                }

                #Truncate the tree at a random point during this interval
                truncate_tree_time( $tree,
                    $duration[$interval] * rand(1) + $start[$interval] );

                #Remove random species so it has the right size
                truncate_tree_size( $tree, $options{tree_size} );

                #Add the tree to our sample
                push( @sample, $tree );

 #Update the sample counter (for GUI or other applications that want to know how
 #many samples have been obtained)
                if ( defined $options{counter} ) {
                    my $counter = $options{counter};
                    &$counter(1);
                }
            }
            $expected_samples--;
        }
    }
    return ( \@sample, \@expected_summary );
}

=item sample_memoryless_b()

Sample from a memoryless birth model

 Type    : Sampling algorithm
 Title   : sample_memoryless_b
 Usage   : see sample
 Function: Samples trees from a memoryless birth model
 Returns : see sample
 Args    : %algorithm_options with fields:
           pendant_dist => function reference for generating random
           shortest pendant edges 

NB: The function pointed to by pendant_dist is given model_options
as it's input argument with an added field tree_size. It must return
a random value from the probability density for the shortest pendant
edges.

=cut

sub sample_memoryless_b {
    my %options = @_;

    #The sample of trees
    my @sample;

    #A list of the expected number of samples
    my @expected_summary;

    #The user specified functions
    my $model        = $options{model};
    my $pendant_dist = $options{algorithm_options}->{pendant_dist};

    #While we have insufficient samples
    while ( scalar @sample < $options{sample_size} ) {

        #Generate a tree ending just after the last speciation event
        my $tree = &$model( %{ $options{model_options} },
            tree_size => $options{tree_size} );

        #Check that the tree has no extinctions
        unless ( $tree->is_ultrametric(1e-6) ) {
            Bio::Phylo::Util::Exceptions::BadFormat->throw(
                'error' => "the model must be a pure birth process" );
        }

        #Get the random length to add after the last speciation event
        my $pendant_add = &$pendant_dist( %{ $options{model_options} },
            tree_size => $options{tree_size} );

        #Add the final length
        foreach ( @{ $tree->get_terminals } ) {
            $_->set_branch_length( $_->get_branch_length + $pendant_add );
        }

        #Add to the sample
        push( @sample,           $tree );
        push( @expected_summary, 1 );

 #Update the sample counter (for GUI or other applications that want to know how
 #many samples have been obtained)
        if ( defined $options{counter} ) {
            my $counter = $options{counter};
            &$counter(1);
        }
    }
    return ( \@sample, \@expected_summary );
}

=item sample_constant_rate_bd()

Sample from a constant rate birth and death model

 Type    : Sampling algorithm
 Title   : sample_constant_rate_bd
 Usage   : see sample
 Function: Samples trees from a memoryless birth model
 Returns : see sample
 Args    : no specific algorithm options but see below

NB: This algorithm only applies to constant rate birth and death 
processes. Consequently a model does not need to be specified (and
will be ignored if it is). But birth_rate and death_rate model 
options must be given. 

=cut

sub sample_constant_rate_bd {
    my %options = @_;

    #Store parameters in shorter variables (for clarity)
    my ( $br, $dr, $n ) = (
        $options{model_options}->{birth_rate},
        $options{model_options}->{death_rate},
        $options{tree_size}
    );
    my @sample;

    #Loop for sampling each tree
    while ( scalar @sample < $options{sample_size} ) {
        my @nodes;

       #Compute the random tree age from the inverse CDF (different formulas for
       #birth rate == death rate and otherwise)
        my $tree_age;

        #The uniform random variable
        my $r = rand;
        if ( $br == $dr ) {
            $tree_age = 1 / ( $br * ( $r**( -1 / $n ) - 1 ) );
        }
        else {
            $tree_age =
              1 /
              ( $br - $dr ) *
              log(
                ( 1 - $dr / $br * $r**( 1 / $n ) ) / ( 1 - $r**( 1 / $n ) ) );
        }

        #Find the random speciation times
        my @speciation;
        foreach ( 0 .. ( $n - 2 ) ) {
            if ( $br == $dr ) {
                my $r = rand;
                $speciation[$_] =
                  $r * $tree_age / ( 1 + $br * $tree_age * ( 1 - $r ) );
            }
            else {

                #Two repeated parts of the inverse CDF for clarity
                my $a = $br - $dr * exp( ( $dr - $br ) * $tree_age );
                my $b = ( 1 - exp( ( $dr - $br ) * $tree_age ) ) * rand;

                #The random speciation time from the inverse CDF
                $speciation[$_] =
                  1 /
                  ( $br - $dr ) *
                  log( ( $a - $dr * $b ) / ( $a - $br * $b ) );
            }
        }

        #Create the initial terminals and a vector for their ages
        my @terminals;
        my @ages;
        foreach ( 0 .. ( $n - 1 ) ) {

            #Add a new terminal
            $terminals[$_] = Bio::Phylo::Forest::Node->new();
            $terminals[$_]->set_name( 'ID' . $_ );
            $ages[$_] = 0;
        }
        @nodes = @terminals;

        #Sort the speciation times
        my @sorted_speciation = sort { $a <=> $b } @speciation;

        #Make a hash for easily finding the index of a given speciation event
        my %speciation_hash;
        foreach ( 0 .. ( $n - 2 ) ) {
            $speciation_hash{ $speciation[$_] } = $_;
        }

        #Construct the tree
        foreach my $index ( 0 .. ( $n - 2 ) ) {

            #Create the parent node
            my $parent = Bio::Phylo::Forest::Node->new();
            $parent->set_name( 'ID' . ( $n + $index ) );
            push( @nodes, $parent );

            #An index for this speciation event back into the unsorted vectors
            my $spec_index = $speciation_hash{ $sorted_speciation[$index] };

            #Add the children to the parent node
            $parent->set_child( $terminals[$spec_index] );
            $terminals[$spec_index]->set_parent($parent);
            $parent->set_child( $terminals[ $spec_index + 1 ] );
            $terminals[ $spec_index + 1 ]->set_parent($parent);

            #Set the children's branch lengths
            $terminals[$spec_index]->set_branch_length(
                $sorted_speciation[$index] - $ages[$spec_index] );
            $terminals[ $spec_index + 1 ]->set_branch_length(
                $sorted_speciation[$index] - $ages[ $spec_index + 1 ] );

            #Replace the two terminals with the new one
            splice( @terminals, $spec_index, 2, $parent );
            splice( @ages,      $spec_index, 2, $sorted_speciation[$index] );

            #Update the mapping for the sorted speciation times
            foreach ( keys %speciation_hash ) {
                $speciation_hash{$_}-- if $speciation_hash{$_} > $spec_index;
            }
        }

        #Add the nodes to a tree
        my $tree = Bio::Phylo::Forest::Tree->new();
        foreach ( reverse(@nodes) ) { $tree->insert($_); }
        push( @sample, $tree );

 #Update the sample counter (for GUI or other applications that want to know how
 #many samples have been obtained)
        if ( defined $options{counter} ) {
            my $counter = $options{counter};
            &$counter(1);
        }
    }
    return ( \@sample, [] );
}

=back

=head1 EVOLUTIONARY MODELS

All evolutionary models take a options hash as their input argument
and return a Bio::Phylo::Forest::Tree. This tree may contain extinct
lineages (lineages that end prior to the end of the tree).

The options hash contains any model specific parameters (see the 
individual model descriptions) and one or both terminating conditions:
tree_size => the number of extant species at which to terminate the tree
tree_age => the age of the tree at which to terminate the process

Note that if the model stops due to the tree_size condition then the 
tree ends immediately after the speciation event that created the last
species.

=over    

=item constant_rate_birth()

A constant rate birth model (Yule/ERM)

 Type    : Evolutionary model
 Title   : constant_rate_birth
 Usage   : $tree = constant_rate_birth(%options)
 Function: Produces a tree from the model terminating at a given size/time
 Returns : Bio::Phylo::Forest::Tree
 Args    : %options with fields:
           birth_rate The birth rate parameter (default 1)
           tree_size  The size of the tree at which to terminate
           tree_age   The age of the tree at which to terminate

 NB: At least one of tree_size and tree_age must be specified           

=cut

sub constant_rate_birth {
    my %options = @_;
    $options{death_rate} = 0;
    return constant_rate_birth_death(%options);
}

=item external_model()

A dummy model that takes as input a set of newick_trees and randomly samples
these.

 Type    : Evolutionary model
 Title   : external_model
 Usage   : $tree = $external_model(%options)
 Function: Returns a random tree that was given as input
 Returns : Bio::Phylo::Forest::Tree
 Args    : %options with fields:
           trees      An array of newick strings. One of these is returned at random.

 NB: The usual parameters tree_size and tree_age will be ignored. When sampling 
     using this model the trees array must contain trees adhering to the requirements
     of the sampling algorithm. This is NOT checked automatically.

=cut

sub external_model {
    my %options = @_;
    my $choice  = int( rand( scalar @{ $options{trees} } ) );

    #Pick a newick string and turn it in to a Bio::Phylo::Forest::Tree object
    my $tree = Bio::Phylo::IO->parse(
        -format => 'newick',
        -string => $options{trees}->[$choice]
    )->first;
    return $tree;
}

=item constant_rate_birth_death()

A constant rate birth and death model

 Type    : Evolutionary model
 Title   : constant_rate_birth_death
 Usage   : $tree = constant_rate_birth_death(%options)
 Function: Produces a tree from the model terminating at a given size/time
 Returns : Bio::Phylo::Forest::Tree
 Args    : %options with fields:
           birth_rate The birth rate parameter (default 1)
           death_rate The death rate parameter (default no extinction)
           tree_size  The size of the tree at which to terminate
           tree_age   The age of the tree at which to terminate

 NB: At least one of tree_size and tree_age must be specified           

=cut

sub constant_rate_birth_death {
    my %options = @_;

    #Check that we have a termination condition
    unless ( defined $options{tree_size} or defined $options{tree_age} ) {

        #Error here.
        return undef;
    }

    #Set the undefined condition to infinity
    $options{tree_size} = 1e6 unless defined $options{tree_size};
    $options{tree_age}  = 1e6 unless defined $options{tree_age};

    #Set default rates
    $options{birth_rate} = 1 unless defined( $options{birth_rate} );
    delete $options{death_rate}
      if defined( $options{death_rate} ) && $options{death_rate} == 0;

    #Each node gets an ID number this tracks these
    my $node_id = 0;

    #Create a new tree with a root, start the list of terminal species
    my $tree = Bio::Phylo::Forest::Tree->new();
    my $root = Bio::Phylo::Forest::Node->new();
    $root->set_branch_length(0);
    $root->set_name( 'ID' . $node_id++ );
    $tree->insert($root);
    my @terminals = ($root);
    my ( $next_extinction, $next_speciation );
    my $time      = 0;
    my $tree_size = 1;

    #Check whether we have a non-zero root edge
    if ( defined $options{root_edge} && $options{root_edge} ) {

        #Non-zero root. We set the time to the first speciation event
        $next_speciation = -log(rand) / $options{birth_rate} / $tree_size;
    }
    else {

        #Zero root, we want a speciation event straight away
        $next_speciation = 0;
    }

    #Time of the first extinction event. If no extinction we always
    #set the extinction event after the current speciation event
    if ( defined $options{death_rate} ) {
        $next_extinction = -log(rand) / $options{death_rate} / $tree_size;
    }
    else {
        $next_extinction = $next_speciation + 1;
    }

    #While the tree has not become extinct and the termination criterion
    #has not been achieved we create new speciation and extinction events
    while ($tree_size > 0
        && $tree_size < $options{tree_size}
        && $time < $options{tree_age} )
    {

        #Add the time since the last event to all terminal species
        foreach (@terminals) {
            $_->set_branch_length(
                $_->get_branch_length + min(
                    $next_extinction, $next_speciation,
                    $options{tree_age} - $time
                )
            );
        }

        #Update the time
        $time += min( $next_extinction, $next_speciation );

        #If the tree exceeds the time limit we are done
        return $tree if ( $time > $options{tree_age} );

   #Get the species effected by this event and remove it from the terminals list
        my $effected =
          splice( @terminals, int( rand( scalar @terminals ) ), 1 );

        #If we have a speciation event we add two new species
        if ( $next_speciation < $next_extinction || !defined $next_extinction )
        {
            foreach ( 1, 2 ) {

                #Create a new species
                my $child = Bio::Phylo::Forest::Node->new();
                $child->set_name( 'ID' . $node_id++ );

                #Give it a zero edge length
                $child->set_branch_length(0);

                #Add it as a child to the speciating species
                $effected->set_child($child);

                #Add it to the tree
                $tree->insert($child);

                #Add it to the terminals list
                push( @terminals, $child );
            }
        }

        #We calculate the time that the next extinction and speciation
        #events will occur (only the earliest of these will actually
        #happen). NB: this approach is only appropriate for models where
        #speciation and extinction times are exponentially distributed.
        #Windows sometimes returns 0 values for rand...
        my ( $r1, $r2 ) = ( 0, 0 );
        $r1 = rand until $r1;
        $r2 = rand until $r2;
        $tree_size = scalar @terminals;
        return $tree unless $tree_size;
        $next_speciation = -log($r1) / $options{birth_rate} / $tree_size;
        if ( defined $options{death_rate} ) {
            $next_extinction = -log($r2) / $options{death_rate} / $tree_size;
        }
        else {
            $next_extinction = $next_speciation + 1;
        }
    }
    return $tree;
}


=item diversity_dependent_speciation()

A birth and death model with speciation rate dependent on diversity as per
Etienne et. al. 2012

 Type    : Evolutionary model
 Title   : diversity_dependent_speciation
 Usage   : $tree = diversity_dependent_speciation(%options)
 Function: Produces a tree from the model terminating at a given size/time
 Returns : Bio::Phylo::Forest::Tree
 Args    : %options with fields:
           maximal_birth_rate The maximal birth rate parameter (default 1)
           death_rate The death rate parameter (default no extinction)
           K_dash     The modified carrying capacity (no default)
           tree_size  The size of the tree at which to terminate
           tree_age   The age of the tree at which to terminate

 NB: At least one of tree_size and tree_age must be specified           

Reference:
Rampal S. Etienne, Bart Haegeman, Tanja Stadler, Tracy Aze, Paul N. Pearson, 
Andy Purvis and Albert B. Phillimore. "Diversity-dependence brings molecular 
phylogenies closer to agreement with the fossil record" 
doi: 10.1098/rspb.2011.1439

=cut

sub diversity_dependent_speciation {
    my %options = @_;

    #Check that we have a termination condition
    unless ( defined $options{tree_size} or defined $options{tree_age} ) {
        #Error here.
        return undef;
    }

    #Check that we have a carrying capacity
    unless ( defined $options{K_dash} ) {
        #Error here.
        return undef;
    }

    #Set the undefined condition to infinity
    $options{tree_size} = 1e6 unless defined $options{tree_size};
    $options{tree_age}  = 1e6 unless defined $options{tree_age};

    #Set default rates
    $options{maximal_birth_rate} = 1 unless defined( $options{maximal_birth_rate} );
    delete $options{death_rate}
      if defined( $options{death_rate} ) && $options{death_rate} == 0;

    #Each node gets an ID number this tracks these
    my $node_id = 0;

    #Create a new tree with a root, start the list of terminal species
    my $tree = Bio::Phylo::Forest::Tree->new();
    my $root = Bio::Phylo::Forest::Node->new();
    $root->set_branch_length(0);
    $root->set_name( 'ID' . $node_id++ );
    $tree->insert($root);
    my @terminals = ($root);
    my ( $next_extinction, $next_speciation );
    my $time      = 0;
    my $tree_size = 1;
    
    
    $options{birth_rate} = max(0,$options{max_birth_rate}*(1-1/$options{K_dash}));
    

    #Check whether we have a non-zero root edge
    if ( defined $options{root_edge} && $options{root_edge} ) {

        #Non-zero root. We set the time to the first speciation event
        $next_speciation = -log(rand) / $options{birth_rate} / $tree_size;
    }
    else {

        #Zero root, we want a speciation event straight away
        $next_speciation = 0;
    }

    #Time of the first extinction event. If no extinction we always
    #set the extinction event after the current speciation event
    if ( defined $options{death_rate} ) {
        $next_extinction = -log(rand) / $options{death_rate} / $tree_size;
    }
    else {
        $next_extinction = $next_speciation + 1;
    }

    #While the tree has not become extinct and the termination criterion
    #has not been achieved we create new speciation and extinction events
    while ($tree_size > 0
        && $tree_size < $options{tree_size}
        && $time < $options{tree_age} )
    {

        #Add the time since the last event to all terminal species
        foreach (@terminals) {
            $_->set_branch_length(
                $_->get_branch_length + min(
                    $next_extinction, $next_speciation,
                    $options{tree_age} - $time
                )
            );
        }

        #Update the time
        $time += min( $next_extinction, $next_speciation );

        #If the tree exceeds the time limit we are done
        return $tree if ( $time > $options{tree_age} );

        #Get the species effected by this event and remove it from the terminals list
        my $effected =
          splice( @terminals, int( rand( scalar @terminals ) ), 1 );

        #If we have a speciation event we add two new species
        if ( $next_speciation < $next_extinction || !defined $next_extinction )
        {
            foreach ( 1, 2 ) {

                #Create a new species
                my $child = Bio::Phylo::Forest::Node->new();
                $child->set_name( 'ID' . $node_id++ );

                #Give it a zero edge length
                $child->set_branch_length(0);

                #Add it as a child to the speciating species
                $effected->set_child($child);

                #Add it to the tree
                $tree->insert($child);

                #Add it to the terminals list
                push( @terminals, $child );
            }
        }

        #We calculate the time that the next extinction and speciation
        #events will occur (only the earliest of these will actually
        #happen). NB: this approach is only appropriate for models where
        #speciation and extinction times are exponentially distributed.
        #Windows sometimes returns 0 values for rand...
        my ( $r1, $r2 ) = ( 0, 0 );
        $r1 = rand until $r1;
        $r2 = rand until $r2;
        $tree_size = scalar @terminals;
        return $tree unless $tree_size;
        
        $options{birth_rate} = max(0,$options{max_birth_rate}*(1-$tree_size/$options{K_dash}));
        if ($options{birth_rate}==0)
        {
        	$next_speciation = $options{tree_age};
        } else
        {
        	$next_speciation = -log($r1) / $options{birth_rate} / $tree_size;
        }
        if ( defined $options{death_rate} ) {
            $next_extinction = -log($r2) / $options{death_rate} / $tree_size;
        }
        else {
            $next_extinction = $next_speciation + 1;
        }
    }
    return $tree;
}


=item constant_rate_birth_death()

A temporal shift birth and death model

 Type    : Evolutionary model
 Title   : temporal_shift_birth_death
 Usage   : $tree = constant_rate_birth_death(%options)
 Function: Produces a tree from the model terminating at a given size/time
 Returns : Bio::Phylo::Forest::Tree
 Args    : %options with fields:
           birth_rates The birth rates 
           death_rates The death rates
           rate_times  The times after which the rates apply (first element must be 0)
           tree_size  The size of the tree at which to terminate
           tree_age   The age of the tree at which to terminate

 NB: At least one of tree_size and tree_age must be specified           

=cut

sub temporal_shift_birth_death {
    my %options = @_;

    #Check that we have a termination condition
    unless ( defined $options{tree_size} or defined $options{tree_age} ) {

        #Error here.
        return undef;
    }

    #Set the undefined condition to infinity
    $options{tree_size} = 1e6 unless defined $options{tree_size};
    $options{tree_age}  = 1e6 unless defined $options{tree_age};

    #Each node gets an ID number this tracks these
    my $node_id = 0;

    #Create a new tree with a root, start the list of terminal species
    my $tree = Bio::Phylo::Forest::Tree->new();
    my $root = Bio::Phylo::Forest::Node->new();
    $root->set_branch_length(0);
    $root->set_name( 'ID' . $node_id++ );
    $tree->insert($root);
    my @terminals = ($root);
    my ( $next_extinction, $next_speciation );
    my $time      = 0;
    my $tree_size = 1;

    #Load current rates
    my $birth_rate = $options{birth_rates}[0];
    my $death_rate = $options{death_rates}[0];
    my $current_rates = 0;
    my $next_rate_change = $options{rate_times}[$current_rates+1];
    
    #Add an additional time to the end of the rate change times to simplify checking
    push(@{$options{rate_times}},$options{tree_size}*2);

    #Check whether we have a non-zero root edge
    if ( defined $options{root_edge} && $options{root_edge} ) {

        #Non-zero root. We set the time to the first speciation event
        $next_speciation = -log(rand) / $birth_rate / $tree_size;
    }
    else {

        #Zero root, we want a speciation event straight away
        $next_speciation = 0;
    }

#        print  "RATES:".$time."|".$birth_rate."|".$death_rate."\n";
    #Time of the first extinction event. If no extinction we always
    #set the extinction event after the current speciation event
    $next_extinction = -log(rand) / $death_rate / $tree_size;

    #While the tree has not become extinct and the termination criterion
    #has not been achieved we create new speciation and extinction events
    while ($tree_size > 0
        && $tree_size < $options{tree_size}
        && $time < $options{tree_age} )
    {

#        print  "TIMES:".$next_extinction."|".$next_speciation."|".$next_rate_change."|\n";
#        print  "RATES:".$time."|".$birth_rate."|".$death_rate."\n";
        #Add the time since the last event to all terminal species
        foreach (@terminals) {
            $_->set_branch_length(
                $_->get_branch_length + min(
                    $next_extinction, $next_speciation,
                    $options{tree_age} - $time
                )
            );
        }

        #Update the time
        my $time_last = $time;
        $time += min( $next_extinction, $next_speciation, $next_rate_change-$time_last);

        #If the tree exceeds the time limit we are done
        return $tree if ( $time > $options{tree_age} );

        
        if ($next_rate_change-$time_last < min( $next_extinction, $next_speciation) )
        {
            $current_rates += 1;
            $birth_rate = $options{birth_rates}[$current_rates];
            $death_rate = $options{death_rates}[$current_rates];
            $next_rate_change = $options{rate_times}[$current_rates+1];
            
        } else
        {
                

            #Get the species effected by this event and remove it from the terminals list
            my $effected = splice( @terminals, int( rand( scalar @terminals ) ), 1 );

            #If we have a speciation event we add two new species
            if ( $next_speciation < $next_extinction || !defined $next_extinction )
            {
                foreach ( 1, 2 ) {

                    #Create a new species
                    my $child = Bio::Phylo::Forest::Node->new();
                    $child->set_name( 'ID' . $node_id++ );

                    #Give it a zero edge length
                    $child->set_branch_length(0);

                    #Add it as a child to the speciating species
                    $effected->set_child($child);

                    #Add it to the tree
                    $tree->insert($child);

                    #Add it to the terminals list
                    push( @terminals, $child );
                }
            }
        }

        #We calculate the time that the next extinction and speciation
        #events will occur (only the earliest of these will actually
        #happen). NB: this approach is only appropriate for models where
        #speciation and extinction times are exponentially distributed.
        #Windows sometimes returns 0 values for rand...
        my ( $r1, $r2 ) = ( 0, 0 );
        $r1 = rand until $r1;
        $r2 = rand until $r2;
        $tree_size = scalar @terminals;
        return $tree unless $tree_size;
        $next_speciation = -log($r1) / $birth_rate / $tree_size;
        $next_extinction = -log($r2) / $death_rate / $tree_size;
        
        if ((scalar @terminals)%100==0)
        {
                print $time."|".@terminals."|\n";
                }

    }
    return $tree;
}

=item evolving_speciation_rate()

An evolutionary model featuring evolving speciation rates. Each daughter 
species is assigned its parent's speciation rate multiplied by a normally 
distributed noise factor.

 Type    : Evolutionary model
 Title   : evolving_speciation_rate
 Usage   : $tree = evolving_speciation_rate(%options)
 Function: Produces a tree from the model terminating at a given size/time
 Returns : Bio::Phylo::Forest::Tree
 Args    : %options with fields:
           birth_rate The initial speciation rate (default 1)
           evolving_std The standard deviation of the normal distribution 
                      from which the rate multiplier is drawn.
           tree_size  The size of the tree at which to terminate
           tree_age   The age of the tree at which to terminate

 NB: At least one of tree_size and tree_age must be specified           

=cut

sub evolving_speciation_rate {
    my %options = @_;

    #Check that we have a termination condition
    unless ( defined $options{tree_size} or defined $options{tree_age} ) {

        #Error here.
        return undef;
    }

    #Set the undefined condition to infinity
    $options{tree_size} = 1e6 unless defined $options{tree_size};
    $options{tree_age}  = 1e6 unless defined $options{tree_age};

    #Set default rates
    $options{birth_rate}   = 1 unless defined( $options{birth_rate} );
    $options{evolving_std} = 1 unless defined( $options{evolving_std} );

    #Each node gets an ID number this tracks these
    my $node_id = 0;

    #Create a new tree with a root, start the list of terminal species
    my $tree = Bio::Phylo::Forest::Tree->new();
    my $root = Bio::Phylo::Forest::Node->new();
    $root->set_branch_length(0);
    $root->set_name( 'ID' . $node_id++ );
    $tree->insert($root);
    my @terminals   = ($root);
    my @birth_rates = ( $options{birth_rate} );
    my $net_rate    = $options{birth_rate};
    my $next_speciation;
    my $time      = 0;
    my $tree_size = 1;

    #Check whether we have a non-zero root edge
    if ( defined $options{root_edge} && $options{root_edge} ) {

        #Non-zero root. We set the time to the first speciation event
        $next_speciation = -log(rand) / $options{birth_rate} / $tree_size;
    }
    else {

        #Zero root, we want a speciation event straight away
        $next_speciation = 0;
    }

    #While we haven't reached termination
    while ( $tree_size < $options{tree_size} && $time < $options{tree_age} ) {

        #Add the time since the last event to all terminal species
        foreach (@terminals) {
            $_->set_branch_length( $_->get_branch_length +
                  min( $next_speciation, $options{tree_age} - $time ) );
        }

        #Update the time
        $time += $next_speciation;

        #If the tree exceeds the time limit we are done
        return $tree if ( $time > $options{tree_age} );

        #Get the species effected by this event
        my $rand_select = rand($net_rate);
        my $selected    = 0;
        for (
            ;
            $selected < scalar @terminals
            && $rand_select > $birth_rates[$selected] ;
            $selected++
          )
        {
            $rand_select -= $birth_rates[$selected];
        }

        #Remove it from the terminals list
        my $effected      = splice( @terminals,   $selected, 1 );
        my $effected_rate = splice( @birth_rates, $selected, 1 );

        #Update the net speciation rate
        $net_rate -= $effected_rate;

        #If we have a speciation event we add two new species
        foreach ( 1, 2 ) {

            #Create a new species
            my $child = Bio::Phylo::Forest::Node->new();
            $child->set_name( 'ID' . $node_id++ );

            #Give it a zero edge length
            $child->set_branch_length(0);

            #Add it as a child to the speciating species
            $effected->set_child($child);

            #Add it to the tree
            $tree->insert($child);

            #Add it to the terminals list
            push( @terminals, $child );

            #New speciation rate
            my $new_speciation_rate =
              $effected_rate * ( 1 + qnorm(rand) * $options{evolving_std} );
            if ( $new_speciation_rate < 0 ) { $new_speciation_rate = 0; }
            push( @birth_rates, $new_speciation_rate );
            $net_rate += $new_speciation_rate;
        }

        #   $net_rate = 0;
        #   foreach (@birth_rates) { $net_rate += $_; }
        #Windows sometimes returns 0 values for rand...
        my ( $r1, $r2 ) = ( 0, 0 );
        $r1 = rand until $r1;
        $tree_size = scalar @terminals;

        #If all species have stopped speciating (unlikely)
        if ( $net_rate == 0 ) {
            return $tree;
        }
        $next_speciation = -log($r1) / $net_rate / $tree_size;
        return $tree unless $tree_size;
    }
    return $tree;
}


=item clade_shifts()

A constant rate birth-death model with punctuated changes in the speciation
and extinction rates. At each change one lineage receives new pre-specified
speciation and extinction rates.

 Type    : Evolutionary model
 Title   : clade_shifts
 Usage   : $tree = clade_shifts(%options)
 Function: Produces a tree from the model terminating at a given size/time
 Returns : Bio::Phylo::Forest::Tree
 Args    : %options with fields:
           birth_rates The speciation rates
           death_rates The death rates
           rate_times  The times at which the rates are introduced to a new
             clade. The first time should be zero. The remaining must be in 
             ascending order.
           tree_size  The size of the tree at which to terminate
           tree_age   The age of the tree at which to terminate

 NB: At least one of tree_size and tree_age must be specified           

=cut

sub clade_shifts {
    my %options = @_;

    #Check that we have a termination condition
    unless ( defined $options{tree_size} or defined $options{tree_age} ) {

        #Error here.
        return undef;
    }

    #Set the undefined condition to infinity
    $options{tree_size} = 1e6 unless defined $options{tree_size};
    $options{tree_age}  = 1e6 unless defined $options{tree_age};

    #Each node gets an ID number this tracks these
    my $node_id = 0;

    #Create a new tree with a root, start the list of terminal species
    my $tree = Bio::Phylo::Forest::Tree->new();
    my $root = Bio::Phylo::Forest::Node->new();
    $root->set_branch_length(0);
    $root->set_name( 'ID' . $node_id++ );
    $tree->insert($root);
    
    #rates
    my @birth_rates_in = @{$options{birth_rates}};
    my @death_rates_in = @{$options{death_rates}};
    my @rate_times_in = @{$options{rate_times}};
    
    if ($rate_times_in[0] != 0)
    {
        Bio::Phylo::Util::Exceptions::BadArgs->throw( 'error' =>
              "The first rate time must be 0" );
    }
    if (scalar @birth_rates_in != scalar @death_rates_in)
    {
        Bio::Phylo::Util::Exceptions::BadArgs->throw( 'error' =>
              "birth and death rates must have the same length" );
    }
    if (scalar @birth_rates_in != scalar @rate_times_in)
    {
        Bio::Phylo::Util::Exceptions::BadArgs->throw( 'error' =>
              "birth/death rates must have the same length as rate times" );
    }
    my @birth_rates = ($birth_rates_in[0]);
    my @death_rates = ($death_rates_in[0]);
    
    my $net_birth_rate = $birth_rates[0];
    my $net_death_rate = $death_rates[0];
    
    shift(@birth_rates_in);
    shift(@death_rates_in);
    
    my @terminals = ($root);
    my ( $next_extinction, $next_speciation, $next_rate_change );
    my $time      = 0;
    my $tree_size = 1;
    my $inf = 9**9**9**9;

    #Check whether we have a non-zero root edge
    if ( defined $options{root_edge} && $options{root_edge} ) {

        #Non-zero root. We set the time to the first speciation event
        if ($birth_rates[0] > 0)
        {
            $next_speciation = -log(rand) / $birth_rates[0] ;
        } else
        { 
            $next_speciation = $inf;
        }
    }
    else {
        #Zero root, we want a speciation event straight away
        $next_speciation = 0.0;
    }

    #Time of the first extinction event. If no extinction we always
    #set the extinction event after the current speciation event
    if ($death_rates[0] > 0)
    {
        $next_extinction = -log(rand) / $death_rates[0];
    } else
    {
        $next_extinction = $inf;
    }
    
    #Time of next rate change
    shift(@rate_times_in); #pop the initial 0
    $next_rate_change = shift(@rate_times_in);
    
    #While the tree has not become extinct and the termination criterion
    #has not been achieved we create new speciation and extinction events
    while ($tree_size > 0
        && $tree_size < $options{tree_size}
        && $time < $options{tree_age} )
    {
        #print $time."|".$tree_size."\n";
        #Update rates if a clade shift is happening
        #TODO index rates or pop off one at a time.
        

        #Add the time since the last event to all terminal species
        foreach (@terminals) {
            $_->set_branch_length(
                $_->get_branch_length + min(
                    $next_extinction, 
                    $next_speciation,
                    $next_rate_change-$time,
                    $options{tree_age} - $time
                )
            );
        }

        #Update the time
        my $time_last = $time;
        $time += min( $next_extinction, $next_speciation, $next_rate_change-$time_last );

        #If the tree exceeds the time limit we are done
        return $tree if ( $time > $options{tree_age} );
        
        #We have a rate change
        if ($next_rate_change-$time_last < min($next_extinction, $next_speciation))
        {   
            #Find a random species to effect
            my $effected_species = int(rand($tree_size));
            #Subtract current rates
            $net_death_rate -= $death_rates[$effected_species];
            $net_birth_rate -= $birth_rates[$effected_species];
            #Get new rates
            $death_rates[$effected_species] = shift(@death_rates_in);
            $birth_rates[$effected_species] = shift(@birth_rates_in);
            #Add new rates
            $net_death_rate += $death_rates[$effected_species];
            $net_birth_rate += $birth_rates[$effected_species];
            #Get next rate change time
            if (scalar(@rate_times_in))
            {
                $next_rate_change = shift(@rate_times_in);
            } else 
            {
                $next_rate_change = $inf;
            }
        }
        #Choosing a random species to speciate
        else 
        {
            my $selected    = 0;
            if ( $next_speciation < $next_extinction )
            {
                my $rand_select = rand($net_birth_rate);
                for (
                    ;
                    $selected < scalar @terminals
                    && $rand_select > $birth_rates[$selected] ;
                    $selected++
                )
                {
                    $rand_select -= $birth_rates[$selected];
                }
            } else
            {
                my $rand_select = rand($net_death_rate);
                for (
                    ;
                    $selected < scalar @terminals
                    && $rand_select > $death_rates[$selected] ;
                    $selected++
                )
                {
                    $rand_select -= $death_rates[$selected];
                }
            }
            if ($net_birth_rate == 0)
            {
                $selected = 0;
            }

            #Remove the species effected by this event and remove it from the terminals list
            my $effected      = splice( @terminals,   $selected, 1 );
            my $effected_birth_rate = splice( @birth_rates, $selected, 1 );
            my $effected_death_rate = splice( @death_rates, $selected, 1 );
            
            $net_birth_rate -= $effected_birth_rate;
            $net_death_rate -= $effected_death_rate;

            #If we have a speciation event we add two new species
            if ( $next_speciation < $next_extinction || !defined $next_extinction )
            {
                foreach ( 1, 2 ) {

                    #Create a new species
                    my $child = Bio::Phylo::Forest::Node->new();
                    $child->set_name( 'ID' . $node_id++ );

                    #Give it a zero edge length
                    $child->set_branch_length(0);

                    #Add it as a child to the speciating species
                    $effected->set_child($child);

                    #Add it to the tree
                    $tree->insert($child);

                    #Add it to the terminals list
                    push( @terminals, $child );
                    
                    push( @birth_rates, $effected_birth_rate );
                    push( @death_rates, $effected_death_rate );
                    
                    $net_death_rate += $effected_death_rate;
                    $net_birth_rate += $effected_birth_rate;
                    
                }
            }
        }
        #We calculate the time that the next extinction and speciation
        #events will occur (only the earliest of these will actually
        #happen). NB: this approach is only appropriate for models where
        #speciation and extinction times are exponentially distributed.
        
        #Windows sometimes returns 0 values for rand...
        my ( $r1, $r2 ) = ( 0, 0 );
        $r1 = rand until $r1;
        $r2 = rand until $r2;
        
        #The current tree size
        $tree_size = scalar @terminals;
        
        return $tree unless $tree_size;
        
        if ($net_birth_rate > 0)
        {
            $next_speciation = -log($r1) / $net_birth_rate;
        } else 
        {
            $next_speciation = $inf;
        }
        
        if ($net_death_rate > 0)
        {
            $next_extinction = -log($r2) / $net_death_rate;
        } else
        {
            $next_extinction = $inf;
        }

    }
    return $tree;
}

=item beta_binomial()

An evolutionary model featuring evolving speciation rates. From Blum2007

 Type    : Evolutionary model
 Title   : beta_binomial
 Usage   : $tree = beta_binomial(%options)
 Function: Produces a tree from the model terminating at a given size/time
 Returns : Bio::Phylo::Forest::Tree
 Args    : %options with fields:
           birth_rate The initial speciation rate (default 1)
           model_param The parameter as defined in Blum2007
           tree_size  The size of the tree at which to terminate
           tree_age   The age of the tree at which to terminate

 NB: At least one of tree_size and tree_age must be specified           

=cut

sub beta_binomial {
    my %options = @_;

    #Check that we have a termination condition
    unless ( defined $options{tree_size} or defined $options{tree_age} ) {

        #Error here.
        return undef;
    }

    #Set the undefined condition to infinity
    $options{tree_size} = 1e6 unless defined $options{tree_size};
    $options{tree_age}  = 1e6 unless defined $options{tree_age};

    #Set default rates
    $options{birth_rate}  = 1 unless defined( $options{birth_rate} );
    $options{model_param} = 0 unless defined( $options{model_param} );

    #Each node gets an ID number this tracks these
    my $node_id = 0;

    #Create a new tree with a root, start the list of terminal species
    my $tree = Bio::Phylo::Forest::Tree->new();
    my $root = Bio::Phylo::Forest::Node->new();
    $root->set_branch_length(0);
    $root->set_name( 'ID' . $node_id++ );
    $tree->insert($root);
    my @terminals   = ($root);
    my @birth_rates = ( $options{birth_rate} );
    my $net_rate    = $options{birth_rate};
    my $next_speciation;
    my $time      = 0;
    my $tree_size = 1;

    #Check whether we have a non-zero root edge
    if ( defined $options{root_edge} && $options{root_edge} ) {

        #Non-zero root. We set the time to the first speciation event
        $next_speciation = -log(rand) / $options{birth_rate} / $tree_size;
    }
    else {

        #Zero root, we want a speciation event straight away
        $next_speciation = 0;
    }

    #While we haven't reached termination
    while ( $tree_size < $options{tree_size} && $time < $options{tree_age} ) {

        #Add the time since the last event to all terminal species
        foreach (@terminals) {
            $_->set_branch_length( $_->get_branch_length +
                  min( $next_speciation, $options{tree_age} - $time ) );
        }

        #Update the time
        $time += $next_speciation;

        #If the tree exceeds the time limit we are done
        return $tree if ( $time > $options{tree_age} );

        #Get the species effected by this event
        my $rand_select = rand($net_rate);
        my $selected    = 0;
        for (
            ;
            $selected < scalar @terminals
            && $rand_select > $birth_rates[$selected] ;
            $selected++
          )
        {
            $rand_select -= $birth_rates[$selected];
        }

        #Remove it from the terminals list
        my $effected      = splice( @terminals,   $selected, 1 );
        my $effected_rate = splice( @birth_rates, $selected, 1 );
        my $p =
          qbeta( rand, $options{model_param} + 1, $options{model_param} + 1 );

        #If we have a speciation event we add two new species
        foreach ( 1, 2 ) {

            #Create a new species
            my $child = Bio::Phylo::Forest::Node->new();
            $child->set_name( 'ID' . $node_id++ );

            #Give it a zero edge length
            $child->set_branch_length(0);

            #Add it as a child to the speciating species
            $effected->set_child($child);

            #Add it to the tree
            $tree->insert($child);

            #Add it to the terminals list
            push( @terminals, $child );

            #New speciation rate
            my $new_speciation_rate = $effected_rate * $p;
            $p = 1 - $p;
            if ( $new_speciation_rate < 0 ) { $new_speciation_rate = 0; }
            push( @birth_rates, $new_speciation_rate );
        }

        #Windows sometimes returns 0 values for rand...
        my ( $r1, $r2 ) = ( 0, 0 );
        $r1 = rand until $r1;
        $tree_size = scalar @terminals;

        #If all species have stopped speciating (unlikely)
        if ( $net_rate == 0 ) {
            return $tree;
        }
        $next_speciation = -log($r1) / $net_rate / $tree_size;
        return $tree unless $tree_size;
    }
    return $tree;
}

=back

=cut

=begin comment

###########################################################
#INTERNAL METHODS
#These are methods that permit additional manipulations of 
#a Bio::Phylo::Tree to be easily made. As such some of
#these could easily be moved into Bio::Phylo::Forest::Tree
###########################################################

=end comment

=cut 

=begin comment

 Type    : Internal method
 Title   : copy_tree
 Usage   : $tree = copy_tree($tree)
 Function: Makes a new independent copy of a tree
 Returns : the phylogenetic $tree
 Args    : the phylogenetic $tree

=end comment

=cut 

sub copy_tree {
    return Bio::Phylo::IO->parse(
        -format => 'newick',
        -string => shift->to_newick( '-nodelabels' => 1 )
    )->first;
}

=begin comment

 Type    : Internal method
 Title   : truncate_tree_time
 Usage   : truncate_tree_time($tree,$age)
 Function: Truncates the tree at the specified age
 Returns : N/A
 Args    : $tree: the phylogenetic tree (which will be modified)
           $age: the age at which to cut the $tree

=end comment

=cut 

sub truncate_tree_time {

    #$node and $time are used only by this function recursively
    my ( $tree, $age, $node, $time ) = @_;

    #If node and time weren't specified we are starting from the root
    $node = $tree->get_root unless defined $node;
    $time = 0 unless defined $time;

    #If we are truncating this branch
    if ( $time + $node->get_branch_length >= $age ) {

        #Collapse the node unless it is terminal
        $node->collapse unless $node->is_terminal();

        #Set the branch length appropriately
        $node->set_branch_length( $age - $time );
        return;
    }

    #If this node has no children we are done
    return if $node->is_terminal();

    #Call the function recursively on the children
    foreach ( @{ $node->get_children } ) {
        truncate_tree_time( $tree, $age, $_,
            $time + $node->get_branch_length() );
    }
}

=begin comment

 Type    : Internal method
 Title   : truncate_tree_size
 Usage   : truncate_tree_size($tree,$size)
 Function: Truncates the tree to the specified number of species
 Returns : N/A
 Args    : $tree: the phylogenetic tree (which will be modified)
           $size: random species are delete so that the tree has this many terminals

=end comment

=cut 

sub truncate_tree_size {
    my ( $tree, $size ) = @_;
    my @terminals = @{ $tree->get_terminals };
    my @names;

    #Calculate the tree height and node distances from the root
    #much more efficient to do this in one hit than repeatedly
    #calling the analogous functions on the tree
    _calc_node_properties($tree);

    #Only push species that are extant and store the number of those
    #    my $tree_height = $tree->get_tallest_tip->calc_path_to_root;
    my $tree_height = $tree->get_root->get_generic('tree_height');
    foreach (@terminals) {
        if (
            abs(
                ( $_->get_generic('root_distance') - $tree_height ) /
                  $tree_height
            ) < 1e-6
          )
        {
            push( @names, $_->get_name );
        }
    }
    if ( @names < $size ) { print "Internal error\n"; }
    my %deletions;
    while ( scalar( keys %deletions ) < @names - $size ) {
        $deletions{ $names[ int( rand(@names) ) ] } = 1;
    }
    $tree = prune_tips( $tree, [ keys %deletions ] );
    return $tree;
}

sub _get_ultrametric_size {
    my ( $tree, $size ) = @_;
    my @terminals = @{ $tree->get_terminals };
    _calc_node_properties($tree);
    my @names;
    my $tree_height = $tree->get_root->get_generic('tree_height');
    foreach (@terminals) {
        if (
            abs(
                ( $_->get_generic('root_distance') - $tree_height ) /
                  $tree_height
            ) < 1e-6
          )
        {
            push( @names, $_->get_name );
        }
    }
    return scalar @names;
}

=begin comment

 Type    : Internal method
 Title   : remove_extinct_species
 Usage   : remove_extinct_species($tree)
 Function: Removes extinct species from the tree. An extinct species
           is a terminal that does not extend as far as the furthest
           terminal(s).
 Returns : N/A
 Args    : $tree: the phylogenetic tree (which will be modified)
           $age: the age at which to cut the $tree

=end comment

=cut 

sub remove_extinct_species {
    my $tree = shift;

    #Calculate the tree height and node distances from the root
    #much more efficient to do this in one hit than repeatedly
    #calling the analogous functions on the tree
    _calc_node_properties($tree);
    my $height = $tree->get_root->get_generic('tree_height');
    return unless $height > 0;
    my $leaves = $tree->get_terminals;
    return unless $leaves;
    my @remove;
    foreach ( @{$leaves} ) {

        unless (
            abs( ( $_->get_generic('root_distance') - $height ) / $height ) <
            1e-6 )
        {
            push( @remove, $_->get_name );
        }
    }
    $tree = prune_tips( $tree, \@remove );
    return $tree;
}

=begin comment

 Type    : Internal method
 Title   : prune_tips
 Usage   : prune_tips($tree,$tips)
 Function: Removes named terminals from the tree
 Returns : N/A
 Args    : $tree: the phylogenetic tree (which will be modified)
           $tips: array ref of terminals to remove from the tree

NB: Available as $tree->prune_tips($tips), but had some problems with
this. 

=end comment

=cut 

sub prune_tips {
    my ( $self, $tips ) = @_;
    my %names_to_delete = map { $_           => 1 } @{$tips};
    my %keep            = map { $_->get_name => 1 }
      grep { not exists $names_to_delete{ $_->get_name } }
      @{ $self->get_terminals };
    $self->visit_depth_first(
        -post => sub {
            my $node = shift;
            if ( $node->is_terminal ) {
                if ( not $keep{ $node->get_name } ) {
                    $node->set_parent();
                    $self->delete($node);
                }
            }
            else {
                my $seen_tip_to_keep = 0;
                for my $tip ( @{ $node->get_terminals } ) {
                    $seen_tip_to_keep++ if $keep{ $tip->get_name };
                }
                if ( not $seen_tip_to_keep ) {
                    $node->set_parent();
                    $self->delete($node);
                }
            }
        }
    );
    $self->remove_unbranched_internals;
    return $self;
}

=begin comment

 Type    : Internal method
 Title   : lineage_through_time
 Usage   : ($time,$count) = lineage_through_time($tree)
 Function: Alternative to $tree->ltt that permits extinctions
 Returns : $time: array ref of times
           $count: array ref of species counts corresponding to the times
 Args    : the phylogenetic $tree for which to produce the ltt data

=end comment

=cut 

sub lineage_through_time {
    my $tree = shift;
    my ( $speciation, $extinction ) = _recursive_ltt_helper($tree);
    my @speciation = sort { $a <=> $b } @{$speciation};
    my @extinction = sort { $a <=> $b } @{$extinction};
    my @time       = (0);
    my @count      = (1);
    my $n_species  = 1;
    my $end_time = max( @speciation, @extinction );
    return ( [], [] ) if ( $end_time == 0 );

#We remove any extinction events occurring at the very end of the tree (as they are not real extinctions)
    while ( scalar @extinction
        && ( $end_time - $extinction[-1] ) / $end_time < 1e-6 )
    {
        pop @extinction;
    }
    while ( scalar @speciation || scalar @extinction ) {
        if ( scalar @extinction == 0
            || ( scalar @speciation && $speciation[0] < $extinction[0] ) )
        {
            push( @count, ++$n_species );
            push( @time,  shift(@speciation) );
        }
        else {
            push( @count, --$n_species );
            push( @time,  shift(@extinction) );
        }
    }
    return ( \@time, \@count );
}

=begin comment

 Type    : Internal method
 Title   : _recursive_ltt_helper
 Usage   : ($speciation, $extinction) = _recursive_ltt_helper($tree)
 Function: Helper for lineage_through_time
 Returns : $speciation: array ref of speciation times
           $extinction: array ref of extinction times
 Args    : the phylogenetic $tree for which to produce the ltt data

=end comment

=cut 

sub _recursive_ltt_helper {
    my ( $tree, $node, $time ) = @_;

    #If we are being invoked at the root level
    $node = $tree->get_root unless defined $node;
    $time = 0 unless defined $time;

    #The new time
    $time += $node->get_branch_length;
    return ( [], [$time] ) if ( $node->is_terminal );
    my @speciation;
    my @extinction;
    foreach ( @{ $node->get_children } ) {
        my ( $spec, $ext ) = _recursive_ltt_helper( $tree, $_, $time );
        @speciation = ( @speciation, @{$spec} );
        @extinction = ( @extinction, @{$ext} );
    }
    push( @speciation, $time );
    return ( \@speciation, \@extinction );
}

=begin comment

 Type    : Internal method.
 Title   : _calc_node_properties
 Usage   : _calc_node_properties($tree);
 Function: Calculates the distance of nodes from the root 
 Returns : The maximum distance from the root
 Args    :

=end comment

=cut

sub _calc_node_properties {
    my ( $node, $root_distance );
    my $tree = shift;
    my $root = $tree->get_root;

    #Check whether we were given a node and distance
    if ( scalar @_ ) {
        $node          = shift;
        $root_distance = shift;

        #Otherwise the root is the default
    }
    else {
        $node = $root;
        $root->set_generic( tree_height => 0 );
        $root_distance = 0;
    }
    $node->set_generic( root_distance => $root_distance );
    if ( $root_distance > $root->get_generic('tree_height') ) {
        $root->set_generic( tree_height => $root_distance );
    }
    my $terminal_count = 0;
    my $children       = $node->get_children;
    if ( defined $children ) {
        foreach ( @{$children} ) {
            _calc_node_properties( $tree, $_,
                $root_distance + $_->get_branch_length() );
        }
    }
}

=begin comment

 Type    : Internal method
 Title   : nchoosek
 Usage   : $out = nchoosek($n,$k)
 Function: Returns the binomial coefficient for $n and $k
 Returns : the binomial coefficient
 Args    : $n, $k

=end comment

=cut 

sub nchoosek {
    my ( $n, $k ) = @_;
    my $r = 1;
    return 0 if ( $k > $n || $k < 0 );
    for ( my $d = 1 ; $d <= $k ; $d++ ) {
        $r *= $n--;
        $r /= $d;
    }
    return $r;
}
1;
