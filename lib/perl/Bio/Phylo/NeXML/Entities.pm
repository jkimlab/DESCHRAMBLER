package Bio::Phylo::NeXML::Entities;
use strict;
use warnings;
use base 'Exporter';
our @EXPORT_OK = qw'encode_entities decode_entities';

my %entity2char = (
    # Some normal chars that have special meaning in SGML context
    '&amp;'   => '&',  # ampersand 
    '&gt;'    => '>',  # greater than
    '&lt;'    => '<',  # less than
    '&quot;'  => '"',  # double quote
    '&apos;'  => "'",  # single quote
    
	# PUBLIC ISO 8879-1986//ENTITIES Added Latin 1//EN//HTML
	'&#198;' => chr(198), # capital AE diphthong (ligature)
	'&#193;' => chr(193), # capital A, acute accent
	'&#194;' => chr(194), # capital A, circumflex accent
	'&#192;' => chr(192), # capital A, grave accent
	'&#197;' => chr(197), # capital A, ring
	'&#195;' => chr(195), # capital A, tilde
	'&#196;' => chr(196), # capital A, dieresis or umlaut mark
	'&#199;' => chr(199), # capital C, cedilla
	'&#208;' => chr(208), # capital Eth, Icelandic
	'&#201;' => chr(201), # capital E, acute accent
	'&#202;' => chr(202), # capital E, circumflex accent
	'&#200;' => chr(200), # capital E, grave accent
	'&#203;' => chr(203), # capital E, dieresis or umlaut mark
	'&#205;' => chr(205), # capital I, acute accent
	'&#206;' => chr(206), # capital I, circumflex accent
	'&#204;' => chr(204), # capital I, grave accent
	'&#207;' => chr(207), # capital I, dieresis or umlaut mark
	'&#209;' => chr(209), # capital N, tilde
	'&#211;' => chr(211), # capital O, acute accent
	'&#212;' => chr(212), # capital O, circumflex accent
	'&#210;' => chr(210), # capital O, grave accent
	'&#216;' => chr(216), # capital O, slash
	'&#213;' => chr(213), # capital O, tilde
	'&#214;' => chr(214), # capital O, dieresis or umlaut mark
	'&#222;' => chr(222), # capital THORN, Icelandic
	'&#218;' => chr(218), # capital U, acute accent
	'&#219;' => chr(219), # capital U, circumflex accent
	'&#217;' => chr(217), # capital U, grave accent
	'&#220;' => chr(220), # capital U, dieresis or umlaut mark
	'&#221;' => chr(221), # capital Y, acute accent
	'&#225;' => chr(225), # small a, acute accent
	'&#226;' => chr(226), # small a, circumflex accent
	'&#230;' => chr(230), # small ae diphthong (ligature)
	'&#224;' => chr(224), # small a, grave accent
	'&#229;' => chr(229), # small a, ring
	'&#227;' => chr(227), # small a, tilde
	'&#228;' => chr(228), # small a, dieresis or umlaut mark
	'&#231;' => chr(231), # small c, cedilla
	'&#233;' => chr(233), # small e, acute accent
	'&#234;' => chr(234), # small e, circumflex accent
	'&#232;' => chr(232), # small e, grave accent
	'&#240;' => chr(240), # small eth, Icelandic
	'&#235;' => chr(235), # small e, dieresis or umlaut mark
	'&#237;' => chr(237), # small i, acute accent
	'&#238;' => chr(238), # small i, circumflex accent
	'&#236;' => chr(236), # small i, grave accent
	'&#239;' => chr(239), # small i, dieresis or umlaut mark
	'&#241;' => chr(241), # small n, tilde
	'&#243;' => chr(243), # small o, acute accent
	'&#244;' => chr(244), # small o, circumflex accent
	'&#242;' => chr(242), # small o, grave accent
	'&#248;' => chr(248), # small o, slash
	'&#245;' => chr(245), # small o, tilde
	'&#246;' => chr(246), # small o, dieresis or umlaut mark
	'&#223;' => chr(223), # small sharp s, German (sz ligature)
	'&#254;' => chr(254), # small thorn, Icelandic
	'&#250;' => chr(250), # small u, acute accent
	'&#251;' => chr(251), # small u, circumflex accent
	'&#249;' => chr(249), # small u, grave accent
	'&#252;' => chr(252), # small u, dieresis or umlaut mark
	'&#253;' => chr(253), # small y, acute accent
	'&#255;' => chr(255), # small y, dieresis or umlaut mark
	
	# Some extra Latin 1 chars that are listed in the HTML3.2 draft (21-May-96)
	'&#169;' => chr(169), # copyright sign
	'&#174;' => chr(174), # registered sign
	'&#160;' => chr(160), # non breaking space
	
	# Additional ISO-8859/1 entities listed in rfc1866 (section 14)
	'&#161;' => chr(161),
	'&#162;' => chr(162),
	'&#163;' => chr(163),
	'&#164;' => chr(164),
	'&#165;' => chr(165),
	'&#166;' => chr(166),
	'&#167;' => chr(167),
	'&#168;' => chr(168),
	'&#170;' => chr(170),
	'&#171;' => chr(171),
	'&#172;' => chr(172),
	'&#173;' => chr(173),
	'&#175;' => chr(175),
	'&#176;' => chr(176),
	'&#177;' => chr(177),
	'&#185;' => chr(185),
	'&#178;' => chr(178),
	'&#179;' => chr(179),
	'&#180;' => chr(180),
	'&#181;' => chr(181),
	'&#182;' => chr(182),
	'&#183;' => chr(183),
	'&#184;' => chr(184),
	'&#186;' => chr(186),
	'&#187;' => chr(187),
	'&#188;' => chr(188),
	'&#189;' => chr(189),
	'&#190;' => chr(190),
	'&#191;' => chr(191),
	'&#215;' => chr(215),
	'&#247;' => chr(247),
	'&#338;' => chr(338),
	'&#339;' => chr(339),
	'&#352;' => chr(352),
	'&#353;' => chr(353),
	'&#376;' => chr(376),
	'&#402;' => chr(402),
	'&#710;' => chr(710),
	'&#732;' => chr(732),
	'&#913;' => chr(913),
	'&#914;' => chr(914),
	'&#915;' => chr(915),
	'&#916;' => chr(916),
	'&#917;' => chr(917),
	'&#918;' => chr(918),
	'&#919;' => chr(919),
	'&#920;' => chr(920),
	'&#921;' => chr(921),
	'&#922;' => chr(922),
	'&#923;' => chr(923),
	'&#924;' => chr(924),
	'&#925;' => chr(925),
	'&#926;' => chr(926),
	'&#927;' => chr(927),
	'&#928;' => chr(928),
	'&#929;' => chr(929),
	'&#931;' => chr(931),
	'&#932;' => chr(932),
	'&#933;' => chr(933),
	'&#934;' => chr(934),
	'&#935;' => chr(935),
	'&#936;' => chr(936),
	'&#937;' => chr(937),
	'&#945;' => chr(945),
	'&#946;' => chr(946),
	'&#947;' => chr(947),
	'&#948;' => chr(948),
	'&#949;' => chr(949),
	'&#950;' => chr(950),
	'&#951;' => chr(951),
	'&#952;' => chr(952),
	'&#953;' => chr(953),
	'&#954;' => chr(954),
	'&#955;' => chr(955),
	'&#956;' => chr(956),
	'&#957;' => chr(957),
	'&#958;' => chr(958),
	'&#959;' => chr(959),
	'&#960;' => chr(960),
	'&#961;' => chr(961),
	'&#962;' => chr(962),
	'&#963;' => chr(963),
	'&#964;' => chr(964),
	'&#965;' => chr(965),
	'&#966;' => chr(966),
	'&#967;' => chr(967),
	'&#968;' => chr(968),
	'&#969;' => chr(969),
	'&#977;' => chr(977),
	'&#978;' => chr(978),
	'&#982;' => chr(982),
	'&#8194;' => chr(8194),
	'&#8195;' => chr(8195),
	'&#8201;' => chr(8201),
	'&#8204;' => chr(8204),
	'&#8205;' => chr(8205),
	'&#8206;' => chr(8206),
	'&#8207;' => chr(8207),
	'&#8211;' => chr(8211),
	'&#8212;' => chr(8212),
	'&#8216;' => chr(8216),
	'&#8217;' => chr(8217),
	'&#8218;' => chr(8218),
	'&#8220;' => chr(8220),
	'&#8221;' => chr(8221),
	'&#8222;' => chr(8222),
	'&#8224;' => chr(8224),
	'&#8225;' => chr(8225),
	'&#8226;' => chr(8226),
	'&#8230;' => chr(8230),
	'&#8240;' => chr(8240),
	'&#8242;' => chr(8242),
	'&#8243;' => chr(8243),
	'&#8249;' => chr(8249),
	'&#8250;' => chr(8250),
	'&#8254;' => chr(8254),
	'&#8260;' => chr(8260),
	'&#8364;' => chr(8364),
	'&#8465;' => chr(8465),
	'&#8472;' => chr(8472),
	'&#8476;' => chr(8476),
	'&#8482;' => chr(8482),
	'&#8501;' => chr(8501),
	'&#8592;' => chr(8592),
	'&#8593;' => chr(8593),
	'&#8594;' => chr(8594),
	'&#8595;' => chr(8595),
	'&#8596;' => chr(8596),
	'&#8629;' => chr(8629),
	'&#8656;' => chr(8656),
	'&#8657;' => chr(8657),
	'&#8658;' => chr(8658),
	'&#8659;' => chr(8659),
	'&#8660;' => chr(8660),
	'&#8704;' => chr(8704),
	'&#8706;' => chr(8706),
	'&#8707;' => chr(8707),
	'&#8709;' => chr(8709),
	'&#8711;' => chr(8711),
	'&#8712;' => chr(8712),
	'&#8713;' => chr(8713),
	'&#8715;' => chr(8715),
	'&#8719;' => chr(8719),
	'&#8721;' => chr(8721),
	'&#8722;' => chr(8722),
	'&#8727;' => chr(8727),
	'&#8730;' => chr(8730),
	'&#8733;' => chr(8733),
	'&#8734;' => chr(8734),
	'&#8736;' => chr(8736),
	'&#8743;' => chr(8743),
	'&#8744;' => chr(8744),
	'&#8745;' => chr(8745),
	'&#8746;' => chr(8746),
	'&#8747;' => chr(8747),
	'&#8756;' => chr(8756),
	'&#8764;' => chr(8764),
	'&#8773;' => chr(8773),
	'&#8776;' => chr(8776),
	'&#8800;' => chr(8800),
	'&#8801;' => chr(8801),
	'&#8804;' => chr(8804),
	'&#8805;' => chr(8805),
	'&#8834;' => chr(8834),
	'&#8835;' => chr(8835),
	'&#8836;' => chr(8836),
	'&#8838;' => chr(8838),
	'&#8839;' => chr(8839),
	'&#8853;' => chr(8853),
	'&#8855;' => chr(8855),
	'&#8869;' => chr(8869),
	'&#8901;' => chr(8901),
	'&#8968;' => chr(8968),
	'&#8969;' => chr(8969),
	'&#8970;' => chr(8970),
	'&#8971;' => chr(8971),
	'&#9001;' => chr(9001),
	'&#9002;' => chr(9002),
	'&#9674;' => chr(9674),
	'&#9824;' => chr(9824),
	'&#9827;' => chr(9827),
	'&#9829;' => chr(9829),
	'&#9830;' => chr(9830),
);

