#!/usr/local/bin/perl

#
# Authentic Theme (https://github.com/authentic-theme/authentic-theme)
# Copyright Ilia Rostovtsev <ilia@virtualmin.com>
# Licensed under MIT (https://github.com/authentic-theme/authentic-theme/blob/master/LICENSE)
#
use strict;

our (%in, %text, %request_uri, $cwd, $base, $path);

require($ENV{'THEME_ROOT'} . "/extensions/file-manager/file-manager-lib.pl");

open(my $fh, "<" . &get_paste_buffer_file()) or die "Error: $!";
my @arr = <$fh>;
close($fh);
if (test_all_items_query()) {
    my @entries_list;
    my @entries_list_entries = get_entries_list();
    push(@entries_list, $arr[0], $arr[1], @entries_list_entries);
    undef(@arr);
    @arr = @entries_list;
}
my $act = $arr[0];
my $dir = $arr[1];
chomp($act);
chomp($dir);
my $from = abs_path($base . $dir);
my %errors;
my $mv = ($act eq "copy"            ? 0 : 1);
my $fr = (length $request_uri{'ua'} ? 1 : 0);
my $fo = ($request_uri{'ua'} eq '1' ? 1 : 0);
my $dr = 0;

# Dry run first to check if targets already exist
if (!$fr) {
    for (my $i = 2; $i <= scalar(@arr) - 1; $i++) {
        chomp($arr[$i]);
        $arr[$i] = simplify_path($arr[$i]);
        if ((-e "$cwd/$arr[$i]") && $cwd ne $from) {
            $dr++;
            set_response('ep');
            last;
        }
    }
}

# Perform actual action
if (!$dr) {
    for (my $i = 2; $i <= scalar(@arr) - 1; $i++) {
        chomp($arr[$i]);
        $arr[$i] = simplify_path($arr[$i]);
        if (!can_move("$from/$arr[$i]", $cwd, $from)) {
            $errors{"$arr[$i]"} = "$text{'error_move'}";
            next;
        }
        my $err = paster("$cwd", "$arr[$i]", "$from/$arr[$i]", "$cwd/$arr[$i]", $fo, $mv, $in{'fownergroup'});
        if ($err) {
            $errors{"$arr[$i]"} = $err;
        }
    }
}

if (%errors) {
    set_response('err');
    redirect_local(
           'list.cgi?path=' . urlize($path) . '&module=filemin' . '&error=' . get_errors(\%errors) . extra_query());
} else {
    set_response_count(scalar(@arr) - 2);
    redirect_local('list.cgi?path=' . urlize($path) . '&module=filemin' . '&error=1' . extra_query());
}
