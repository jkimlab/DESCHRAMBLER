package Bio::Phylo::Models::Substitution::Dna;
use Bio::Phylo::Util::CONSTANT qw'/looks_like/ :objecttypes';
use Bio::Phylo::Util::Exceptions qw'throw';
use Bio::Phylo::IO qw(parse unparse);
use Bio::Phylo::Util::Logger':levels';
use File::Temp qw(tempfile cleanup);

use strict;
use warnings;

sub _INDEX_OF_ { { A => 0, C => 1, G => 2, T => 3 } }
sub _BASE_AT_ { [qw(A C G T)] }

my $logger = Bio::Phylo::Util::Logger->new;

=head1 NAME

Bio::Phylo::Models::Substitution::Dna - DNA substitution model

=head1 SYNOPSIS

    use Bio::Phylo::Models::Substitution::Dna;

    # create a DNA substitution model from scratch
    my $model = Bio::Phylo::Models::Substitution::Dna->new(
        '-type'   => 'GTR',
        '-pi'     => [ 0.23, 0.27, 0.24, 0.26 ],
        '-kappa'  => 2,
        '-alpha'  => 0.9,
        '-pinvar' => 0.5,
        '-ncat'   => 6,
        '-median' => 1,
        '-rate'   => [
            [ 0.23, 0.23, 0.23, 0.23 ],
            [ 0.23, 0.26, 0.26, 0.26 ],
            [ 0.27, 0.26, 0.26, 0.26 ],
            [ 0.24, 0.26, 0.26, 0.26 ]
        ]
    );

    # get substitution rate from A to C
    my $rate = $model->get_rate('A', 'C');

    # get model representation that can be used by Garli
    my $modelstr = $model->to_string( '-format' => 'garli' )

=head1 DESCRIPTION

This is a superclass for models of DNA evolution. Classes that inherit from this
class provide methods for retreiving general parameters such as substitution rates
or the number of states as well as model-specific parameters. Currently most of the
popular models are implemented. The static function C<modeltest> determines the
substitution model from a L<Bio::Phylo::Matrices::Matrix> object and returns the
appropriate instance of the subclass. This class also provides serialization
of a model to standard phylogenetics file formats.

=head1 METHODS

=head2 CONSTRUCTOR

=over

=item new

Dna model constructor.

 Type    : Constructor
 Title   : new
 Usage   : my $model = Bio::Phylo::Models::Substitution::Dna->new(%args);
 Function: Instantiates a Bio::Phylo::Models::Substitution::Dna object.
 Returns : A Bio::Phylo::Models::Substitution::Dna object.
 Args    : Optional:
		   -type       => type of model, one of GTR, F81, HKY85, JC69, K80
		   -pi         => base frequencies of bases A, C, G, T
		   -kappa      => ratio transitions/transversions
		   -alpha      => shape parameter (for models of GTR family)
		   -mu         => overall mutation rate
		   -pinvar     => proportion of invariant sites
		   -ncat       => number of distinct rate categories
		   -median     => median for gamma-modeled rate categories
		   -rate       => Array of Arrays (4x4) giving substitution rates betwen A, C, T, G
		   -catweights => weights for rate categories
=cut

sub new {
    my $class = shift;
    my %args  = looks_like_hash @_;
    $class .= '::' . uc $args{'-type'} if $args{'-type'};
    delete $args{'-type'};
    my $self = {};
    bless $self, looks_like_class $class;
    while ( my ( $key, $value ) = each %args ) {
        $key =~ s/^-/set_/;
        $self->$key($value);
    }
    return $self;
}

=item get_catrates

Getter for rate categories, implemented by child classes.

 Type    : method
 Title   : get_catrates
 Usage   : $model->get_catrates;
 Function: Getter for rate categories.
 Returns : scalar or array
 Args    : None.

=cut

sub get_catrates {
    throw 'NotImplemented' => 'FIXME';
}

=item get_nst

Getter for number of transition rate parameters.

 Type    : method
 Title   : get_nst
 Usage   : $model->get_nst;
 Function: Getter for number of transition rate parameters.
 Returns : scalar
 Args    : None.

=cut

sub get_nst { 6 }

=item get_rate

