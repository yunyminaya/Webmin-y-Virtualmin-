#!/usr/local/bin/perl

#
# Authentic Theme (https://github.com/authentic-theme/authentic-theme)
# Copyright Ilia Rostovtsev <ilia@virtualmin.com>
# Licensed under MIT (https://github.com/authentic-theme/authentic-theme/blob/master/LICENSE)
#
use strict;

our (%in, $current_theme, $config_directory, $get_user_level, %theme_text, $has_usermin);

do($ENV{'THEME_ROOT'} . "/authentic-lib.pl");
do($ENV{'THEME_ROOT'} . "/settings-lib.pl");

my @files = get_settings_editor_files();

webmin_user_is_admin() ||
  error($theme_text{'theme_error_access_not_root_user'});
if ($in{'file'}) {
  array_contains(\@files, $in{'file'}) ||
    error($theme_text{'theme_error_access_dir_not_allowed'});
}

theme_make_config_dir();
my $file = &html_escape($in{'file'});
unlink_file($file);
write_file_contents($file, $in{'data'});

if ($has_usermin) {
    (my $_file = $file) =~ s/webmin/usermin/;
    unlink_file($_file);
    write_file_contents($_file, $in{'data'});
}
redirect("tconfig.cgi");
