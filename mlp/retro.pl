#!/usr/bin/env perl
use strict;
use warnings;
use constant true => 1;
use constant false => 0;
binmode(STDOUT, ":utf8");

my $CMD = "$0" . " " x (@ARGV > 0) . join(" ", @ARGV);

sub ERR {
    my ($msg) = @_;
    print STDERR "${msg}\n";
    print STDERR "  \$ ${CMD}\n";
    exit 1;
}

sub OPEN_FILE_ERR {
    my ($file, $open_err) = @_;
    ERR("Could not open file `$file`: $open_err");
}

@ARGV or ERR("Missing ml file argument");
my $ML_FILE = shift @ARGV;
@ARGV or ERR("Missing mlp file argument");
my $MLP_FILE = shift @ARGV;

# file => content
my %content = ($MLP_FILE => "");

# stack of "current file"
my @curr_file_stack = ($MLP_FILE);

my $curr_file = $curr_file_stack[-1];
my $LF_after_begin = false;

open my $fh, "<:encoding(UTF-8)", $ML_FILE or OPEN_FILE_ERR($ML_FILE, $!);
while (my $line = <$fh>) {
    chomp $line;

    if ($line =~ /^"=== mlp: BEGIN (\S+)/) {
        $curr_file = $1;
        push @curr_file_stack, $curr_file;
        $content{$curr_file} = "";
        $LF_after_begin = true;
    }

    elsif ($LF_after_begin) {
        ; # discard the line
        $LF_after_begin = false;
    }

    elsif ($line =~ /^"=== mlp: END /) {
        pop(@curr_file_stack);
        @curr_file_stack or die();
        $curr_file = $curr_file_stack[-1]
    }

    else {
        $content{$curr_file} .= "$line\n"
    }
}
close $fh;

my $ML_FILE_MTIME = (stat $ML_FILE)[9];
# need to set its own mtime with utime
# (because utime is second-precision only)
utime -1, $ML_FILE_MTIME, $ML_FILE;

my $err_msg = "";

for my $file (keys %content) {
    my @content_file_lines = split "\n", $content{$file};
    my $new_content = "";

    if (-f $file) {
        if ((stat $file)[9] > $ML_FILE_MTIME) {
            $err_msg .= "- `$file` is newer than `$ML_FILE` => SKIP\n";
            next;
        }

        elsif ((stat $file)[9] == $ML_FILE_MTIME) {
            utime -1, $ML_FILE_MTIME, $file;
            next; # nothing to do
        }
    }

    if (open my $fh, "+<:encoding(UTF-8)", $file) {
        while (my $line = <$fh>) {
            chomp $line;

            if ($line =~ /^include <(\S+)>$/) {
                $new_content .= "$line\n";
            }

            else {
                @content_file_lines or die();
                $new_content .= shift(@content_file_lines) . "\n";
            }
        }

        truncate($fh, 0);
        seek($fh, 0, 0);
        print $fh $new_content;

        close $fh;
        utime -1, $ML_FILE_MTIME, $file;
    }
    else {
        $err_msg .= "- Could not open file `$file`: $!\n";
    }
}

if ($err_msg) {
    print($err_msg);
    print("Use 'mlp diff' and/or 'mlp' to mitigate this\n")
}
