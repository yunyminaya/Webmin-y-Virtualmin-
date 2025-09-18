#!/usr/local/bin/perl

#
# Authentic Theme (https://github.com/authentic-theme/authentic-theme)
# Copyright Ilia Rostovtsev <ilia@virtualmin.com>
# Licensed under MIT (https://github.com/authentic-theme/authentic-theme/blob/master/LICENSE)
#
use strict;

use lib ($ENV{'LIBROOT'} . "/vendor_perl");

our (%in);

do($ENV{'THEME_ROOT'} . "/extensions/mail/mail-lib.pl");

my %temporary;
my @folders_data = mailbox::list_folders_sorted();
my @folders;
foreach my $folder (@folders_data) {
    if ($folder->{'hide'} && $folder ne $_[1]) {
        next;
    }

    my ($total,     $unread,      $special)     = folder_counts($folder);
    my ($folder_id, $folder_file, $folder_name) = folder_data($folder);

    my $id = $folder_id || $folder_file;
    my ($fid) = folders_process($id =~ m#([^/]+)$#);
    my ($parent, $child) = $fid =~ m|^ (.+) \. ([^\.]+) \z|x;
    my $name   = $folder_name;
    my $key    = folders_key_escape($id);
    my $title  = &decode_utf7($child ? $child : $name); utf8::decode($title); utf8::encode($title);
    $title     = folders_title_escape(folders_title_unseen(html_escape($title), $unread));
    my $active = (folders_key_escape($in{'key'}) eq $key ? 1 : 0);
    my $data   = $temporary{$fid} = { key    => $key,
                                      title  => $title,
                                      active => $active,
                                      unread => $unread, };
    defined $parent ? (push @{ $temporary{$parent}{children} }, $data) : (push(@folders, $data));
}
print_json(\@folders);
