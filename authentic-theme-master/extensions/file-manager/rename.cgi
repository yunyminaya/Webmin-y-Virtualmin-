#!/usr/local/bin/perl

#
# Authentic Theme (https://github.com/authentic-theme/authentic-theme)
# Copyright Ilia Rostovtsev <ilia@virtualmin.com>
# Copyright Alexandr Bezenkov (https://github.com/real-gecko/filemin)
# Licensed under MIT (https://github.com/authentic-theme/authentic-theme/blob/master/LICENSE)
#
use strict;

our (%in, %text, $cwd, $path);

require($ENV{'THEME_ROOT'} . "/extensions/file-manager/file-manager-lib.pl");

if (!$in{'name'}) {
    redirect_local('list.cgi?path=' . urlize($path) . '&module=filemin' . extra_query());
}

$path = $path || "/";

my $type;
if (-d "$cwd/$in{'name'}") {
    $type = 'directory';
} else {
    $type = 'file';
}

if (-e "$cwd/$in{'name'}") {
    print_error(
          (text('filemanager_rename_exists', html_escape($in{'name'}), $path, $text{ 'theme_xhred_global_' . $type . '' })));
} else {
    my $from = $in{'file'};
    my $to   = $in{'name'};
    my $fsid = $in{'fsid'};

    if (can_move($cwd . '/' . $from, $cwd) && 
        rename_file($cwd . '/' . $from, $cwd . '/' . $to)) {
        cache_search_rename($fsid, $from, $to) if ($fsid);
        redirect_local('list.cgi?path=' . urlize($path) . '&module=filemin' . extra_query());
    } else {
        print_error(
                    (
                     text('filemanager_rename_denied',
                          html_escape($to),
                          html_escape($path),
                          lc($text{ 'theme_xhred_global_' . $type . '' })
                     )
                    ));
    }
}