Getter for substitution rate. If bases are given as arguments,
returns corresponding rate. If no arguments given, returns rate matrix or
overall rate, dependent on model.

 Type    : method
 Title   : get_rate
 Usage   : $model->get_rate('A', 'C');
 Function: Getter for transition rate between nucleotides.
 Returns : scalar or array
 Args    : Optional:
           base1: scalar
           base2: scalar
=cut

sub get_rate {
    my $self = shift;
    if (@_) {
        my $src    = _INDEX_OF_()->{ uc shift };
        my $target = _INDEX_OF_()->{ uc shift };
        $self->{'_rate'} = [] if not $self->{'_rate'};
        if ( not $self->{'_rate'}->[$src] ) {
            $self->{'_rate'}->[$src] = [];
        }
        return $self->{'_rate'}->[$src]->[$target];
    }
    else {
        return $self->{'_rate'};
    }
}

=item get_nstates

Getter for number of states (bases).

 Type    : method
 Title   : get_nstates
 Usage   : $model->get_nstates;
 Function: Getter for transition rate between nucleotides.
 Returns : scalar
 Args    : None

=cut

sub get_nstates {
    my $states = _BASE_AT_;
    return scalar @{ $states };
}

=item get_ncat

Getter for number of rate categories.

 Type    : method
 Title   : get_ncat
 Usage   : $model->get_ncat;
 Function: Getter for number of rate categories.
 Returns : scalar
 Args    : None

=cut

sub get_ncat { shift->{'_ncat'} }

=item get_catweights

Getter for weights on rate categories.

 Type    : method
 Title   : get_catweights
 Usage   : $model->get_catweights;
 Function: Getter for number of rate categories.
 Returns : array
 Args    : None

=cut

sub get_catweights { shift->{'_catweights'} }

=item get_kappa

Getter for transition/transversion ratio.

 Type    : method
 Title   : get_kappa
 Usage   : $model->get_kappa;
 Function: Getter for transition/transversion ratio.
 Returns : scalar
 Args    : None

=cut

sub get_kappa { shift->{'_kappa'} }

=item get_alpha

Getter for shape parameter.

 Type    : method
 Title   : get_alpha
 Usage   : $model->get_alpha;
 Function: Getter for shape parameter.
 Returns : scalar
 Args    : None

=cut

sub get_alpha { shift->{'_alpha'} }

=item get_mu

Getter for overall mutation rate.

 Type    : method
 Title   : get_mu
 Usage   : $model->get_mu;
 Function: Getter for overall mutation rate.
 Returns : scalar
 Args    : None

=cut

sub get_mu { shift->{'_mu'} }

=item get_pinvar

Getter for proportion of invariant sites.

 Type    : method
 Title   : get_pinvar
 Usage   : $model->get_pinvar;
 Function: Getter for proportion of invariant sites.
 Returns : scalar
 Args    : None

=cut

sub get_pinvar { shift->{'_pinvar'} }

=item get_pi

Getter for base frequencies.

 Type    : method
 Title   : get_pi
 Usage   : $model->get_pi;
 Function: Getter for base frequencies.
 Returns : array
 Args    : Optional:
           Base (A, C, T or G)

=cut

sub get_pi {
    my $self = shift;
    $self->{'_pi'} = [] if not $self->{'_pi'};
    if (@_) {
        my $base = uc shift;
        return $self->{'_pi'}->[ _INDEX_OF_()->{$base} ];
    }
    else {
        return $self->{'_pi'};
    }
}

=item get_median

Getter for median for gamma-modeled rate categories.

 Type    : method
 Title   : get_median
 Usage   : $model->get_median;
 Function: Getter for median.
 Returns : scalar
 Args    : None

=cut

sub get_median { shift->{'_median'} }

=item set_rate

Setter for substitution rate.

 Type    : method
 Title   : set_rate
 Usage   : $model->set_rate(1);
 Function: Set nucleotide transition rates.
 Returns : A Bio::Phylo::Models::Substitution::Dna object.
 Args    : scalar or array of arrays (4x4)

=cut

sub set_rate {
    my ( $self, $q ) = @_;
    ref $q eq 'ARRAY' or throw 'BadArgs' => 'Not an array ref!';
    scalar @{$q} == 4 or throw 'BadArgs' => 'Q matrix must be 4 x 4';
    for my $row ( @{$q} ) {
        scalar @{$row} == 4 or throw 'BadArgs' => 'Q matrix must be 4 x 4';
    }
    $self->{'_rate'} = $q;
    return $self;
}

