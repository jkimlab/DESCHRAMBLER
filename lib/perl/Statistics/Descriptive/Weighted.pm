package Statistics::Descriptive::Weighted;
$VERSION = '0.5';
use Statistics::Descriptive;
use Data::Dumper;

package Statistics::Descriptive::Weighted::Sparse;
use strict;
use vars qw($AUTOLOAD @ISA %fields);

@ISA = qw(Statistics::Descriptive::Sparse);

use Carp qw(cluck confess);

##Define a new field to be used as method, to
##augment the ones inherited
%fields = (
	   weight                    => 0,
	   sum_squares               => 0,
	   weight_homozyg            => 0,
	   biased_variance           => 0,
	   biased_standard_deviation => 0,
  );

__PACKAGE__->_make_accessors( [ grep { $_ ne "weight" } keys(%fields) ] );
__PACKAGE__->_make_private_accessors(["weight"]);

##Have to override the base method to add new fields to the object
##The proxy method from base class is still valid
sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = $class->SUPER::new();  ##Create my self re SUPER
  @{ $self->{'_permitted'} } {keys %fields} = values %fields;
  @{ $self } {keys %fields} = values %fields;
  bless ($self, $class);  #Re-anneal the object
  return $self;
}

sub add_data {
  my $self = shift;  ##Myself
  my $oldmean;
  my $oldweight;
  my ($min,$max);
  my $aref;

  if ( (not ref $_[0] eq 'ARRAY') || (exists $_[1] and (not (ref $_[1] eq 'ARRAY') || @{$_[0]} != @{$_[1]} ) ) ) {
    cluck "WARNING: Expected input are two references to two arrays of equal length; first data, then positive weights. Second array is optional.\n";
    return undef;
  }

  my ($datum,$weight) = @_;

  ##Calculate new mean, pseudo-variance, min and max;
  ##The on-line weighted incremental algorithm for variance is based on West 1979 from Wikipedia
  ##D. H. D. West (1979). Communications of the ACM, 22, 9, 532-535: Updating Mean and Variance Estimates: An Improved Method

  ## NEW in Version 0.4:
  ## I calculate a sample weighted variance based on normalized weights rather than the sample size 
  ## correction factor is: 1 / (1 - sum [w_i / (sum w_i) ]^2)

  ## call H = sum [w_i / (sum w_i) ]^2. An online update eq for H is  H_new =  (sum.w_old^2 * H_old) + weight^2) / sum.w^2

  ## correction factor is then 1 / (1 - H_new)

  my $weighterror;
  for (0..$#$datum ) {
    if (not defined $$weight[$_]) {
      $$weight[$_] = 1;
    }
    if ($$weight[$_] <= 0) {
      $weighterror = 1;
      next;
    }
    $oldmean = $self->{mean};
    $oldweight = $self->{weight};
    $self->{weight} += $$weight[$_];
    $self->{weight_homozyg} = ((($oldweight ** 2 * $self->{weight_homozyg}) + $$weight[$_] ** 2) / ( $self->{weight} ** 2 ));
    $self->{count}++;
    $self->{sum} += ($$weight[$_] * $$datum[$_]);
    $self->{mean} += (($$weight[$_] / $self->{weight} ) * ($$datum[$_] - $oldmean)); 
    $self->{sum_squares} += (($$weight[$_] / $self->{weight} ) * ($$datum[$_] - $oldmean) ** 2) * $oldweight;
    if (not defined $self->{max} or $$datum[$_] > $self->{max}) {
      $self->{max} = $$datum[$_];
    }
    if (not defined $self->{min} or $$datum[$_] < $self->{min}) {
      $self->{min} = $$datum[$_];
    }
  }
  cluck "WARNING: One or more data with nonpositive weights were skipped.\n" if ($weighterror);
  $self->{sample_range} = $self->{max} - $self->{min};
  if ($self->{count} > 1) {
    $self->{variance}     = ($self->{sum_squares} / ((1 - $self->{weight_homozyg}) * $self->{weight}));
    $self->{standard_deviation}  = sqrt( $self->{variance});
    $self->{biased_variance}     = ($self->{sum_squares} / $self->{weight});
    $self->{biased_standard_deviation}  = sqrt( $self->{biased_variance});
  }
  return 1;
}

