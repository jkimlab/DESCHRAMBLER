package Bio::Phylo::Unparsers::Hennig86;
use strict;
use warnings;
use base 'Bio::Phylo::Unparsers::Abstract';
use Bio::Phylo;
use Bio::Phylo::Util::CONSTANT qw'/looks_like/ :objecttypes';
use Bio::Phylo::Util::Exceptions 'throw';

my $MATRIX  = _MATRIX_;
my $PROJECT = _PROJECT_;
my %typemap = (
    'continuous' => 'cont',
    'dna'        => 'dna',
    'protein'    => 'prot',
    'restriction'=> 'num',
    'rna'        => 'rna',
    'standard'   => 'num',
);


=head1 NAME

Bio::Phylo::Unparsers::Hennig86 - Serializer used by Bio::Phylo::IO, no serviceable
parts inside

=head1 DESCRIPTION

This module turns the supplied object into a Hennig86 string. The supplied
object has to either be a L<Bio::Phylo::Matrices::Matrix> object or a
L<Bio::Phylo::Project> object, whose first matrix is exported to Hennig86. In
other words, this only works on things that are or contain character state
matrices. 

=begin comment

 Type    : Wrapper
 Title   : _to_string
 Usage   : my $hennig_string = $obj->_to_string;
 Function: Stringifies a Bio::Phylo object into a Hennig86 string
 Alias   :
 Returns : SCALAR
 Args    : Bio::Phylo::* object

=end comment

=cut

sub _to_string {
    my $self = shift;
    my $obj  = $self->{'PHYLO'};
    my $matrix;
    if ( looks_like_implementor $obj, '_type' ) {
        if ( $obj->_type == $MATRIX ) {
            $matrix = $obj;
        }
        elsif ( $obj->_type == $PROJECT ) {
            ($matrix) = @{ $obj->get_items(_MATRIX_) };
        }
        else {
            throw 'ObjectMismatch' => "Can't serialize ".ref($obj)." objects as Hennig86";
        }
        return $self->_serialize_matrix($matrix);
    }
    else {
        throw 'ObjectMismatch' => "Can't serialize supplied argument as Hennig86";
    }    
}

sub _serialize_matrix {
    my ( $self, $matrix ) = @_;    
    my $hennig86 = $self->_create_header($matrix);
    my $to = $matrix->get_type_object;
    for my $row ( @{ $matrix->get_entities } ) {
        $hennig86 .= $row->get_nexus_name . "\t";
        my @char = $row->get_char;
        my @encoded;
        for my $c ( @char ) {
            if ( $to->is_ambiguous($c) ) {
                my @states = @{ $to->get_states_for_symbol($c) };
                push @encoded, '[' . $to->join(\@states) . ']';
            }
            else {
                push @encoded, $c;
            }
        }
        $hennig86 .= $to->join(\@encoded) . "\n";
    }
    return $hennig86 .= ";\n";
}

sub _create_header {
    my ( $self, $matrix ) = @_;
    
    my $comment = "Hennig86 matrix written by ".ref($self)." ".Bio::Phylo->VERSION." on ".localtime();
    
    # calculate nstates
    my $nstates = scalar keys %{ $matrix->calc_state_counts };
    
    # calculate ntax and nchar
    my ( $ntax, $nchar ) = ( $matrix->get_ntax, $matrix->get_nchar );
    
    # map type to hennig86 tokens
    my $type = lc $matrix->get_type;
    my $hennig86type = $typemap{ $type } || throw 'BadFormat' => "Can't write $type matrices to Hennig86";

    my $template = << 'TEMPLATE';
nstates %d
xread
'%s'
%d %d
& [%s]
TEMPLATE

    return sprintf $template, $nstates, $comment, $nchar, $ntax, $hennig86type;
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The hennig86 unparser is called by the L<Bio::Phylo::IO> object.
Look there to learn how to unparse objects.

=item L<Bio::Phylo::Manual>

Also see the manual: L<Bio::Phylo::Manual> and L<http://rutgervos.blogspot.com>.

=item Hennig86 file format

To learn more about the Hennig86 format, visit
L<http://www.phylo.org/tools/hennig.html>.

=back

=head1 CITATION

If you use Bio::Phylo in published research, please cite it:

B<Rutger A Vos>, B<Jason Caravas>, B<Klaas Hartmann>, B<Mark A Jensen>
and B<Chase Miller>, 2011. Bio::Phylo - phyloinformatic analysis using Perl.
I<BMC Bioinformatics> B<12>:63.
L<http://dx.doi.org/10.1186/1471-2105-12-63>

=cut

1;