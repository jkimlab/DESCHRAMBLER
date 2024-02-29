package Bio::Phylo::Unparsers::Taxlist;
use strict;
use warnings;
use base 'Bio::Phylo::Unparsers::Abstract';
use Bio::Phylo::Util::CONSTANT qw'/looks_like/ :objecttypes';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::Dependency qw'Template';

=head1 NAME

Bio::Phylo::Unparsers::Taxlist - Serializer used by Bio::Phylo::IO, no serviceable
parts inside

=head1 DESCRIPTION

This module creates a taxon list/table

=begin comment

 Type    : Wrapper
 Title   : _to_string
 Usage   : my $json_string = $obj->_to_string;
 Function: Stringifies a Bio::Phylo object into an HTML string
 Alias   :
 Returns : SCALAR
 Args    : Bio::Phylo::* object

=end comment

=cut

sub _to_string {
    my $self = shift;
    my $obj  = $self->{'PHYLO'};
	my $taxa;
    if ( $obj->_type == _PROJECT_ ) {
        $taxa = $obj->get_items(_TAXON_);
	}
	elsif ( $obj->_type == _TAXA_ ) {
		$taxa = $obj->get_entities;
	}
    else {
        throw 'ObjectMismatch' => "Can't make taxon list string out of $obj";
    }	
	my %predicates;
	for my $taxon ( @{ $taxa } ) {
		for my $meta ( @{ $taxon->get_meta } ) {
			$predicates{$meta->get_predicate} = 1;
		}
	}
	my @predicates = keys %predicates;
	my $result = '';
	if ( @predicates ) {
		$result .= "name\t" . join("\t",@predicates) . "\n";
	}
	for my $taxon ( @{ $taxa } ) {
		$result .= $taxon->get_name;
		if ( @predicates ) {
			my @values;
			for my $predicate ( @predicates ) {
				push @values, $taxon->get_meta_object($predicate);
			}
			$result .= "\t" . join("\t",@values);
		}
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

The taxlist unparser is called by the L<Bio::Phylo::IO> object.
Look there to learn how to unparse objects.

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