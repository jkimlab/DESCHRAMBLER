package Bio::Phylo::Unparsers::Html;
use strict;
use warnings;
use base 'Bio::Phylo::Unparsers::Abstract';
use Bio::Phylo::Util::CONSTANT qw'/looks_like/ :objecttypes';
use Bio::Phylo::Util::Exceptions 'throw';
use Bio::Phylo::Util::Dependency qw'Template';

=head1 NAME

Bio::Phylo::Unparsers::Html - Serializer used by Bio::Phylo::IO, no serviceable
parts inside

=head1 DESCRIPTION

This module creates an HTML representation of the provided project

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
    if ( $obj->_type == _PROJECT_ ) {
        my $result;
		my $template = $self->{'TEMPLATE'} || \*DATA;
		my $tt = Template->new;
		$tt->process($template,{'proj' => $obj},\$result);
		return $result;
    }
    else {
        throw 'ObjectMismatch' => "Can't make HTML string out of $obj";
    }
}

# podinherit_insert_token

=head1 SEE ALSO

There is a mailing list at L<https://groups.google.com/forum/#!forum/bio-phylo> 
for any user or developer questions and discussions.

=over

=item L<Bio::Phylo::IO>

The html unparser is called by the L<Bio::Phylo::IO> object.
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

__DATA__
<html>
	<head>
		<title>
			[% IF proj.get_name %]
				[% proj.get_name %]
			[% END %]
		</title>
	</head>
	<body>
		<img src="http://www.evoio.org/wg/evoio/images/f/f1/Phylotastic_logo.png"/>
		<h1>Document</h1>
		[% PROCESS identifiable obj = proj, tag = "h2" %]
		
		<!-- process taxa blocks, if any -->
		[% IF proj.get_taxa.size > 0 %]
			<h1>Taxa</h1>
			<!-- iterate over each taxa block -->
			<ul>
			[% FOREACH taxa = proj.get_taxa %]
				<li>
			
					<!-- write taxa block metadata -->
					[% PROCESS identifiable obj = taxa, tag = "h2" %]
					<h3>Number of taxa: [% taxa.get_ntax %]</h3>
					
					<!-- write taxon contents -->
					<ul>
					[% FOREACH taxon = taxa.get_entities %]
						[% PROCESS identifiable obj = taxon, tag = "li" %]
					[% END %]
					</ul>
				</li>
			[% END %]
			</ul>
		[% END %]
			
		<!-- process characters blocks, if any -->
		[% IF proj.get_matrices.size > 0 %]
			<h1>Characters</h1>
			<!-- iterate over each characters block -->
			[% FOREACH matrix = proj.get_matrices %]
			
				<!-- write characters block metadata -->
				[% PROCESS identifiable obj = matrix, tag = "h2" %]
				<ul>
					<li>Data type: [% matrix.get_type %]</li>
					<li>Number of taxa: [% matrix.get_ntax %]</li>
					<li>Number of characters: [% matrix.get_nchar %]</li>
					<li>Taxa block:
						<a href="#[% matrix.get_taxa.get_xml_id %]">
							[% matrix.get_taxa.get_internal_name %]
						</a>
					<li>
				</ul>
				
				<!-- write datum contents -->
				<table>
				[% FOREACH datum = matrix.get_entities %]
					<tr>
						<td>
							[% PROCESS identifiable obj = datum, tag = "h3" %]
						</td>
						<td>
							<pre>[% datum.get_char %]</pre>
						</td>
					</tr>
				[% END %]
				<table>
			[% END %]
		[% END %]
		
		<!-- process trees blocks, if any -->
		[% IF proj.get_forests.size > 0 %]
			<h1>Trees</h1>
			<!-- iterate over each trees block -->
			[% FOREACH forest = proj.get_forests %]
			
				<!-- write trees block metadata -->
				[% PROCESS identifiable obj = forest, tag = "h2" %]
				
				<!-- write trees block contents -->
				[% FOREACH tree = forest.get_entities %]
					[% PROCESS identifiable obj = tree, tag = "h3" %]
					<pre>[% tree.to_newick %]</pre>
				[% END %]
			[% END %]
		[% END %]
	</body>
</html>

[% BLOCK identifiable %]
	<[% tag %] id="[% obj.get_xml_id %]" class="[% obj.get_tag %]">
		<a name="[% obj.get_xml_id %]">
			[% IF obj.get_name %]
				[% obj.get_name %]
			[% END %]
		</a>
	</[% tag %]>
	[% PROCESS annotatable %]
[% END %]

[% BLOCK annotatable %]
	[% IF obj.get_meta.size > 0 %]
		<ul>
		[% FOREACH meta = obj.get_meta %]
			<li id="[% meta.get_xml_id %]" class="[% meta.get_tag %]">
				<a href="[% meta.get_predicate_namespace %][% meta.get_predicate_local %]" class="predicate">
					[% meta.get_predicate %]
				</a> = 
				[% IF meta.is_resource %]
					[% IF meta.is_xml_literal %]
						<pre class="xml_literal">[% meta.get_object %]</pre>
					[% ELSE %]
						<a href="[% meta.get_object %]" rel="[% meta.get_predicate %]" class="resource">
							[% meta.get_object %]
						</a>
					[% END %]
				[% ELSE %]
					<span class="[% meta.get_object_type %]">[% meta.get_object %]</span>
				[% END %]				
				[% PROCESS annotatable obj = meta %]
			</li>
		[% END %]
		</ul>
	[% END %]
[% END %]
