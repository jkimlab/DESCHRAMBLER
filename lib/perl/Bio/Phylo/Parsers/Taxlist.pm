package Bio::Phylo::Parsers::Taxlist;
use strict;
use warnings;
use base 'Bio::Phylo::Parsers::Abstract';
use Bio::Phylo::Util::CONSTANT;

=head1 NAME

Bio::Phylo::Parsers::Taxlist - Parser used by Bio::Phylo::IO, no serviceable parts inside

=head1 DESCRIPTION

This module is used for importing sets of taxa from plain text files, one taxon
on each line. It is called by the L<Bio::Phylo::IO|Bio::Phylo::IO> object, so
look there for usage examples. If you want to parse from a string, you
may need to indicate the field separator (default is '\n') to the
Bio::Phylo::IO->parse call:

 -fieldsep => '\n',

=cut

sub _parse {
    my $self = shift;
    my $fh   = $self->_handle;
    my $fac  = $self->_factory;
    my $taxa = $fac->create_taxa;
    local $/ = $self->_args->{'-fieldsep'} || "\n";
    my $delim = $self->_args->{'-delim'} || "\t";
    my @header;
    LINE: while (<$fh>) {
        chomp;
        my @fields = split /$delim/, $_;
        my $name;
        my %meta;
        
        # this means it is actually tabular, which also means it has a header
        if ( scalar @fields > 1 ) {
            
            # this happens the first line
            if ( not @header ) {
                @header = @fields;
                for my $predicate ( @header ) {
                    if ( $predicate =~ /^(.+?):.+$/ ) {
                        my $prefix = $1;
                        $taxa->set_namespaces(
                            $prefix => $Bio::Phylo::Util::CONSTANT::NS->{$prefix}
                        );
                    }
                }
                next LINE;
            }
            
            # create key value pairs to attach
            for my $i ( 1 .. $#fields ) {
                $meta{$header[$i]} = $fields[$i] if $fields[$i];
            }
        }
        
        # this is the first field regardless        
        $name = shift @fields;
        my $taxon = $fac->create_taxon( '-name' => $name );
        
        # attach metadata, if any
        for my $predicate ( keys %meta ) {
            $taxon->add_meta(
                $fac->create_meta( '-triple' => { $predicate => $meta{$predicate} } )
            );
        }
        $taxa->insert( $taxon );
    }
    return $taxa;
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The taxon list parser is called by the L<Bio::Phylo::IO> object.
Look there for examples.

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