sub weight {
  my $self = shift;
  if (@_ > 0) { 
    cluck "WARNING: Sparse statistics object expects zero arguments to weight function, returns sum of weights.";
  }
  return $self->_weight();
}

## OVERRIDES FOR UNSUPPORTED FUNCTIONS

sub mindex{
  confess "ERROR: Statistics::Descriptive::Weighted does not support this function.";
}

sub maxdex{
  confess "ERROR: Statistics::Descriptive::Weighted does not support this function.";
}

1;

package Statistics::Descriptive::Weighted::Full;

use Carp qw(cluck confess);
use Tree::Treap;
use strict;
use vars qw(@ISA %fields);

@ISA = qw(Statistics::Descriptive::Weighted::Sparse);

##Create a list of fields not to remove when data is updated
%fields = (
  _permitted => undef,  ##Place holder for the inherited key hash
  data       => undef,  ##keys from variate values to a hashref with keys weight, cdf, tail-prob
  did_cdf    => undef,  ##flag to indicate whether CDF/quantile fun has been computed or not
  quantile   => undef,  ##"hash" for quantile function
  percentile => undef,  ##"hash" for percentile function
  maxweight  => 0,
  mode       => undef,
  order      => 1,
  _reserved  => undef,  ##Place holder for this lookup hash
);

##Have to override the base method to add the data to the object
##The proxy method from above is still valid
sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = $class->SUPER::new();  ##Create my self re SUPER
  $self->{data}           = new Tree::Treap("num");  ## inserts data by numeric comparison
  $self->{did_cdf}        = 0;
  $self->{maxweight}      = 0;
  $self->{quantile}       = new Tree::Treap("num");
  $self->{percentile}     = new Tree::Treap("num");
  $self->{order}          = 1; 
  $self->{'_reserved'} = \%fields;
  bless ($self, $class);  
  return $self;
}

## The treap gives relatively fast search and good performance on possibly sorted data
## The choice is motivated by heavy intended use for Empirical Distribution Function
## A lot of work is done at insertion for faster computation on search
## THE ACTUAL DATA INSERTION IS DONE AT FUNCTION _addweight
## The data structure loses information. Like a hash keys appear only once.
## The value of a key is its sum of weight for that key, and the cumulative weight
sub add_data {
  my $self = shift;
  my $key;

  if ( (not ref $_[0] eq 'ARRAY') || (exists $_[1] and (not (ref $_[1] eq 'ARRAY') || @{$_[0]} != @{$_[1]} ) ) ) {
    cluck "WARNING: Expected input are two references to two arrays of equal length; first data, then positive weights. Second array is optional.\n";
    return undef;
  }

  my ($datum,$weight) = @_;
  my $filterdatum = [];
  my $filterweight = [];
  my $weighterror;
  my $newweight;
  for (0..$#$datum) {
    if (not defined $$weight[$_]) {
      $$weight[$_] = 1;
    }
    if ($$weight[$_] > 0) {
      push @$filterdatum,$$datum[$_];
      push @$filterweight,$$weight[$_];
      $newweight = $self->_addweight($$datum[$_], $$weight[$_]);
      if ($newweight > $self->{maxweight}) {
	$self->{maxweight} = $newweight;
	$self->{mode} = $$datum[$_];
      }
    }
    else {
      $weighterror = 1;
    }
  }
  cluck "WARNING: One or more data with nonpositive weights were skipped.\n" if ($weighterror);
  $self->SUPER::add_data($filterdatum,$filterweight);  ##Perform base statistics on the data
  ##Clear the did_cdf flag
  $self->{did_cdf} = 0;
  ##Need to delete all cached keys
  foreach $key (keys %{ $self }) { # Check each key in the object
    # If it's a reserved key for this class, keep it
    next if exists $self->{'_reserved'}->{$key};
    # If it comes from the base class, keep it
    next if exists $self->{'_permitted'}->{$key};
    delete $self->{$key};          # Delete the out of date cached key
  }
  return 1;
}

sub count {
  my $self = shift;
  if (@_ == 1) {  ##Inquire
    my $val = $self->{data}->get_val($_[0]);
    return (defined $val ? ${ $val }{'count'} : $val);
  }
  elsif (@_ == 0) {  ##Inquire
    return $self->{count};
  }
  else { 
    cluck "WARNING: Only 1 or fewer arguments expected.";
  }
  return 1;
}

