package Bio::Phylo::Unparsers::Nexus;
use strict;
use warnings;
use base 'Bio::Phylo::Unparsers::Abstract';
use Bio::Phylo::Util::CONSTANT ':objecttypes';
use Bio::Phylo::Util::Exceptions 'throw';

=head1 NAME

Bio::Phylo::Unparsers::Nexus - Serializer used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module turns a L<Bio::Phylo::Matrices::Matrix> object into a nexus
formatted matrix. It is called by the L<Bio::Phylo::IO> facade, don't call it
directly. You can pass the following additional arguments to the unparse call:
	
	# an array reference of matrix, forest and taxa objects:
	-phylo => [ $block1, $block2 ]
	
	# the arguments that can be passed for matrix objects, 
	# refer to Bio::Phylo::Matrices::Matrix::to_nexus:
	-matrix_args => {}

	# the arguments that can be passed for forest objects, 
	# refer to Bio::Phylo::Forest::to_nexus:
	-forest_args => {}

	# the arguments that can be passed for taxa objects, 
	# refer to Bio::Phylo::Taxa::to_nexus:
	-taxa_args => {}	
	
	OR:
	
	# for backward compatibility:
	-phylo => $matrix	

=begin comment

 Type    : Wrapper
 Title   : _to_string($matrix)
 Usage   : $nexus->_to_string($matrix);
 Function: Stringifies a matrix object into
           a nexus formatted table.
 Alias   :
 Returns : SCALAR
 Args    : Bio::Phylo::Matrices::Matrix;

=end comment

=cut

sub _to_string {
    my $self   = shift;
    my $blocks = $self->{'PHYLO'};
    my $nexus  = "#NEXUS\n";
    my $type;
    eval { $type = $blocks->_type };

    # array?
    if ($@) {
        for my $block (@$blocks) {
            eval { $type = $block->_type };
            my %args;
            if ( $type == _FOREST_ ) {
                if ( exists $self->{'FOREST_ARGS'} ) {
                    %args = %{ $self->{'FOREST_ARGS'} };
                }
            }
            elsif ( $type == _TAXA_ ) {
                if ( exists $self->{'TAXA_ARGS'} ) {
                    %args = %{ $self->{'TAXA_ARGS'} };
                }
            }
            elsif ( $type == _MATRIX_ ) {
                if ( exists $self->{'MATRIX_ARGS'} ) {
                    %args = %{ $self->{'MATRIX_ARGS'} };
                }
            }
            elsif ($@) {
                throw 'ObjectMismatch' => "Can't unparse this object: $blocks";
            }
            $nexus .= $block->to_nexus(%args);
        }
    }
	
	# taxa?
    elsif ( defined $type and $type == _TAXA_ ) {
		my %args;
        if ( exists $self->{'TAXA_ARGS'} ) {
            %args = %{ $self->{'TAXA_ARGS'} };
        }		
        $nexus .= $blocks->to_nexus(%args);
    }
	
    # matrix?
    elsif ( defined $type and $type == _MATRIX_ ) {
		my %args;
        if ( exists $self->{'MATRIX_ARGS'} ) {
            %args = %{ $self->{'MATRIX_ARGS'} };
        }		
        $nexus .= $blocks->to_nexus(%args);
    }
	
	# forest?
	elsif ( defined $type and $type == _FOREST_ ) {
        my %args;
		if ( exists $self->{'FOREST_ARGS'} ) {
            %args = %{ $self->{'FOREST_ARGS'} };
        }		
		$nexus .= $blocks->to_nexus(%args);
	}

    # project?
    elsif ( defined $type and $type == _PROJECT_ ) {
		my ( %farg, %marg, %targ );
        if ( exists $self->{'TAXA_ARGS'} ) {
            %targ = %{ $self->{'TAXA_ARGS'} };
        }
        if ( exists $self->{'MATRIX_ARGS'} ) {
            %marg = %{ $self->{'MATRIX_ARGS'} };
        }
		if ( exists $self->{'FOREST_ARGS'} ) {
            %farg = %{ $self->{'FOREST_ARGS'} };
        }		
        $nexus = $blocks->to_nexus( %farg, %marg, %targ );
    }

    # wrong!
    else {
        throw 'ObjectMismatch' => "Can't unparse this object: $blocks";
    }
    return $nexus;
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The nexus serializer is called by the L<Bio::Phylo::IO> object.

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
