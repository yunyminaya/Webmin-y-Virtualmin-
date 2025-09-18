#!/usr/local/bin/perl

#
# Authentic Theme (https://github.com/authentic-theme/authentic-theme)
# Copyright Ilia Rostovtsev <ilia@virtualmin.com>
# Licensed under MIT (https://github.com/authentic-theme/authentic-theme/blob/master/LICENSE)
#
use strict;

our (%in, %text, $cwd, $path);

require($ENV{'THEME_ROOT'} . "/extensions/file-manager/file-manager-lib.pl");

my @entries_list = get_entries_list();
my $path_urlized = urlize($path);
my $error;

if (!@entries_list) {
    redirect_local(("list.cgi?path=$path_urlized&module=filemin" . extra_query()));
}
foreach my $name (@entries_list) {
    my $name_ = $name;
    $name = simplify_path($name);
    my $symlink = "$cwd/${name}--symlink";

    # If symlink exists add a numerable suffix
    if (-e $symlink) {
        my $__ = 1;
        for (;;) {
            my $necwd = "$symlink(" . $__++ . ")";
            if (!-e $necwd) {
                $symlink = $necwd;
                last;
            }
        }
    }

    if (symlink_file("$cwd/$name", $symlink) == 0) {
        $error .= "<br>" if ($error);
        $error .= text('filemanager_symlink_exists', html_escape("${name_}_symlink"), html_escape($cwd));
    }
}
redirect_local('list.cgi?path=' . $path_urlized . '&module=filemin' . '&error=' . $error . extra_query());