=item set_ncat

Setter for number of rate categories.

 Type    : method
 Title   : set_ncat
 Usage   : $model->set_ncat(6);
 Function: Set the number of rate categoeries.
 Returns : A Bio::Phylo::Models::Substitution::Dna object.
 Args    : scalar

=cut

sub set_ncat {
    my $self = shift;
    $self->{'_ncat'} = shift;
    return $self;
}

=item set_catweights

Setter for weights on rate categories.

 Type    : method
 Title   : set_catweights
 Usage   : $model->get_catweights;
 Function: Set number of rate categories.
 Returns : A Bio::Phylo::Models::Substitution::Dna object.
 Args    : array

=cut

sub set_catweights {
    my $self = shift;
    $self->{'_catweights'} = shift;
    return $self;
}

=item set_kappa

Setter for weights on rate categories.

 Type    : method
 Title   : set_kappa
 Usage   : $model->set_kappa(2);
 Function: Set transition/transversion ratio.
 Returns : A Bio::Phylo::Models::Substitution::Dna object.
 Args    : scalar

=cut

sub set_kappa {
    my $self = shift;
    $self->{'_kappa'} = shift;
    return $self;
}

=item set_alpha

Setter for shape parameter.

 Type    : method
 Title   : set_alpha
 Usage   : $model->set_alpha(1);
 Function: Set shape parameter.
 Returns : A Bio::Phylo::Models::Substitution::Dna object.
 Args    : scalar

=cut

sub set_alpha {
    my $self = shift;
    $self->{'_alpha'} = shift;
    return $self;
}

=item set_mu

Setter for overall mutation rate.

 Type    : method
 Title   : set_mu
 Usage   : $model->set_mu(0.5);
 Function: Set overall mutation rate.
 Returns : A Bio::Phylo::Models::Substitution::Dna object.
 Args    : scalar

=cut

sub set_mu {
    my $self = shift;
    $self->{'_mu'} = shift;
    return $self;
}

=item set_pinvar

Set for proportion of invariant sites.

 Type    : method
 Title   : set_pinvar
 Usage   : $model->set_pinvar(0.1);
 Function: Set proportion of invariant sites.
 Returns : A Bio::Phylo::Models::Substitution::Dna object.
 Args    : scalar

=cut

sub set_pinvar {
    my $self   = shift;
    my $pinvar = shift;
    if ( $pinvar <= 0 || $pinvar >= 1 ) {
        throw 'BadArgs' => "Pinvar not between 0 and 1";
    }
    $self->{'_pinvar'} = $pinvar;
    return $self;
}

=item set_pi

Setter for base frequencies.

 Type    : method
 Title   : get_pi
 Usage   : $model->set_pi((0.2, 0.2, 0.3, 0.3));
 Function: Set base frequencies.
 Returns : A Bio::Phylo::Models::Substitution::Dna object.
 Args    : array of four base frequencies (A, C, G, T)
 Comments: Base frequencies must sum to one

=cut

sub set_pi {
    my ( $self, $pi ) = @_;
    ref $pi eq 'ARRAY' or throw 'BadArgs' => "Not an array ref!";
    my $total = 0;
    $total += $_ for @{$pi};
    my $epsilon = 0.000001;
    abs(1 - $total) < $epsilon or throw 'BadArgs' => 'Frequencies must sum to one';
    $self->{'_pi'} = $pi;
    return $self;
}

=item set_median

Setter for median for gamma-modeled rate categories.

 Type    : method
 Title   : set_median
 Usage   : $model->set_median(1);
 Function: Setter for median.
 Returns : A Bio::Phylo::Models::Substitution::Dna object.
 Args    : scalar

=cut

sub set_median {
    my $self = shift;
    $self->{'_median'} = !!shift;
    return $self;
}

=item modeltest