sub weight {
  my $self = shift;
  if (@_ == 1) {  ##Inquire
    my $val = $self->{data}->get_val($_[0]);
    return (defined $val ? ${ $val }{'weight'} : $val);
  }
  elsif (@_ == 0) {  ##Inquire
    return $self->{weight};
  }
  else { 
    cluck "WARNING: Only 1 or fewer arguments expected.";
  }
  return 1;
}

sub _addweight {
  my $self = shift;
  my $oldweight = ($self->weight($_[0]) || 0);
  my $newweight = $_[1] + $oldweight;
  my $value = $self->{data}->get_val($_[0]);
  my $weights = ($value ? $$value{'weights'} : [] );
  push @$weights, $_[1]; 
  my $orders  = ($value ? $$value{'order'} : [] );
  push @$orders, $self->{order}++; 
  my $newcount  = ($self->count($_[0]) || 0) + 1;
  if (@_ == 2) {  ##Assign
    my $values = {'weight' => $newweight, 'weights' => $weights, 'count' => $newcount, 'order' => $orders, 'cdf' => undef, 'rt_tail_prob' => undef, 'percentile' => undef};
    $self->{data}->insert($_[0],$values);
  }
  else {
    cluck "WARNING: Only two arguments (key, addend) expected.";
  }
  return $newweight;
}

sub _do_cdf {
  my $self = shift;
  my $cumweight = 0;
  foreach my $key ($self->{data}->keys()){
    my $value = $self->{data}->get_val($key);
    my $keyweight = $self->weight($key); 

    my $oldcumweight = $cumweight;
    $cumweight += $keyweight;

    my $propcumweight = $cumweight / $self->{weight};
    my $right_tail_prob = (1 - ($oldcumweight /  $self->{weight}));
    my $percentile = ((100 / $self->{weight}) * ($cumweight - ($keyweight / 2)));

    $$value{'cdf'} = $propcumweight;
    $$value{'rt_tail_prob'} = $right_tail_prob;
    $$value{'percentile'} = $percentile;

    $self->{data}->insert($key,$value);
    $self->{quantile}->insert($propcumweight,$key);
    $self->{percentile}->insert($percentile,$key);
  }
  $self->{did_cdf} = 1;
  return 1;
}

sub quantile {
  my $self = shift;
  $self->_do_cdf() unless $self->{did_cdf};
  if (@_ == 1) {  ##Inquire
    my $proportion = shift;
    cluck "WARNING: Expects an argument between 0 and 1 inclusive." if ($proportion < 0 or $proportion > 1);
    my @keys = $self->{quantile}->range_keys($proportion, undef);
    my $key = $keys[0]; ## GET THE SMALLEST QUANTILE g.e. $proportion
    return $self->{quantile}->get_val($keys[0]);
  }
  else { 
    cluck "WARNING: Exactly 1 argument expected.";
    return undef;
  }
}

sub percentile {
  my $self = shift;
  $self->_do_cdf() unless $self->{did_cdf};
  if (@_ != 1) {
    cluck "WARNING: Exactly 1 argument expected.";
  }
  my $percent = shift;
  if ($percent < 0 or $percent > 100) {
    cluck "WARNING: Expects an argument between 0 and 100 inclusive.";
  }
  my $percentile;
  if ($percent < $self->{percentile}->minimum()) {
    $percentile = $self->{data}->minimum();
  } elsif ($percent > $self->{percentile}->maximum()) {
    $percentile = $self->{data}->maximum();
  } else {
    my @lekeys =  $self->{percentile}->range_keys(undef,$percent);
    my $lekey = $lekeys[-1];
    my @gekeys =  $self->{percentile}->range_keys($percent, undef);
    my $gekey = $gekeys[0];
    my $leval = $self->{percentile}->get_val($lekey);
    $percentile = $leval;
    if ($gekey != $lekey) {
      my $geval = $self->{percentile}->get_val($gekey);
      $percentile += ($percent - $lekey) / ($gekey - $lekey) * ($geval - $leval);
    }
  }
  return $percentile;
}


