package Bio::Phylo::Unparsers::Nexml;
use strict;
use warnings;
use base 'Bio::Phylo::Unparsers::Abstract';
use Bio::Phylo::Util::CONSTANT qw':objecttypes looks_like_object';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::Dependency 'XML::Twig';

=head1 NAME

Bio::Phylo::Unparsers::Nexml - Serializer used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module serializes Taxa objects, Forest objects and Matrix objects
to NeXML.

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
    my $self     = shift;
    my $taxa_obj = $self->{'PHYLO'};
    if ( $taxa_obj->can('_type') && $taxa_obj->_type == _PROJECT_ ) {
        return $taxa_obj->to_xml;
    }
    if ( $taxa_obj->can('_type') && $taxa_obj->_type == _DESCRIPTION_ ) {
        return $taxa_obj->to_xml;
    }
    if ( $taxa_obj->can('_type') && $taxa_obj->_type != _TAXA_ ) {
        if ( $taxa_obj->can('make_taxa') ) {
            my $obj          = $taxa_obj->make_taxa;
            my $attached_obj = $taxa_obj;
            for my $contained_obj ( @{ $attached_obj->get_entities } ) {
                if ( $contained_obj->_type == _DATUM_ ) {
                    $contained_obj->set_name();
                }
                else {
                    for my $node ( @{ $contained_obj->get_entities } ) {
                        $node->set_name();
                    }
                }
            }
            $taxa_obj = $obj;
        }
        else {
            throw 'ObjectMismatch' =>
"Object ($taxa_obj) is not a taxa object,\n and doesn't link to one";
        }
    }

    # 	else {
    # 		throw 'ObjectMismatch' => "Can't serialize $taxa_obj to nexml";
    # 	}
    my $parse_twig = XML::Twig->new;
    my $nexml_twig = XML::Twig->new;
    my $nexml_root = XML::Twig::Elt->new(
        'nex:nexml',
        {
            'xmlns:nex' => 'http://www.nexml.org/2009',
            'version'   => '0.9',
            'generator' => __PACKAGE__ . ' v.' . $Bio::Phylo::VERSION,
            'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
            'xsi:schemaLocation' =>
              'http://www.nexml.org/2009 http://www.nexml.org/1.0/nexml.xsd',
        }
    );
    eval {
        my $taxa_elt =
          $parse_twig->parse( $taxa_obj->to_xml( %{ $self->{TAXA_ARGS} } ) );
        $taxa_elt->root->paste($nexml_root);
    };
    die $@, $taxa_obj->to_xml( ${ $self->{TAXA_ARGS} } ) if $@;
    if ( $taxa_obj->get_matrices ) {
        for my $characters_obj ( reverse @{ $taxa_obj->get_matrices } ) {
            eval {
                my $characters_elt =
                  $parse_twig->parse(
                    $characters_obj->to_xml( %{ $self->{MATRIX_ARGS} } ) );
                $characters_elt->root->paste( 'last_child', $nexml_root );
            };
            die $@, $characters_obj->to_xml( %{ $self->{MATRIX_ARGS} } ) if $@;
        }
    }
    if ( $taxa_obj->get_forests ) {
        for my $forest_obj ( reverse @{ $taxa_obj->get_forests } ) {
            eval {
                my $forest_elt =
                  $parse_twig->parse(
                    $forest_obj->to_xml( %{ $self->{FOREST_ARGS} } ) );
                $forest_elt->root->paste( 'last_child', $nexml_root );
            };
            die $@, $forest_obj->to_xml( %{ $self->{FOREST_ARGS} } ) if $@;
        }
    }
    $nexml_twig->set_root($nexml_root);
    $nexml_twig->set_xml_version('1.0');
    $nexml_twig->set_encoding('UTF-8');
    $nexml_twig->set_pretty_print('indented');
    $nexml_twig->set_empty_tag_style('normal');
    my $nexml_string = $nexml_twig->sprint();
    return $nexml_string;
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The NeXML serializer is called by the L<Bio::Phylo::IO> object.

=item L<Bio::Phylo::Manual>

Also see the manual: L<Bio::Phylo::Manual>.

=item L<http://www.nexml.org>

The NeXML project is housed at L<http://www.nexml.org>

=back

=head1 CITATION

If you use Bio::Phylo in published research, please cite it:

B<Rutger A Vos>, B<Jason Caravas>, B<Klaas Hartmann>, B<Mark A Jensen>
and B<Chase Miller>, 2011. Bio::Phylo - phyloinformatic analysis using Perl.
I<BMC Bioinformatics> B<12>:63.
L<http://dx.doi.org/10.1186/1471-2105-12-63>

=cut

1;
