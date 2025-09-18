#!/usr/local/bin/perl

#
# Authentic Theme (https://github.com/authentic-theme/authentic-theme)
# Copyright Ilia Rostovtsev <ilia@virtualmin.com>
# Licensed under MIT (https://github.com/authentic-theme/authentic-theme/blob/master/LICENSE)
#
use strict;

our (%in, %theme_text, $config_directory, $current_theme, $remote_user, $has_usermin);

do($ENV{'THEME_ROOT'} . "/authentic-lib.pl");

theme_make_config_dir();

my $file = $config_directory . "/$current_theme/favorites-$remote_user.json";
unlink_file($file);
write_file_contents($file, $in{'data'});
redirect("tconfig.cgi");
