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
    $real_name =~ s![/\\]!;!g;    # replace directory separators
    $real_name =~ s![`’]+!'!g;     # normalize fancy quotes
    $real_name =~ s![\N{LEFT SINGLE QUOTATION MARK}\N{RIGHT SINGLE QUOTATION MARK}]!'!g;     # normalize fancy quotes
    $real_name =~ s/[!?:|"><]//g; # remove filesystem unsafe characters
    $real_name =~ s/[*]/_/g;      # replace filesystem unsafe characters
    $real_name =~ s/\s+/ /g;      # squash/normalize whitespace

    return $real_name
};

sub audio_info( $audiofile, $artist=undef, $album=undef ) {
    # Maybe this can take over MP3 too?
    my $tag = Music::Tag->new( $audiofile);

    $tag->get_tag;

    # Mush 03/10 into 03
    if( $tag->track =~ m!(\d+)\s*/\s*\d+$! ) {
        $tag->track( $1 );
    };

    my %info = map { $_ => $tag->$_() } qw(artist album track title duration);
    $info{ duration } ||= '-1000'; # "unknown" if we didn't find anything
    $audiofile =~ /\.(\w+)$/;
    $info{ ext } = lc $1;

    $info{ artist } //= $artist;
    $info{ album  } //= $album;
    $info{ track  } = sprintf '%02d', $info{ track };

    return \%info;
}

=head2 C<< build_name >>

  my $clean_name = build_name( 'foo.mp3', '${artist} - ${album} - ${track} - ${title}.${ext}' );
  rename 'foo.mp3' => $clean_name;

=cut

sub build_name( $audiofile, $pattern='${artist} - ${album} - ${track} - ${title}.${ext}',
                $artist=undef,
                $album=undef ) {
    my $real_name;
    my $info = audio_info( $audiofile, $artist, $album );
    $real_name = ($pattern =~ s!\$\{\s*(\w+)\s*\}!$info->{$1} // $1!gre);

    return $real_name
};

1;
