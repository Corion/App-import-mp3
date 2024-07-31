#!perl
use strict;
use warnings;
use Archive::SevenZip;
use File::Basename;
#use MP3::Tag;
use URI::file;
use Getopt::Long;
use Path::Class;
use File::Glob 'bsd_glob';
use File::Copy 'move';
use Encode 'encode', 'decode';
use File::HomeDir;
use File::Audio::CleanName 'sanitize', 'build_name';

no warnings 'experimental';
use feature 'signatures';

=head1 NAME

import-mp3-zip.pl - unpack and rename music files from archives

=head1 SYNOPSIS

  import-mp3-zip.pl ~/downloads/*.zip --target-base ~/music/ --archive-target ~/backup/

This program unpacks music files from archives and puts them in directories
named after the artist and album metadata extracted from the music files. The
archive files are then moved to a storage directory.

The 7zip program is needed for unpacking archives.

=cut

GetOptions(
    'v|verbose' => \my $verbose,
    't|target-base:s' => \my $target_base,
    'a|archive-target:s' => \my $archive_target,
);

our $VERSION = '0.01';

$ENV{HOME} ||= $ENV{HOMEPATH}; # just to silence a warning inside MP3::Tag on Windows

# Reglob on Windows
if( ! @ARGV) {
    my $download_dir;
    if( $^O =~ /mswin/i ) {
        $download_dir = # File::HomeDir->my_download
                        "$ENV{HOMEPATH}/Downloads";
        $download_dir =~ s!\\!/!g;
        @ARGV = "$download_dir/*_([0-9][0-9][0-9][0-9]).zip";
    } else {
        $download_dir = File::HomeDir::FreeDesktop->my_download;
    };
    @ARGV = "$download_dir/*_([0-9][0-9][0-9][0-9]).zip";
};
@ARGV = map { -f $_ ? $_ : bsd_glob( $_ ) } @ARGV;


sub import_file( $archivename ) {
    my $ar = Archive::SevenZip->new(
        find => 1,
        archivename => $archivename,
        verbose => $verbose,
    );

    my $name = basename $archivename;
    $name =~ s!_! !g;
    $name =~ /(.*?) - (.*?)\((\d+)\)/ or die "No music names found in '$archivename'";
    my ($artist, $album) = ($1,$2);
    s/\s*$// for ($artist, $album);
    $album =~ s!\s*\(Deluxe Edition\)$!!;
    if( $^O ne 'MSWin32' ) {
        $_ = decode('UTF-8', $_)
            for ($artist,$album);
    };

    print sanitize( "$artist - $album" ) . "\n";

    my $subdir;
    if( -d dir( $target_base, sanitize( $artist ) )) {
        $subdir = dir( sanitize( $artist ), sanitize( "$artist - $album" ));
    } else {
        $subdir = sanitize( "$artist - $album" )
    };
    my $target_dir = dir( $target_base, $subdir );
    if( ! -d $target_dir ) {
        mkdir $target_dir
            or die "Couldn't create '$target_dir': $!";
    };

    my @playlist;
    for my $entry ( $ar->list ) {
        my $target = join "/", "$target_dir", sanitize( $entry->basename );

        if( $^O =~ /mswin/i ) {
            $target = encode('Latin-1', $target);
        };
        #local $ar->{verbose} = 1;
        print sprintf "Extracting %s\n", $entry->fileName;
        $ar->extractMember( decode('UTF-8',$entry->fileName), $target);

        if( $target =~ /\.(jpg|jpeg|png)$/i ) {
            my $albumartname = file( $target_dir, "cover.".lc $1);
            rename $target => $albumartname
                or die "Couldn't rename $target to $albumartname: $!";
            next
        };

        my $real_name = build_name( $target,
                                    '${artist} - ${album} - ${track} - ${title}.${ext}',
                                    $artist, $album );

        # read information before copying to target, for speed
        my $info = File::Audio::CleanName::audio_info($target);

        my $mp3name = file( $target_dir, sanitize( $real_name ));
        $info->{url} = basename $mp3name;

        if( $mp3name ne $target ) {
            rename $target => encode('UTF-8', $mp3name)
                or warn "Couldn't rename '$target' to '$mp3name': $!"
        };
        push @playlist, $info;
    };

    undef $ar; # just in case we should hold open filehandles in $ar
    my $target = file($archive_target, basename( $archivename ));
    move($archivename => $target)
        or warn "Couldn't rename $archivename to $target: $!";

    # Create m3u8 for the album from the tracks in @playlist
    @playlist = sort {
                          $a->{track} <=> $b->{track}
                       || $a->{artist} cmp $b->{artist}
                       || $a->{title}  cmp $b->{title}
                     } @playlist;
    my $playlist_file = file( $target_dir, sanitize( "$artist - $album" ) . ".m3u8" );
    $playlist_file->spew( create_playlist( @playlist ));
};

for my $url_or_file (@ARGV ) {
    my $file;
    if( $url_or_file =~/^file:/ ) {
        $file = URI::file->new( $url_or_file )->file;
    } else {
        $file = $url_or_file;
    };

    next unless -s $file;

    import_file( $file );
}

sub create_playlist( @urls ) {
    my @lines=( '#EXTM3U','#EXTENC: UTF-8' );

    #if( my $cover = $directory->album_art ) {
    #    push @lines, "#EXTIMG:" . basename( $cover->name );
    #};

    push @lines,
        '#PLAYLIST ' . $urls[0]->{album};

    push @lines,
        map {;
            my $duration = int( $_->{duration} / 1000 );
            my $title = ($_->{title} =~ s!\s*,\s*! !r);
            (
                # Yes, a double comma, so $_->{title} can contain a comma, for SMPlayer
                "#EXTINF:$duration,$title",
                "#EXTALB:$_->{album}",
                "#EXTART:$_->{artist}",
                $_->{url},
            )
        } @urls;
    return join "\n", @lines;
};