Performing a modeltest using the package 'phangorn' in
R (Schliep, Bioinformatics (2011) 27 (4): 592-593) from an
DNA alignment. If no tree is given as argument, a neighbor-joining
tree is generated from the alignment to perform model testing.
Selects the model with the minimum AIC.

 Type    : method
 Title   : modeltest
 Usage   : $model->modeltest(-matrix=>$matrix);
 Function: Determine DNA substitution model from alignment.
 Returns : An object which is subclass of Bio::Phylo::Models::Substitution::Dna.
 Args    : -matrix: A Bio::Phylo::Matrices::Matrix object
           Optional:
           -tree: A Bio::Phylo::Forest::Tree object
           -timeout: Timeout in seconds to prevent getting stuck in an R process.
 Comments: Prerequisites: Statistics::R, R, and the R package phangorn.

=cut

sub modeltest {
	my ($self, %args) = @_;

	my $matrix = $args{'-matrix'};
	my $tree = $args{'-tree'};
	my $timeout = $args{'-timeout'};

	my $model;

	if ( looks_like_class 'Statistics::R' ) {

		eval {
			# phangorn needs files as input
			my ($fasta_fh, $fasta) = tempfile();
			print $fasta_fh unparse('-phylo'=>$matrix, '-format'=>'fasta');
			close $fasta_fh;

			# instanciate R and lcheck if phangorn is installed
			my $R = Statistics::R->new;
			$R->timeout($timeout) if $timeout;
			$R->run(q[options(device=NULL)]);
			$R->run(q[package <- require("phangorn")]);

			if ( ! $R->get(q[package]) eq "TRUE") {
				$logger->warn("R library phangorn must be installed to run modeltest");
				return $model;
			}

			# read data
			$R->run(qq[data <- read.FASTA("$fasta")]);

			# remove temp file
			cleanup();

			if ( $tree ) {
				# make copy of tree since it will be pruned
				my $current_tree = parse('-format'=>'newick', '-string'=>$tree->to_newick)->first;
				# prune out taxa from tree that are not present in the data
				my @taxon_names = map {$_->get_name} @{ $matrix->get_entities };
				$logger->debug('pruning input tree');
				$current_tree->keep_tips(\@taxon_names);
				$logger->debug('pruned input tree: ' . $current_tree->to_newick);

				if ( ! $current_tree or scalar( @{ $current_tree->get_terminals } ) < 3 ) {
					$logger->warn('pruned tree has too few tip labels, determining substitution model using NJ tree');
					$R->run(q[test <- modelTest(phyDat(data))]);
				}
				else {
					my $newick = $current_tree->to_newick;

					$R->run(qq[tree <- read.tree(text="$newick")]);
					# call modelTest
					$logger->debug("calling modelTest from R package phangorn");
					$R->run(q[test <- modelTest(phyDat(data), tree=tree)]);
				}
			}
			else {
				# modelTest will estimate tree
				$R->run(q[test <- modelTest(phyDat(data))]);
			}

			# get model with lowest Aikaike information criterion
			$R->run(q[model <- test[which(test$AIC==min(test$AIC)),]$Model]);
			my $modeltype = $R->get(q[model]);
			$logger->info("estimated DNA evolution model $modeltype");

			# determine model parameters
			$R->run(q[env <- attr(test, "env")]);
			$R->run(q[fit <- eval(get(model, env), env)]);

			#  get base freqs
			my $pi = $R->get(q[fit$bf]);

			# get overall mutation rate
			my $mu = $R->get(q[fit$rate]);

			# get lower triangle of rate matrix (column order ACGT)
			# and fill whole matrix; set diagonal values to 1
			my $q = $R->get(q[fit$Q]);
			my $rate_matrix = [ [ 1,       $q->[0], $q->[1], $q->[3] ],
								[ $q->[0], 1,       $q->[2], $q->[4] ],
								[ $q->[1], $q->[2], 1,       $q->[5] ],
								[ $q->[3], $q->[4], $q->[5], 1       ]
				];

			# create model with specific parameters dependent on primary model type
			if ( $modeltype =~ /JC/ ) {
				require Bio::Phylo::Models::Substitution::Dna::JC69;
				$model = Bio::Phylo::Models::Substitution::Dna::JC69->new();
			}
			elsif ( $modeltype =~ /F81/ ) {
				require Bio::Phylo::Models::Substitution::Dna::F81;
				$model = Bio::Phylo::Models::Substitution::Dna::F81->new('-pi' => $pi);
			}
			elsif ( $modeltype =~ /GTR/ ) {
				require Bio::Phylo::Models::Substitution::Dna::GTR;
				$model = Bio::Phylo::Models::Substitution::Dna::GTR->new('-pi' => $pi);
			}
			elsif ( $modeltype =~ /HKY/ ) {
				require Bio::Phylo::Models::Substitution::Dna::HKY85;
				# transition/transversion ratio kappa determined by transiton A->G/A->C in Q matrix
				my $kappa = $R->get(q[fit$Q[2]/fit$Q[1]]);
				$model = Bio::Phylo::Models::Substitution::Dna::HKY85->new('-kappa' => $kappa, '-pi' => $pi );
			}
			elsif ( $modeltype =~ /K80/ ) {
				require Bio::Phylo::Models::Substitution::Dna::K80;
			my $kappa = $R->get(q[fit$Q[2]]);
				$model = Bio::Phylo::Models::Substitution::Dna::K80->new(
					'-pi' => $pi,
					'-kappa' => $kappa );
			}
			# Model is unknown  (e.g. phangorn's SYM ?)
			else {
				$logger->debug("unknown model type, setting to generic DNA substitution model");
				$model = Bio::Phylo::Models::Substitution::Dna->new(
					'-pi' => $pi );
			}

			# set gamma parameters
			if ( $modeltype =~ /\+G/ ) {
				$logger->debug("setting gamma parameters for $modeltype model");
				# shape of gamma distribution
				my $alpha = $R->get(q[fit$shape]);
				$model->set_alpha($alpha);
				# number of categories for Gamma distribution
				my $ncat = $R->get(q[fit$k]);
				$model->set_ncat($ncat);
				# weights for rate categories
				my $catweights = $R->get(q[fit$w]);
				$model->set_catweights($catweights);
			}

			# set invariant parameters
			if ( $modeltype =~ /\+I/ ) {
				$logger->debug("setting invariant site parameters for $modeltype model");
				# get proportion of invariant sites
				my $pinvar = $R->get(q[fit$inv]);
				$model->set_pinvar($pinvar);
			}
			# set universal parameters
			$model->set_rate($rate_matrix);
			$model->set_mu($mu);
		};
		# catch possible R errors (e.g. timeout)
		if ($@) {
			$logger->warn("modeltest not successful : " . $@);
		}
	}
	else {
		$logger->warn("Statistics::R must be installed to run modeltest");
	}

	return $model;
}