sub median {
  my $self = shift;

  ##Cached?
  return $self->{median} if defined $self->{median};
  return $self->{median} = $self->percentile(50);
}

sub mode {
  my $self = shift;
  return $self->{mode};
}

sub cdf {
  my $self = shift;
  $self->_do_cdf() unless $self->{did_cdf};
  if (@_ == 1) {  ##Inquire
    my $value = shift;
    return 0 if ($self->{data}->minimum() > $value);
    my @keys = $self->{data}->range_keys(undef, $value);
    my $key = $keys[-1]; ## GET THE LARGEST OBSERVED VALUE l.e. $value
    return ${ $self->{data}->get_val($key) }{'cdf'};
  }
  else { 
    cluck "WARNING: Exactly 1 argument expected.";
    return undef;
  }
}

sub survival {
  my $self = shift;
  $self->_do_cdf() unless $self->{did_cdf};
  if (@_ == 1) {  ##Inquire
    my $value = shift;
    return 1 if ($self->{data}->minimum() > $value);
    my @keys = $self->{data}->range_keys(undef, $value);
    my $key = $keys[-1]; ## GET THE LARGEST OBSERVED VALUE l.e. $value
    return 1 - (${ $self->{data}->get_val($key) }{'cdf'});
  }
  else { 
    cluck "WARNING: Only 1 argument expected.";
    return undef;
  }
}

sub rtp {
  my $self = shift;
  $self->_do_cdf() unless $self->{did_cdf};
  if (@_ == 1) {  ##Inquire
    my $value = shift;
    return 0 if ($self->{data}->maximum() < $value);
    my @keys = $self->{data}->range_keys($value, undef);
    my $key = $keys[0]; ## GET THE SMALLEST OBSERVED VALUE g.e. $value
    return ${ $self->{data}->get_val($key) }{'rt_tail_prob'};
  }
  else { 
    cluck "WARNING: Only 1 argument expected.";
    return undef;
  }
}

sub get_data {
  my $self = shift;
  $self->_do_cdf() unless $self->{did_cdf};
  my ($uniqkeys, $sumweights, $keys, $weights, $counts, $cdfs, $rtps, $percentiles, $order) = ([],[],[],[],[],[],[],[],[]);
  my $key = $self->{'data'}->minimum();
  while ($key){
    my $value = $self->{data}->get_val($key);
    push @$uniqkeys, $key;
    push @$sumweights, $$value{'weight'};
    foreach my $weight (@{ $$value{'weights'} } ) {
      push @$keys, $key;
      push @$weights, $weight;
    }
    push @$order, @{ $$value{'order'}}; 
    push @$counts, $$value{'count'};
    push @$cdfs,   $$value{'cdf'};
    push @$rtps,   $$value{'rt_tail_prob'};
    push @$percentiles,   $$value{'percentile'};
    $key = $self->{'data'}->successor($key);
  }
  return {'uniqvars' => $uniqkeys, 'sumweights' => $sumweights, 'counts' => $counts, 'cdfs' => $cdfs, 'rtps' => $rtps, 'vars' => $keys, 'weights' => $weights, 'percentiles' => $percentiles, 'order' => $order};
}

sub print {
  my $self = shift;
  print Data::Dumper->Dump([$self->get_data()]);
}

## OVERRIDES FOR UNSUPPORTED FUNCTIONS

sub sort_data{
  confess "ERROR: Statistics::Descriptive::Weighted does not support this function.";
}

sub presorted{
  confess "ERROR: Statistics::Descriptive::Weighted does not support this function.";
}

sub harmonic_mean{
  confess "ERROR: Statistics::Descriptive::Weighted does not support this function.";
}

sub geometric_mean{
  confess "ERROR: Statistics::Descriptive::Weighted does not support this function.";
}

sub trimmed_mean{
  confess "ERROR: Statistics::Descriptive::Weighted does not support this function.";
}

sub frequency_distribution{
  confess "ERROR: Statistics::Descriptive::Weighted does not support this function.";
}

sub least_squares_fit{
  confess "ERROR: Statistics::Descriptive::Weighted does not support this function.";
}


1;

package Statistics::Descriptive;

##All modules return true.
1;

__END__

=head1 NAME

