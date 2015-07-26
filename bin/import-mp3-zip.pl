#!perl -w
use strict;
use Path::Class::Archive;
use File::Basename;

my $archivename = shift @ARGV;
my $ar = Path::Class::Archive->new(
    '7zip' => 'C:/Program Files/7-Zip/7z.exe',
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
    #print $entry->fileName,"\n";
    #print $entry->basename,"\n";
    
    my $target = join "/", $target_dir, $entry->basename;
    $ar->extractMember( $entry->fileName, $target );
};