=item to_string

Get string representation of model in specified format
(paup, phyml, mrbayes or garli)

 Type    : method
 Title   : to_string
 Usage   : $model->to_string(-format=>'mrbayes');
 Function: Write model to string.
 Returns : scalar
 Args    : scalar
 Comments: format must be either paup, phyml, mrbayes or garli

=cut

sub to_string {
    my $self = shift;
    my %args = looks_like_hash @_;
    if ( $args{'-format'} =~ m/paup/i ) {
        return $self->_to_paup_string(@_);
    }
    if ( $args{'-format'} =~ m/phyml/i ) {
        return $self->_to_phyml_string(@_);
    }
    if ( $args{'-format'} =~ m/mrbayes/i ) {
        return $self->_to_mrbayes_string(@_);
    }
    if ( $args{'-format'} =~ m/garli/i ) {
        return $self->_to_garli_string(@_);
    }
}

sub _to_garli_string {
    my $self   = shift;
    my $nst    = $self->get_nst;
    my $string = "ratematrix ${nst}\n";
    if ( my $pinvar = $self->get_pinvar ) {
        $string .= "invariantsites fixed\n";
    }
    if ( my $ncat = $self->get_ncat ) {
        $string .= "numratecats ${ncat}\n";
    }
    if ( my $alpha = $self->get_alpha ) {
        $string .= "ratehetmodel gamma\n";
    }
    return $string;
}

