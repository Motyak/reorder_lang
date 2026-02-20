#!/usr/bin/env perl
use strict;
use warnings;
use open ":encoding(UTF-8)", ":std";
use feature "state";
use constant true => 1;
use constant false => 0;
# use constant _ => undef;

sub ERR {
    my ($msg) = @_;
    print STDERR "${msg}\n";
    exit 1;
}

sub CD_DIR_ERR {
    my ($dir, $cd_err) = @_;
    ERR("Could not cd into dir `$dir`: $cd_err");
}

sub OPEN_DIR_ERR {
    my ($dir, $open_err) = @_;
    ERR("Could not open dir `$dir`: $open_err");
}

sub OPEN_FILE_ERR {
    my ($file, $open_err) = @_;
    ERR("Could not open file `$file`: $open_err");
}

sub treexp {
    my ($dir, $out_fh, $cwd) = @_;
    state $first_file = true;
    $cwd //= "."; # parent call
    opendir(my $dh, $dir) or OPEN_DIR_ERR($dir, $!);
    my @files = sort readdir($dh);
    closedir($dh);

    foreach my $file (@files) {
        next if $file eq "." || $file eq "..";
        my $filepath = "$dir/$file";

        # symlink
        if (-l $filepath) {
            my $target = readlink($filepath);
            if (!$first_file) {
                print $out_fh "\n"; # extra newline for readability
            }
            print $out_fh "$cwd/$file -> $target\n";
            $first_file = false;
        }
        # fifo (could match -T so it needs to precede it)
        # ..or socket or block/character special
        elsif (-p $filepath || -S $filepath || -b $filepath || -c $filepath) {
            ; # nothing to do
        }
        # text file
        elsif (-T $filepath) {
            open my $fh, "<", $filepath or OPEN_FILE_ERR($filepath, $!);
            my $content = "";
            my $nb_of_lines = 0;
            while (my $line = <$fh>) {
                $content .= $line;
                $nb_of_lines += 1;
            }
            close $fh;

            if (!$first_file) {
                print $out_fh "\n"; # extra newline for readability
            }
            print $out_fh "$cwd/$file";
            if (-x $filepath) {
                print $out_fh " +x";
            }
            print $out_fh " $nb_of_lines";
            if (length($content) != 0 && substr($content, -1) ne "\n") {
                print $out_fh "*\n$content\n";
            }
            else {
                print $out_fh "\n$content";
            }
            $first_file = false;
        }
        # dir
        elsif (-d $filepath) {
            treexp($filepath, $out_fh, "$cwd/$file");
        }
        else {
            # a binary file, most likely
            ; # do nothing
        }
    }
}

sub buildtree {
    my ($file) = @_;
    # TODO
}

@ARGV or ERR("Missing input argument");
my $ARG = shift @ARGV;
-e $ARG or ERR("`$ARG` do not exist");

# dispatching based on the type of the file arg
#
# treexp() is a recursive function (needs to treewalk)
# ..as opposed to buildtree()

if (-d $ARG) {
    my $dir = $ARG;
    my $outfile = "$dir.txt";
    # if (-e $outfile) {
    #     ERR("Output file `$outfile` already exists");
    # }
    open my $fh, ">", $outfile or OPEN_FILE_ERR($outfile, $!);
    treexp($dir, $fh);
    close($fh);
}

elsif (-f $ARG) {
    my $file = $ARG;
    buildtree($file);
}

else {
    ERR("Arg should be either a dir (for exporting) or a file (for building)");
}
