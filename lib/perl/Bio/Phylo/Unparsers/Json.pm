package Bio::Phylo::Unparsers::Json;
use strict;
use warnings;
use base 'Bio::Phylo::Unparsers::Abstract';
use Bio::Phylo::Util::CONSTANT qw'/looks_like/';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::Dependency qw'XML::XML2JSON';

=head1 NAME

Bio::Phylo::Unparsers::Json - Serializer used by Bio::Phylo::IO, no serviceable
parts inside

=head1 DESCRIPTION

This module turns the supplied object into a JSON string.

=begin comment

 Type    : Wrapper
 Title   : _to_string
 Usage   : my $json_string = $obj->_to_string;
 Function: Stringifies a Bio::Phylo object into a JSON string
 Alias   :
 Returns : SCALAR
 Args    : Bio::Phylo::* object

=end comment

=cut

sub _to_string {
    my $self = shift;
    my $obj  = $self->{'PHYLO'};
    if ( looks_like_implementor $obj, 'to_json' ) {
        return $obj->to_json;
    }
    else {
        throw 'ObjectMismatch' => "Can't make JSON string out of $obj";
    }
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The json unparser is called by the L<Bio::Phylo::IO> object.
Look there to learn how to unparse objects.

=item L<Bio::Phylo::Manual>

Also see the manual: L<Bio::Phylo::Manual> and L<http://rutgervos.blogspot.com>.

=item L<http://www.json.org>

To learn more about the JavaScript Object Notation (JSON) format, visit
L<http://www.json.org>.

=back

=head1 CITATION

If you use Bio::Phylo in published research, please cite it:

B<Rutger A Vos>, B<Jason Caravas>, B<Klaas Hartmann>, B<Mark A Jensen>
and B<Chase Miller>, 2011. Bio::Phylo - phyloinformatic analysis using Perl.
I<BMC Bioinformatics> B<12>:63.
L<http://dx.doi.org/10.1186/1471-2105-12-63>

=cut

1;