Statistics::Descriptive::Weighted - Module of basic descriptive 
statistical functions for weighted variates.

=head1 SYNOPSIS

  use Statistics::Descriptive::Weighted;

  $stat  = Statistics::Descriptive::Weighted::Full->new();
  
  $stat->add_data([1,2,3,4],[0.1,1,10,100]); ## weights are in second argument
  $mean  = $stat->mean();                    ## weighted mean
  $var   = $stat->variance();                ## weighted sample variance (unbiased estimator)
  $var   = $stat->biased_variance();         ## weighted sample variance (biased)
  
  $stat->add_data([3],[10]);                 ## statistics are updated as variates are added
  $vwt   = $stat->weight(3);                 ## returns 20, the weight of 3
  $wt    = $stat->weight();                  ## returns sum of weights, 121.1
  $ct    = $stat->count(3);                  ## returns 2, the number of times 3 was observed
  $ct    = $stat->count();                   ## returns 5, the total number of observations

  $med   = $stat->median();                  ## weighted sample median
  $mode  = $stat->mode();                    ## returns 4, value with the most weight
  $ptl   = $stat->quantile(.01);             ## returns 3, smallest value with cdf >= 1st %ile 
  $ptl   = $stat->percentile(1);             ## returns about 2.06, obtained by interpolation
  $cdf   = $stat->cdf(3);                    ## returns ECDF of 3   (about 17.4%)
  $cdf   = $stat->cdf(3.5);                  ## returns ECDF of 3.5 (about 17.4%, same as ECDF of 3)
  $sf    = $stat->survival(3);               ## returns complement of ECDF(3)   (about 82.6%)
  $pval  = $stat->rtp(4);                    ## returns right tail probability of 4 (100 / 121.1, about 82.6%)

  $min  = $stat->min();                      ## returns 1, the minimum
  $max  = $stat->max();                      ## returns 4, the maximum

  $unweighted  = Statistics::Descriptive::Full->new();
  $weighted    = Statistics::Descriptive::Weighted::Full->new();

  $unweighted->add_data(1,1,1,1,7,7,7,7);
  $weighted->add_data([1,7],[4,4]);

  $ct = $unweighted->count();                ## returns 8 
  $ct = $weighted->count();                  ## returns 2 

  print "false, variances unequal!\n" unless 
         ( abs($unweighted->variance() - $weighted->variance()) < 1e-12 );
 
  ## the above statement will print, the variances are truly unequal
  ## the unweighted variance is corrected in terms of sample-size,
  ## while the weighted variance is corrected in terms of the sum of
  ## squared weights

  $data = $weighted->get_data();     

  ## the above statement returns a hashref with keys:
  ## 'vars','weights','uniqvars','counts','sumweights','cdfs','rtps','percentiles','order'

  $weighted->print();                 

  ## prints the hashref above with Data::Dumper

=head1 DESCRIPTION

This module partially extends the module Statistics::Descriptive to handle
weighted variates. Like that module, this module has an object-oriented
design and supports two different types of data storage and calculation
objects: sparse and full. With the sparse object representation, none of
the data is stored and only a few statistical measures are available. Using
the full object representation, complete information about the dataset
(including order of observation) is retained and additional functions are
available.

This module represents numbers in the same way Perl does on your
architecture, relying on Perl's own warnings and assertions regarding
underflow and overflow errors, division by zero, etc.  The constant
C<$Statistics::Descriptive::Tolerance> is not used. Caveat programmor.

Variance calculations, however, are designed to avoid numerical
problems. "Online" (running sums) approaches are used to avoid
catastrophic cancellation and other problems. New in versions 0.4 and
up, I have corrected the definition of the "variance" and
"standard_deviation" functions to standard definitions. This module
now models the same calculation as eg the "corpcor" package in R for
weighted sample variance. Following convention from
Statistics::Descriptive, "variance" and "standard_deviation" return
B<unbiased> "sample" estimators. Also new in v0.4, I now provide
"biased_variance" and "biased_standard_deviation" functions to return
the biased estimators. Please see below for full definitions.

Like in Statistics::Descriptive any of the methods (both Sparse and
Full) cache values so that subsequent calls with the same arguments
are faster.