# Make the opposite mapping
my %char2entity = map { $entity2char{$_} => $_ } keys %entity2char;

# Fill in missing entities
#for (0 .. 255) {
#    next if exists $char2entity{chr($_)};
#    $char2entity{chr($_)} = "&#$_;";
#}

sub encode_entities {
    my ( $string, $chars ) = @_;
    my %escape;
    if ( $chars ) {
        %escape = map { $_ => 1 } split //, $chars;
    }
    else {
        %escape = map { $_ => 1 } keys %char2entity;
    }
    my @string = split //, $string;
    for my $i ( 0 .. $#string ) {
        my $c = $string[$i];
        if ( $escape{$c} and $c ne '&' and $c ne ';' ) {
            $string[$i] = $char2entity{$c};
        }
        elsif ( $escape{$c} and $c eq '&' ) {
            my $maybe_entity = '';
            FIND_SEMI: for my $j ( $i .. $#string ) {
                $maybe_entity .= $string[$j];
                last FIND_SEMI if $string[$j] eq ';';
            }
            if ( not exists $entity2char{$maybe_entity} ) {
                $string[$i] = $char2entity{$c};
            }
        }
        elsif( $escape{$c} and $c eq ';' ) {
            my $maybe_entity = '';
            FIND_AMP: for ( my $j = $i; $j >= 0; $j-- ) {
                $maybe_entity = $string[$j] . $maybe_entity;
                last FIND_SEMI if $string[$j] eq '&';                
            }
            if ( not exists $entity2char{$maybe_entity} ) {
                $string[$i] = $char2entity{$c};
            }
        }
    }
    return join '', @string;
}

