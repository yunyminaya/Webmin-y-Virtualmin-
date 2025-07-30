#!/usr/local/bin/perl

#
# Authentic Theme (https://github.com/authentic-theme/authentic-theme)
# Copyright Ilia Rostovtsev <ilia@virtualmin.com>
# Licensed under MIT (https://github.com/authentic-theme/authentic-theme/blob/master/LICENSE)
#
use strict;

our (%in, %text, @allowed_paths, $cwd, $base, $path);

require($ENV{'THEME_ROOT'} . "/extensions/file-manager/file-manager-lib.pl");

kill_previous($0, $$);

no warnings 'once';
unless (opendir(DIR, $cwd)) {
    fatal_errors("$text{'theme_xhred_global_error'}: [tt]`$cwd`[/tt]- $!.");
    exit;
}
print_json(get_tree($in{'cpt'}, $in{'d'}, $in{'e'}, $in{'y'}));