Be warned that this is B<not> a drop-in replacement for
Statistics::Descriptive. The interfaces are different for adding data,
and also for retrieving data with get_data. Certain functions from
Statistics::Descriptive have been dropped, specifically:

=over 

=item Statistics::Descriptive::Sparse::mindex()

=item Statistics::Descriptive::Sparse::maxdex()

=item Statistics::Descriptive::Full::sort_data()

=item Statistics::Descriptive::Full::presorted()

=item Statistics::Descriptive::Full::harmonic_mean()

=item Statistics::Descriptive::Full::geometric_mean()

=item Statistics::Descriptive::Full::trimmed_mean()

=item Statistics::Descriptive::Full::frequency_distribution()

=item Statistics::Descriptive::Full::least_squares_fit()

=back

Calling these functions on Statistics::Descriptive::Weighted objects
will cause programs to die with a stack backtrace.

With this module you can recover the data sorted from get_data(). Data
is sorted automatically on insertion. 

The main extension and focus of this module was to implement a cumulative
distribution function and a right-tail probability function with efficient
search performance, even if the data added is already sorted. This is
achieved using a partially randomized self-balancing tree to store data.
The implementation uses Tree::Treap v. 0.02 written by Andrew Johnson.

=head1 METHODS

=head2 Sparse Methods

=over 

=item $stat = Statistics::Descriptive::Weighted::Sparse->new();

Create a new sparse statistics object.

=item $stat->add_data([1,2,3],[11,9,2]);

Adds data to the statistics object. The cached statistical values are
updated automatically.

This function expects one or two array references: the first points to
variates and the second to their corresponding weights. The referenced
arrays must be of equal lengths. The weights are expected to all be
positive. If any weights are not positive, the module will carp
(complain to standard error) and the corresponding variates will be
skipped over. 

If the weights array is omitted, all weights for the values added are
assumed to be 1.

Variates may be added in multiple instances to Statistics objects, and
their summaries are calculated "on-line," that is updated.

=item $stat->count();

Returns the number of variates that have been added.

=item $stat->weight();

Returns the sum of the weight of the variates.

=item $stat->sum();

Returns the sum of the variates multiplied by their weights.

=item $stat->mean();

Returns the weighted mean of the data. This is the sum of the weighted
data divided by the sum of weights.

=item $stat->variance();

Returns the unbiased weighted sample variance of the data. An
"on-line" weighted incremental algorithm for variance is based on
D. H. D. West (1979). Communications of the ACM, 22, 9, 532-535:
Updating Mean and Variance Estimates: An Improved Method. However,
instead of dividing by (n-1) as in that paper, the bias correction
used is:

=over

1 / (1 - (sum_i ((w_i)^2) / (sum_i w_i)^2)),

=back

where w_i is the ith weight. This bias correction factor multiplies
the biased estimator of the variance defined below.

=item $stat->standard_deviation();

Returns the square root of the unbiased weighted sample variance of the data.

=item $stat->biased_variance();

Returns the biased weighted sample variance of the data. The same
"on-line" weighted incremental algorithm for variance is used. The
definition of the biased weighted variance estimator is:

=over

sum_i (w_i * (x_i - mean_x)^2) / sum_i (w_i),

=back

where w_i is the weight of the ith variate x_i, and mean_x is the
weighted mean of the variates. To reproduce the variance calculation
of earlier versions of this module, multiple the biased variance by
($stat->count() / ($stat->count() - 1)).

=item $stat->biased_standard_deviation();

Returns the square root of the unbiased weighted sample variance of the data.

=item $stat->min();

Returns the minimum value of the data set.

=item $stat->max();

Returns the maximum value of the data set.

=item $stat->sample_range();

Returns the sample range (max - min) of the data set.

=back

=head2 Full Methods

Similar to the Sparse Methods above, any Full Method that is called caches
the current result so that it doesn't have to be recalculated.  

=over 

=item $stat = Statistics::Descriptive::Weighted::Full->new();

Create a new statistics object that inherits from
Statistics::Descriptive::Sparse so that it contains all the methods
described above.

=item $stat->add_data([1,2,4,5],[2,2,2,5]);

Adds weighted data to the statistics object. All of the sparse
statistical values are updated and cached. Cached values from Full
methods are deleted since they are no longer valid.

