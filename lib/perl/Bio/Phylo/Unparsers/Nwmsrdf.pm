package Bio::Phylo::Unparsers::Nwmsrdf;
use strict;
use warnings;
use base 'Bio::Phylo::Unparsers::Abstract';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::CONSTANT qw':objecttypes looks_like_object';

=head1 NAME

Bio::Phylo::Unparsers::Nwmsrdf - Serializer used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This unparser produces multistate character state matrices for the "Network" 
(L<http://www.fluxus-engineering.com/sharenet.htm>) program. These files by Network's 
conventions have the .rdf extension, which has nothing to do with RDF. The matrices are
represented as follows:

=over

=item Only variable columns are shown. The header includes the column number.

=item The end of each character row has the frequency of the haplotype. By default this
is 1, other values can be specified by adding an annotation to the row in question:

	$row->set_meta_object( 'bp:haplotype_frequency' => 2 );

=item The bottom of the file lists the weight of each column. By default this is 10, other
values can be specified by adding a weight to the character:

	$char->set_weight( 15 );

=item Taxon names must be variable in the first 6 characters as they are truncated to 
this length.

=back

=cut

sub _to_string {
    my $self = shift;
    
    # get the matrix object
    my $obj  = $self->{'PHYLO'};
    my $matrix;
    eval { $matrix = $obj if looks_like_object $obj, _MATRIX_; };
    if ($@) {
        undef($@);
        eval {
            ($matrix) = @{ $obj->get_matrices }
              if looks_like_object $obj, _PROJECT_;
        };
        if ( $@ or not $matrix ) {
            throw 'ObjectMismatch' => 'Invalid object!';
        }
    }

	# build the matrix hash, record column numbers    
	my $nchar = $matrix->get_nchar;
	my $raw   = $matrix->get_raw;
	my %result = map { $_->[0] => '' } @{ $raw };
	my @cols;
	my ( $missing, $gap ) = ( $matrix->get_missing, $matrix->get_gap );
	for my $i ( 1 .. $nchar ) {
		my %seen;
		my %state;
		for my $row ( @{ $raw } ) {
			my $state = $row->[$i];
			$state{$row->[0]} = $state;
			$seen{$state}++ if $state ne $missing and $state ne $gap;
		}
		if ( scalar(keys(%seen)) > 1 ) {
			push @cols, $i;
			$result{$_} .= $state{$_} for keys %state;
		}
	}
	
	# build the header with column numbers
	my $result = '';
	my @header;
	push @header, ' ' x 7 for 1 .. 6;
	for my $c ( @cols ) {
		my @parts = split //, $c;
		for my $i ( 0 .. $#header ) {
			my $val = defined($parts[$i]) ? $parts[$i] : ' ';
			$header[$i] .= $val;
		}
	}
	$result .= join "\n", @header;
	$result .= "\n";
	
	# build the matrix
	for my $name ( map { $_->[0] } @{ $raw } ) {
		if ( length($name) <= 6 ) {
			$result .= $name . ( ' ' x ( 7 - length($name) ) );
		}
		else {
			$result .= substr( $name, 0, 6 ) . ' ';
		}
		$result .= $result{$name} . '  ';
		my $freq = $matrix->get_by_name($name)->get_meta_object('bp:haplotype_frequency') || 1;
		$result .= $freq . "\n";
	}
	$result .= "\n";
	
	# build the character weights
	my $characters = $matrix->get_characters;
	my @weights;
	for my $i ( @cols ) {
		my $weight = $characters->get_by_index($i-1)->get_weight;
		$weight = 10 if not defined $weight;
		push @weights, $weight;
	}
	for ( my $i = 0; $i <= $#weights; $i += 124 ) {
		my $max = $i+124 < $#weights ? $i+124 : $#weights;
		$result .= join '', @weights[$i..$max];
		$result .= "\n";
	}
	return $result;
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The nwmsrdf unparser is called by the L<Bio::Phylo::IO> object.
Look there to learn how to create phylip formatted files.

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