sub _to_mrbayes_string {
    my $self   = shift;
    my $string = 'lset ';
    $string .= ' nst=' . $self->get_nst;
    if ( $self->get_pinvar && $self->get_alpha ) {
        $string .= ' rates=invgamma';
        if ( $self->get_ncat ) {
            $string .= ' ngammacat=' . $self->get_ncat;
        }
    }
    elsif ( $self->get_pinvar ) {
        $string .= ' rates=propinv';
    }
    elsif ( $self->get_alpha ) {
        $string .= ' rates=gamma';
        if ( $self->get_ncat ) {
            $string .= ' ngammacat=' . $self->get_ncat;
        }
    }
    $string .= ";\n";
    if ( $self->get_kappa && $self->get_nst == 2 ) {
        $string .= 'prset tratiopr=fixed(' . $self->get_kappa . ");\n";
    }
    my @rates;
    push @rates, $self->get_rate( 'A' => 'C' );
    push @rates, $self->get_rate( 'A' => 'G' );
    push @rates, $self->get_rate( 'A' => 'T' );
    push @rates, $self->get_rate( 'C' => 'G' );
    push @rates, $self->get_rate( 'C' => 'T' );
    push @rates, $self->get_rate( 'G' => 'T' );
    $string .= 'prset revmatpr=fixed(' . join( ',', @rates ) . ");\n";

    if (   $self->get_pi('A')
        && $self->get_pi('C')
        && $self->get_pi('G')
        && $self->get_pi('T') )
    {
        my @freqs;
        push @freqs, $self->get_pi('A');
        push @freqs, $self->get_pi('C');
        push @freqs, $self->get_pi('G');
        push @freqs, $self->get_pi('T');
        $string .= 'prset statefreqpr=fixed(' . join( ',', @freqs ) . ");\n";
    }
    if ( $self->get_alpha ) {
        $string .= 'prset shapepr=fixed(' . $self->get_alpha . ");\n";
    }
    if ( $self->get_pinvar ) {
        $string .= 'prset pinvarpr=fixed(' . $self->get_pinvar . ");\n";
    }
}

sub _to_phyml_string {
    my $self = shift;
    my $m    = ref $self;
    $m =~ s/.+://;
    my $string = "--model $m";
    if (   $self->get_pi('A')
        && $self->get_pi('C')
        && $self->get_pi('G')
        && $self->get_pi('T') )
    {
        my @freqs;
        push @freqs, $self->get_pi('A');
        push @freqs, $self->get_pi('C');
        push @freqs, $self->get_pi('G');
        push @freqs, $self->get_pi('T');
        $string .= ' -f ' . join ' ', @freqs;
    }
    if ( $self->get_nst == 2 and defined( my $kappa = $self->get_kappa ) ) {
        $string .= ' --ts/tv ' . $kappa;
    }
    if ( $self->get_pinvar ) {
        $string .= ' --pinv ' . $self->get_pinvar;
    }
    if ( $self->get_ncat ) {
        $string .= ' --nclasses ' . $self->get_ncat;
        $string .= ' --use_median' if $self->get_median;
    }
    if ( $self->get_alpha ) {
        $string .= ' --alpha ' . $self->get_alpha;
    }
    return $string;
}

sub _to_paup_string {
    my $self   = shift;
    my $nst    = $self->get_nst;
    my $string = 'lset nst=' . $nst;
    if ( $nst == 2 and defined( my $kappa = $self->get_kappa ) ) {
        $string .= ' tratio=' . $kappa;
    }
    if ( $nst == 6 ) {
        my @rates;
        push @rates, $self->get_rate( 'A' => 'C' );
        push @rates, $self->get_rate( 'A' => 'G' );
        push @rates, $self->get_rate( 'A' => 'T' );
        push @rates, $self->get_rate( 'C' => 'G' );
        push @rates, $self->get_rate( 'C' => 'T' );
        $string .= ' rmatrix=(' . join( ' ', @rates ) . ')';
    }
    if ( $self->get_pi('A') && $self->get_pi('C') && $self->get_pi('G') ) {
        my @freqs;
        push @freqs, $self->get_pi('A');
        push @freqs, $self->get_pi('C');
        push @freqs, $self->get_pi('G');
        $string .= ' basefreq=(' . join( ' ', @freqs ) . ')';
    }
    if ( $self->get_alpha ) {
        $string .= ' rates=gamma shape=' . $self->get_alpha;
    }
    if ( $self->get_ncat ) {
        $string .= ' ncat=' . $self->get_ncat;
        $string .= ' reprate=' . ( $self->get_median ? 'median' : 'mean' );
    }
    if ( $self->get_pinvar ) {
        $string .= ' pinvar=' . $self->get_pinvar;
    }
    return $string . ';';
}

sub _type { _MODEL_ }

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