I<Note:  Calling add_data with an empty array will delete all of your
Full method cached values!  Cached values for the sparse methods are
not changed>

=item $stat->mode();

Returns the data value with the most weight. In the case that a data
value is observed multiple times, their successive weights are summed
of course.

=item $stat->maxweight();

The weight of the mode.

=item $stat->count(10);

The number of observations of a particular data value.

=item $stat->weight(10);

The total weight of a particular data value.

=item $x = $stat->cdf(4);

Returns the weighted empirical cumulative distribution function (ECDF).

=over 

=item

For example, given the 6 measurements:

-2, 7, 7, 4, 18, -5

with weights: 

2, 1, 1, 2, 2, 2

Let F(x) be the ECDF of x, which is defined as the sum of all
normalized weights of all observed variates less than or equal to x.

Then F(-8) = 0, F(-5.0001) = 0, F(-5) = 1/5, F(-4.999) = 1/5, F(7) =
4/5, F(18) = 1, F(239) = 1.

Note that we can recover the different measured values and how many
times each occurred from F(x) -- no information regarding the range
in values is lost.  Summarizing measurements using histograms, on the
other hand, in general loses information about the different values
observed, so the EDF is preferred.

Using either the EDF or a histogram, however, we do lose information
regarding the order in which the values were observed.  Whether this
loss is potentially significant will depend on the metric being
measured.

=back

(Modified from: pod from Statistics::Descriptive, itself taken from
I<RFC2330 - Framework for IP Performance Metrics>, Section 11.3.
Defining Statistical Distributions.  RFC2330 is available from:
http://www.cis.ohio-state.edu/htbin/rfc/rfc2330.html.)

=item $x = $stat->survival(8);

Complement of the weighted cdf function, also known as the weighted
survival function.  The weighted survival function S(x) is the sum of
all normalized weights of all observed variates greater than x.

=over 

=item

For example, given the 6 measurements:

-2, 7, 7, 4, 18, -5

with weights: 

2, 1, 1, 2, 2, 2

Then S(-8) = 1, S(-5.0001) = 1, S(-5) = 4/5, S(-4.999) = 4/5, S(7) =
1/5, S(18) = 0, S(239) = 0.

=back

=item $x = $stat->rtp(8);

The weighted right tail probability function. The weighted right tail
probability function P(x) is the sum of all normalized weights of all
observed variates greater than or equal to x. This may be useful for
Monte Carlo estimation of P-values.

=over 4

=item

For example, given the 6 measurements:

-2, 7, 7, 4, 18, -5

with weights: 

2, 1, 1, 2, 2, 2

Then P(-8) = 1, P(-5.0001) = 1, P(-5) = 1, P(-4.999) = 4/5, P(7) =
2/5, P(18) = 1/5, P(239) = 0.

=back

=item $x = $stat->quantile(0.25);

Returns the weighted quantile. This is the inverse of the weighted
ECDF function. It is only defined for arguments between 0 and 1
inclusively. If F(x) is the ECDF, then the weighted quantile function
G(y) returns the smallest variate x whose weighted ECDF F(x) is
greater than or equal to y.

=over 

=item

For example, given the 6 measurements:

-2, 7, 7, 4, 18, -5

with weights: 

2, 1, 1, 2, 2, 2

Then G(0) = -5, G(0.1) = -5, G(0.2) = -5, G(0.25) = -2, G(0.4) = -2,
G(0.8) = 7, G(1) = 18.

=back

=item $x = $stat->percentile(25);

Returns the weighted percentile. It is only defined for arguments
between 0 and 100 inclusively. Unlike the quantile function above, the
percentile function performs weighted linear interpolation between
variates unless the argument exactly equals the computed percentile of
one of the variates.

=over 

=item

Define p_n to be the percentile of the nth sorted variate, written
v_n, like so:

p_n = 100/S_N * (S_n - (w_n / 2)), 

where S_N is the sum of all weights, S_n is the partial sum of weights
up to and including the nth variate, and w_n is the weight of the nth
variate.

Given a percent value 0 <= y <= 100, find an integer k such that: 

p_k <= y <= p_(k+1).

The percentile function P(y) may now be defined:

P(y) = v_k + {[(y - p_k) / (p_(k+1) - p_k)] * (v_(k+1) - v_k)}

=back

This definition of weighted percentile was taken from:
http://en.wikipedia.org/wiki/Percentile on Dec 15, 2008.

=item $stat->median();

This is calculated as $stat->percentile(50) and cached as necessary.

=item $stat->get_data();

Returns a data structure that reconstitutes the original data added to
the object, supplemented by some of the distributional
summaries. Returns a reference to a hash, with the following keys,
each pointing to a reference to an array containing the indicated data.

=over

=item vars

The observed variates, sorted.

=item weights

The weights of the variates (in corresponding order to the value of
'vars').

=item order

The order of addition of the variates (in corresponding order to the value of
'vars').

=item uniqvars 

The uniquely observed variates, sorted.

=item counts 

The numbers of times each variate was observed (in corresponding order
to the value of 'uniqvars').

=item sumweights 

The total weight of each unique variate (in corresponding order
to the value of 'uniqvars').

=item cdfs 

The cdf of each unique variate (in corresponding order to the value of
'uniqvars').

=item rtps

The rt tail probabilities of each unique variate (in corresponding
order to the value of 'uniqvars').

=item percentiles

The percentiles of each unique variate (see "percentile" above for
definition, given in corresponding order to the value of 'uniqvars').

=back

=item $stat->print();

Prints a Data::Dumper dump of the hashref returned by get_data().

=back

=head1 REPORTING ERRORS

When reporting errors, please include the following to help me out:

=over 

=item *

Your version of perl.  This can be obtained by typing perl C<-v> at
the command line.

=item *

Which versions of Statistics::Descriptive and
Statistics::Descriptive::Weighted you're using.

=item *

Details about what the error is.  Try to narrow down the scope
of the problem and send me code that I can run to verify and
track it down.

=back

=head1 NOTES

I use a running sum approach for the bias correction factor. We may
write this factor as (1 / (1 - H)), 

where 

=over

H is 1 / (1 - (sum_i ((w_i)^2) / (sum_i w_i)^2)). 

=back

The calculation I use for calculation of the (n+1)th value of H, on
encountering the (n+1)th variate is:

=over

H_(n+1) =  (sum_i^n w_i)^2 * H_n + w_(n+1)^2) / (sum_i^(n+1) w_i)^2