sub decode_entities {
    my @results;
    for my $string ( @_ ) {
        my @string = split //, $string;
        for my $i ( 0 .. $#string ) {
            my $c = $string[$i];
            if ( $c eq '&' ) {
                my $maybe_entity = '';
                my $length = 0;
                FIND_SEMI: for my $j ( $i .. $#string ) {
                    $maybe_entity .= $string[$j];
                    last FIND_SEMI if $string[$j] eq ';';
                    $length++;
                }
                if ( exists $entity2char{$maybe_entity} ) {
                    $string[$i] = $entity2char{$maybe_entity};
                    splice( @string, $i + 1, $length );
                }                
            }
        }
        push @results, join '', @string;
    }
    return wantarray ? @results : $results[0];
}

1;

__END__

=head1 NAME

Bio::Phylo::NeXML::Entities - Functions for dealing with XML entities

=head1 DESCRIPTION

This package provides subroutines for dealing with characters that need to be
encoded as XML entities, and decoded in other formats. For example: C<&> needs
to be encoded as C<&amp;> in XML. The subroutines have the same signatures and
the same names as those in the commonly-used module L<HTML::Entities>. They are
re-implemented here to avoid introducing dependencies.

=head1 SUBROUTINES

The following subroutines are utility functions that can be imported using:

 use Bio::Phylo::NeXML::Entities '/entities/';

=over

=item encode_entities

Encodes problematic characters as XML entities

 Type    : Utility function
 Title   : encode_entities
 Usage   : my $encoded = encode_entities('string with & or >','>&')
 Function: Encodes entities in first argument string
 Returns : Modified string
 Args    : Required, first argument: a string to encode
           Optional, second argument: a string that specifies
           which characters to encode

=item decode_entities

Decodes XML entities into the characters they code for

 Type    : Utility function
 Title   : decode_entities
 Usage   : my $decoded = decode_entities('string with &amp; or &gt;')
 Function: decodes encoded entities in argument string(s)
 Returns : Array of decoded strings
 Args    : One or more encoded strings

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

