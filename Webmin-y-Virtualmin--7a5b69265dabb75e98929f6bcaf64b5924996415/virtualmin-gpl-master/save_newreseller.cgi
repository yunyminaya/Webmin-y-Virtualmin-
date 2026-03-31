#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './virtual-server-lib.pl';
&can_edit_templates() || &error($text{'newreseller_ecannot'} || 'You are not allowed to edit the new reseller email template');
&error_setup($text{'newreseller_title'} || 'New Reseller Email');
&ReadParse();

&uncat_file('reseller-template', $in{'body'});
&lock_file($module_config_file);
$config{'newreseller_subject'} = $in{'subject'};
$config{'resel_from'} = $in{'from'};
&save_module_config();
&unlock_file($module_config_file);

&webmin_log('newreseller');
&redirect('newreseller.cgi');