=back

together with initial value:

=over

H_0 = 0.

=back

=head1 AUTHOR

David H. Ardell

dhard@cpan.org (or just ask Google).

=head1 THANKS

Florent Angly

who contributed bug fixes, added features and tests, and improved
installation statistics (Oct 2009).

=head1 REFERENCES

=over

=item * 

RFC2330, Framework for IP Performance Metrics

=item * 

L<http://en.wikipedia.org/wiki/Percentile>

=item * 

L<http://en.wikipedia.org/wiki/Weighted_mean>

=item * 

L<http://en.wikipedia.org/wiki/Weighted_variance>

=item * 

D. H. D. West (1979). Communications of the ACM, 22, 9, 532-535:
Updating Mean and Variance Estimates: An Improved Method.

=item * 

L<http://en.wikipedia.org/wiki/Treap>

=item * 

Tree::Treap Copyright 2002-2005 Andrew Johnson. L<http://stuff.siaris.net>

=back

=head1 COPYRIGHT

Copyright (c) 2008,2009 David H. Ardell. 

Copyright (c) 2009 Florent Angly.

This program is free software; you may redistribute it and/or modify it
under the same terms as Perl itself.

Portions of this code are from Statistics::Descriptive which is under
the following copyrights.

Copyright (c) 1997,1998 Colin Kuskie. All rights 
reserved.  This
program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

Copyright (c) 1998 Andrea Spinelli. All rights 
reserved.  This program
is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

Copyright (c) 1994,1995 Jason Kastner. All rights 
reserved.  This
program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=head1 REVISION HISTORY

=over

=item v.0.5

October 2009. Fixed installation/test errors. Weights array made optional.

=item v.0.4

January 2009. Redefinition of variance and standard_deviation to
standard definitions; introduction of biased_variance,
biased_standard_deviation functions

=item v.0.2-v.0.3

December 2008. Corrections made to installation package.

=item v.0.1

December 2008. Initial release under perl licensing.

=back

=cut
