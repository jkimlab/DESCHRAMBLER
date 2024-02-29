package Bio::Phylo::Models::Substitution::Binary;
use strict;
use warnings;
use Data::Dumper;
use Bio::Phylo::Util::Logger;
use Bio::Phylo::Util::CONSTANT qw'/looks_like/ :objecttypes';
use Bio::Phylo::Util::Exceptions qw'throw';

my $logger = Bio::Phylo::Util::Logger->new;

=head1 NAME

Bio::Phylo::Models::Substitution::Binary - Binary character substitution model

=head1 SYNOPSIS

use Bio::Phylo::Models::Substitution::Binary;

# create a binary substitution model
# by doing a modeltest
my $model = Bio::Phylo::Models::Substitution::Binary->modeltest(
	-tree   => $tree,   # phylogeny
	-matrix => $matrix, # character state matrix, standard categorical data
	-model  => 'ARD',   # ace model
	-char   => 'c1',    # column ID in $matrix
);

# after model test, forward and reverse instantaneous transition
# rates are available, e.g. for simulation
print $model->forward, "\n";
print $model->reverse, "\n";

=head1 DESCRIPTION

This is a class that encapsulates an instantaneous transition model
for a binary character. The model is asymmetrical in that the forward
and reverse rates (can) differ. The rates can be inferred from a 
character in a character state matrix by modeltesting. This is done
by delegation to the R package C<ape>. For this to work, you therefore
need to have R and C<ape> installed, as well as the bridge that allows
Perl to communicate with R, which is done by the optional package
L<Statistics::R>.

=head1 METHODS

=head2 CONSTRUCTOR

=over

=item new

Binary character model constructor.

 Type    : Constructor
 Title   : new
 Usage   : my $model = Bio::Phylo::Models::Substitution::Binary->new(%args);
 Function: Instantiates a Bio::Phylo::Models::Substitution::Binary object.
 Returns : A Bio::Phylo::Models::Substitution::Binary object.
 Args    : Optional:
	       -forward => sets forward rate
	       -reverse => sets reverse rate

=cut

sub new {
    my $class = shift;
    my %args  = looks_like_hash @_;
    my $self  = { '_fw' => undef, '_rev' => undef };
    bless $self, $class;
    while ( my ( $key, $value ) = each %args ) {
        $key =~ s/^-/set_/;
        $self->$key($value);
    }
    return $self;
}

=item set_forward

Setter for forward transition rate

 Type    : method
 Title   : set_forward
 Usage   : $model->set_forward($rate);
 Function: Setter for forward transition rate
 Returns : $self
 Args    : A rate (floating point number)

=cut

sub set_forward {
	my ( $self, $fw ) = @_;
	$self->{'_fw'} = $fw;
	return $self;
}

=item set_reverse

Setter for reverse transition rate

 Type    : method
 Title   : set_reverse
 Usage   : $model->set_reverse($rate);
 Function: Setter for reverse transition rate
 Returns : $self
 Args    : A rate (floating point number)

=cut

sub set_reverse {
	my ( $self, $rev ) = @_;
	$self->{'_rev'} = $rev;
	return $self;
}

=item get_forward

Setter for forward transition rate

 Type    : method
 Title   : get_forward
 Usage   : my $rate = $model->get_forward;
 Function: Getter for forward transition rate
 Returns : A rate (floating point number)
 Args    : NONE

=cut

sub get_forward { shift->{'_fw'} }

=item get_reverse

Setter for reverse transition rate

 Type    : method
 Title   : get_reverse
 Usage   : my $rate = $model->get_reverse;
 Function: Getter for reverse transition rate
 Returns : A rate (floating point number)
 Args    : NONE

=cut

sub get_reverse { shift->{'_rev'} }

=item modeltest

Performs a model test to infer transition rates

 Type    : method
 Title   : modeltest
 Usage   : my $model = $package->modeltest;
 Function: Performs a model test to infer transition rates
 Returns : A populated $model object
 Args    : All required:
			-tree   => $tree,   # phylogeny
			-matrix => $matrix, # character state matrix, standard categorical data
			-model  => 'ARD',   # ace model
			-char   => 'c1',    # column ID in $matrix

=cut

sub modeltest {

	# process arguments
	my ( $class, %args ) = @_;
	my $tree   = $args{'-tree'}   or throw 'BadArgs' => "Need -tree argument";
	my $char   = $args{'-char'}   or throw 'BadArgs' => "Need -char argument";
	my $matrix = $args{'-matrix'} or throw 'BadArgs' => "Need -matrix argument";
	my $model  = $args{'-model'}  || 'ARD';
	
	# we don't actually check if the character is binary here. perhaps we should,
	# and verify that the tips in the tree match the rows in the matrix, and 
	# prune tips with missing data, and, and, and...
	if ( $matrix->get_type !~ /standard/i ) {
		throw 'BadArgs' => "Need standard categorical data";
	}
	if ( looks_like_class 'Statistics::R' ) {
	
		# start R, load library
		$logger->info("going to run 'ace'");
		my $R = Statistics::R->new;
		$R->run(q[library("ape")]);
		
		# insert data
		my $newick = $tree->to_newick;
		my %hash = $class->_data_hash($char,$matrix);
		$R->run(qq[phylo <- read.tree(text="$newick")]);
		$R->set('chars', [values %hash]);
		$R->set('labels', [keys %hash]);
		$R->run(q[names(chars) <- labels]);
		
		# do calculation
		$R->run(qq[ans <- ace(chars,phylo,type="d",model="$model")]);
		$R->run(q[rates <- ans$rates]);
		my $rates = $R->get(q[rates]);
		$logger->info("Rates: ".Dumper($rates));
		
		# return instance
		return $class->new(
			'-forward' => $rates->[1],
			'-reverse' => $rates->[0],
		);	
	}
}

sub _data_hash {
	my ( $self, $char, $matrix ) = @_;
	my $cid = $char->get_id;
	my $chars = $matrix->get_characters;
	my $nchar = $matrix->get_nchar;
	my $name  = $char->get_name || $cid;
	
	# find index of character
	my $index;
	CHAR: for my $i ( 0 .. $nchar - 1 ) {
		my $c = $chars->get_by_index($i);
		if ( $c->get_id == $cid ) {
			$index = $i;
			$logger->info("index of character ${name}: ${index}");
			last CHAR;
		}
	}
	
	# get character states
	my %result;
	for my $row ( @{ $matrix->get_entities } ) {
		my @char = $row->get_char;
		my $name = $row->get_name;
		$result{$name} = $char[$index];
	}	
	$logger->debug(Dumper(\%result));
	return %result;
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
