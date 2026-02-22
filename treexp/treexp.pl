#!/usr/bin/env perl
use strict;
use warnings;
use open ":encoding(UTF-8)", ":std";
use feature "state";
use constant true => 1;
use constant false => 0;
# use constant _ => undef;

use File::Path; # make_path, remove_tree

sub ERR {
    my ($msg) = @_;
    print STDERR "$msg\n";
    exit 1;
}

sub prompt_confirm {
    my ($msg) = @_;
    print STDERR "$msg\nConfirm?(Y/n) >";
    my $confirm = <STDIN>;
    if ($confirm =~ /n|N/) {
        print STDERR "Aborted\n";
        exit 2;
    }
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

sub CHMOD_X_ERR {
    my ($file, $chmod_x_err) = @_;
    ERR("Could not chmod +x file `$file`: $chmod_x_err");
}

sub treexp {
    my ($dir, $out_fh, $cwd) = @_;
    state $first_file = true;
    $cwd //= "."; # basically if parent treexp() call (<> recursive call)

    opendir(my $dh, $dir) or OPEN_DIR_ERR($dir, $!);
    my @files = sort readdir($dh);
    closedir($dh);

    foreach my $file (@files) {
        next if $file eq "." || $file eq ".." || $file eq ".git";
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
                $content .= "\t$line";
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
            if ($content =~ /\n$/) {
                print $out_fh "\n$content";
            }
            else {
                print $out_fh "*\n$content\n";
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

# returns a file handler (will create all the intermediary dirs as needed)
sub createfile {
    my ($file) = @_;
    # make sure we have both a dirname AND a basename (otherwise => die)
    my ($dirname, $basename) = $file =~ /(\S+\/)([^\/\s]+)$/ or die;
    File::Path::make_path($dirname); # <=> mkdir -p
    open my $fh, '>', $file or OPEN_FILE_ERR($file, $!);
    return $fh;
}

sub buildtree {
    my ($input_fh, $out_dir) = @_;
    mkdir($out_dir);
    chdir($out_dir); # because paths in file are relative to dir (and start with `./`)

    while (my $line = <$input_fh>) {
        chomp $line;

        if ($line =~ /^(\S+) -> (\S+)$/) {
            my $symlink = $1;
            my $target = $2;

            symlink($target, $symlink);
        }

        elsif ($line =~ /^(\S+)( \+x)? (\d+\*?)$/) {
            my $textfile = $1;
            my $is_executable = $2;
            my ($nb_of_lines, $has_trailing_nl) = substr($3, -1) eq "*"?
                    (0 + substr($3, 0, -1), false) : (0 + $3, true);

            my $out_fh = createfile($textfile);
            for my $nth (1 .. $nb_of_lines) {
                my $line = <$input_fh>;
                defined $line or ERR("Hit EOF before reaching nb of lines");
                $line =~ s/^\t// or die; # remove leading \t
                if ($nth == $nb_of_lines && !$has_trailing_nl) {
                    $line =~ s/\n$// or die; # remove trailing \n
                }
                print $out_fh $line;
            }
            close $out_fh;

            if ($is_executable) {
                chmod 0755, $textfile or CHMOD_X_ERR($textfile, $!); # <=> chmod +x
            }
        }

        elsif ($line =~ /\s*/) {
            ; # nothing to do
        }

        else {
            ERR("Invalid pattern on line `$line`\n");
        }
    }
}

@ARGV or ERR("Missing input argument");
my $ARG = shift @ARGV;
-e $ARG or ERR("`$ARG` do not exist");

# dispatching based on the type of the file arg
#
# treexp() is a recursive function (needs to treewalk)
# ..as opposed to buildtree()

if (-d $ARG) {
    (my $dir = $ARG) =~ s/(\S+?)\/*$/$1/ or die; # remove trailing slashes
    my $outfile = "$dir.txt";
    if (-e $outfile) {
        if (-d $outfile) {
            prompt_confirm("Output file `$outfile/` already exists, are you sure you want to nuke it?");
            File::Path::remove_tree($outfile); # <=> rm -rf
        }
        else {
            prompt_confirm("Output file `$outfile` already exists, are you sure you want to overwrite it?");
        }
    }
    open my $out_fh, ">", $outfile or OPEN_FILE_ERR($outfile, $!);
    treexp($dir, $out_fh);
    close($out_fh);
}

elsif (-f $ARG) {
    -T $ARG or ERR("File arg is not a text file");
    my $textfile = $ARG;
    my ($out_dir) = $textfile =~ /(\S*[^\/\s])\.txt$/ or ERR("File arg doesn't match xxx.txt");
    if (-e $out_dir) {
        if (-d $out_dir) {
            prompt_confirm("Output dir `$out_dir` already exists, are you sure you want to nuke it?");
            File::Path::remove_tree($out_dir); # <=> rm -rf
        }
        else {
            prompt_confirm("Output file `$out_dir` already exists, are you sure you want to nuke it?");
            unlink $out_dir; # <=> rm # doesn't work on dirs
        }
    }

    open my $input_fh, "<", $textfile or OPEN_FILE_ERR($textfile, $!);
    buildtree($input_fh, $out_dir);
    close $input_fh;
}

else {
    ERR("Arg should be either a dir (for exporting) or a file (for building)");
}
