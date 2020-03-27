package File::Audio::CleanName;
use strict;
use warnings;
no warnings 'experimental';
use feature 'signatures';

use charnames ':full';
use Music::Tag 'traditional' => 1;

use Exporter 'import';
our @EXPORT_OK = (qw(sanitize build_name));

our $VERSION = '0.01';

sub sanitize( $pathname ) {
    my $real_name = $pathname;
    # Maybe we oughta use Text::Unidecode, but it does too much...
    $real_name =~ s![\N{EM DASH}
                     \N{EN DASH}
                     \N{HORIZONTAL BAR}
                     \N{FIGURE DASH}
                     \N{HYPHEN}
                     \N{NON-BREAKING HYPHEN}
                     \N{TWO-EM DASH}
                     \N{THREE-EM DASH}
                     \N{SMALL EM DASH}
                     ]
                   !-!gx;
    $real_name =~ s![/\\]!;!g;
    $real_name =~ s/[!?:|"><]//g;
    $real_name =~ s/[*]/_/g;
    $real_name =~ s/\s+/ /g;
    return $real_name
};

=head2 C<< build_name >>

  my $clean_name = build_name( 'foo.mp3', '${artist} - ${album} - ${track} - ${title}.${ext}' );
  rename 'foo.mp3' => $clean_name;

=cut

sub build_name( $audiofile, $pattern='${artist} - ${album} - ${track} - ${title}.${ext}',
                $artist=undef,
                $album=undef ) {
    my $real_name;
    # Maybe this can take over MP3 too?
    my $tag = Music::Tag->new( $audiofile);

    $tag->get_tag;

    # Mush 03/10 into 03
    if( $tag->track =~ m!(\d+)\s*/\s*\d+$! ) {
        $tag->track( $1 );
    };

    my %info = map { $_ => $tag->$_() } qw(artist album track title);
    $audiofile =~ /\.(\w+)$/;
    $info{ ext } = lc $1;

    $info{ artist } //= $artist;
    $info{ album  } //= $album;
    $info{ track  } = sprintf '%02d', $info{ track };
    $real_name = $pattern =~ s!\$\{\s*(\w+)\s*\}!$info{$1} // $1!gr;

    return $real_name
};

1;