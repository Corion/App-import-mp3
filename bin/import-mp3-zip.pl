#!perl -w
use strict;
use Archive::SevenZip;
use File::Basename;
use MP3::Tag;
use Music::Tag 'traditional' => 1;
use URI::file;
use Getopt::Long;
use Path::Class;
use File::Glob 'bsd_glob';

no warnings 'experimental';
use feature 'signatures';

GetOptions(
    'v|verbose' => \my $verbose,
    't|target-base' => \my $target_base,
);

# Reglob on Windows
if( ! @ARGV) {
    my $dir = "$ENV{HOMEPATH}/Downloads";
    $dir =~ s!\\!/!g;
    @ARGV = "$dir/*_([0-9][0-9][0-9][0-9]).zip";
};
@ARGV = map { -f $_ ? $_ : bsd_glob( $_ ) } @ARGV;

$target_base ||= "\\\\aliens\\media\\mp3";

sub sanitize( $pathname ) {
    my $real_name = $pathname;
    $real_name =~ s![/\\]!;!g;
    $real_name =~ s/[?:|]//g;
    $real_name =~ s/[*]/_/g;
    return $real_name
};

sub import_file( $archivename ) {
    my $ar = Archive::SevenZip->new(
        find => 1,
        archivename => $archivename,
        verbose => $verbose,
    );

    my $name = basename $archivename;
    $name =~ s!_! !g;
    $name =~ /(.*?) - (.*?)\((\d+)\)/ or die "No music names found";
    my ($artist, $album) = ($1,$2);
    s/\s*$// for ($artist, $album);
    $album =~ s!\s*\(Deluxe Edition\)$!!;
    
    print "$artist - $album\n";

    my $subdir;
    if( -d dir( $target_base, $artist ) ) {
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
        my $target = join "/", "$target_dir", $entry->basename;
        $ar->extractMember( $entry->fileName, $target );
        
        my $real_name;
        if( $target =~ /\.mp3$/i ) {
            my $tag = MP3::Tag->new( $target );

            # ($title, $track, $artist, $album, $comment, $year, $genre)
            my @info = $tag->autoinfo;
            if( $info[1] =~ m!(\d+)\s*/\s*\d+$! ) {
                $info[1] = $1;
            };
            $real_name = sprintf "%s - %s - %02d - %s.mp3",
                @info[2,3,1,0];

        } elsif( $target =~ /\.flac$/i ) {
            # Maybe this can take over MP3 too?
            my $tag = Music::Tag->new( $target);

            $tag->get_tag;
            if( $tag->track =~ m!(\d+)\s*/\s*\d+$! ) {
                $tag->track( $1 );
            };
            
            my %info = map { $_ => $tag->$_() } qw(artist album track title);
            $info{ artist } //= $artist;
            $info{ album  } //= $album;
            $real_name = sprintf "%s - %s - %02d - %s.flac",
                $info{ artist }, $info{ album }, $info{ track }, $info{ title };
        };

        my $mp3name = file( $target_dir, sanitize( $real_name ));
        rename $target => $mp3name
            or die "Couldn't rename $target to $mp3name: $!"
    };
    
    undef $ar; # just in case we should hold open filehandles in $ar
    my $target = file('d:/Music/', basename( $archivename ));
    rename($archivename => $target)
        or warn "Couldn't rename $archivename to $target: $!";
};

for my $url_or_file (@ARGV ) { 
    my $file;
    if( $url_or_file =~/^file:/ ) {
        $file = URI::file->new( $url_or_file )->file;
    } else {
        $file = $url_or_file;
    };
    import_file( $file );
}
