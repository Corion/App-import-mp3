#!perl -w
use strict;
use Archive::SevenZip;
use File::Basename;
use MP3::Tag;

my $archivename = shift @ARGV;

my $ar = Archive::SevenZip->new(
    find => 1,
    archivename => $archivename,
);

my $name = basename $archivename;
$name =~ s!_! !g;
$name =~ /(.*?) - (.*?)\((\d+)\)/ or die "No music names found";
my ($artist, $album) = ($1,$2);
s/\s*$// for ($artist, $album);

my $target_dir = "\\\\aliens\\media\\mp3\\$artist - $album";
if( ! -d $target_dir ) {
    mkdir $target_dir
        or die "Couldn't create '$target_dir': $!";
};

for my $entry ( $ar->list ) {
    my $target = join "/", $target_dir, $entry->basename;
    $ar->extractMember( $entry->fileName, $target );
    
    # Rename
    my $tag = MP3::Tag->new( $target );

    # ($title, $track, $artist, $album, $comment, $year, $genre)
    my @info = $tag->autoinfo;
    my $real_name = sprintf "%s - %s - %02d - %s.mp3",
        @info[2,3,1,0];
    undef $tag; # to release the filehandle kept open...

    $real_name =~ s![/\\]!;!g;
    $real_name =~ s/[?:]//g;
    my $mp3name = "$target_dir/$real_name";
    rename $target => $mp3name
        or die "Couldn't rename $target to $mp3name: $!"
};
