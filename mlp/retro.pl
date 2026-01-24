#!/usr/bin/env perl
use strict;
use warnings;
use open ":encoding(UTF-8)", ":std";
use constant true => 1;
use constant false => 0;

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

my @INCLUDE_PATH = ();

{
    my $include_arg = false;
    foreach my $arg (@ARGV) {
        if ($include_arg) {
            push(@INCLUDE_PATH, $arg);
            $include_arg = false;
        }
        elsif ($arg =~ /^-I$/) {
            $include_arg = true;
        }
        else {
            ERR("Unknown option/argument: `$arg`");
        }
    }
}

unless (@INCLUDE_PATH) {
    push(@INCLUDE_PATH, ".");
}

sub short_name {
    my ($dirs, $included_file) = @_;
    (my $dirname = $included_file) =~ s/^([^\/]+)\//$1/ or die();

    foreach my $dir (@$dirs) {
        (my $basename = $dir) =~ s/\/*([^\/]+)\/*$/$1/ or die();
        if ($included_file =~ /^\Q${basename}\E\/(.*)/) {
            return $1;
        }
    }

    return $included_file;
}

# file => content
my %content = ($MLP_FILE => "");

# stack of "current file"
my @curr_file_stack = ($MLP_FILE);

my $curr_file = $curr_file_stack[-1];
my $LF_after_begin = false;

open my $fh, "<", $ML_FILE or OPEN_FILE_ERR($ML_FILE, $!);
while (my $line = <$fh>) {
    chomp $line;

    if ($line =~ /^"=== mlp: BEGIN (\S+)/) {
        my $short_name = short_name(\@INCLUDE_PATH, $1);
        $content{$curr_file} .= "include <${short_name}>\n";

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

    elsif ($line =~ /^"(include <\S+>)" -- mlp$/) {
        $content{$curr_file} .= "$1\n"
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

    if (open my $fh, "+<", $file) {
        my $package_main = "";
        unless ($file eq $MLP_FILE) {
            my $in_package_main = false;
            while (my $line = <$fh>) {
                chomp $line;

                if ($line =~ /^package main$/) {
                    $package_main .= "$&\n";
                    $in_package_main = true;
                }

                elsif ($in_package_main) {
                    $package_main .= "$line\n"
                }
            }
        }

        truncate($fh, 0);
        seek($fh, 0, 0);
        print $fh $content{$file} . $package_main;

        close $fh;
        utime -1, $ML_FILE_MTIME, $file;
    }
    else {
        $err_msg .= "- Could not open file `$file`: $!\n";
    }
}

if ($err_msg) {
    print STDERR $err_msg;
    print STDERR "Use 'mlp diff' and/or 'mlp' to mitigate this\n";
    exit 1;
}
