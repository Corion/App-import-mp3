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

    for my $entry ( $ar->list ) {
        my $target = join "/", "$target_dir", sanitize( $entry->basename );

        if( $^O =~ /mswin/i ) {
            $target = encode('Latin-1', $target);
        };
        #local $ar->{verbose} = 1;
        $ar->extractMember( $entry->fileName, $target);

        my $real_name = build_name( $target,
                                    '${artist} - ${album} - ${track} - ${title}.${ext}',
                                    $artist, $album );
        my $mp3name = file( $target_dir, sanitize( $real_name ));
        if( $mp3name ne $target ) {
            rename $target => $mp3name
                or die "Couldn't rename $target to $mp3name: $!"
        };
    };

    undef $ar; # just in case we should hold open filehandles in $ar
    my $target = file($archive_target, basename( $archivename ));
    move($archivename => $target)
        or warn "Couldn't rename $archivename to $target: $!";
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
