#!/usr/local/bin/perl
# Restart some feature-related service

require './virtual-server-lib.pl';
&ReadParse();
&can_stop_servers() || &error($text{'restart_ecannot'});
if (&indexof($in{'feature'}, @plugins) < 0) {
	# Core feature
	$startfunc = "start_service_".$in{'feature'};
	$stopfunc = "stop_service_".$in{'feature'};
	$err = &$stopfunc($in{'id'});
	if (!$err) {
		$err = &$startfunc($in{'id'});
		if ($err) {
			# Delay for Apache to close sockets
			sleep(5);
			$err = &$startfunc($in{'id'});
			}
		}
	$name = $text{'feature_'.$in{'feature'}};
	}
else {
	# Plugin
	$err = &plugin_call($in{'feature'}, "feature_stop_service", $in{'id'});
	if (!$err) {
		$err = &plugin_call($in{'feature'}, "feature_start_service", $in{'id'});
		}
	$name = &plugin_call($in{'feature'}, "feature_name");
	}
&error_setup($text{'restart_err'});
&refresh_startstop_status();
&error($err) if ($err);
&webmin_log("restart", $in{'feature'});

if ($in{'show'}) {
	# Tell the user
	&ui_print_header(undef, $text{'restart_title'}, "");

	print &text('restart_done', $name),"<p>\n";

	&run_post_actions();
	&ui_print_footer("", $text{'index_return'});
	}
elsif ($in{'redirect'}) {
	&run_post_actions_silently();
	&redirect($in{'redirect'});
	}
else {
	&run_post_actions_silently();
	&redirect($ENV{'HTTP_REFERER'});
	}


