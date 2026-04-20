#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-cron-lib.pl';
&ReadParse();

ovmcr_require_access();
my $config = ovmcr_init();

# Task templates - predefined common tasks
my @task_templates = (
	{
		'name' => 'Daily Database Backup',
		'desc' => 'Backup all MySQL databases daily using mysqldump with compression.',
		'min' => '0', 'hour' => '2', 'day' => '*', 'month' => '*', 'wday' => '*',
		'cmd' => 'mysqldump -u root --all-databases | gzip > /var/db-backups/all_db_$(date +\%Y\%m\%d).sql.gz',
		'icon' => '&#128451;',
		'color' => '#3498db',
		},
	{
		'name' => 'Renew SSL Certificates',
		'desc' => 'Auto-renew Let\'s Encrypt SSL certificates before expiration.',
		'min' => '0', 'hour' => '0', 'day' => '*', 'month' => '*', 'wday' => '0',
		'cmd' => 'certbot renew --quiet --post-hook "systemctl reload apache2"',
		'icon' => '&#128274;',
		'color' => '#27ae60',
		},
	{
		'name' => 'Rotate Logs',
		'desc' => 'Rotate and compress old log files to save disk space.',
		'min' => '0', 'hour' => '0', 'day' => '*', 'month' => '*', 'wday' => '*',
		'cmd' => 'logrotate /etc/logrotate.conf',
		'icon' => '&#128196;',
		'color' => '#e67e22',
		},
	{
		'name' => 'Clean Temporary Files',
		'desc' => 'Remove old temporary files from /tmp and /var/tmp.',
		'min' => '0', 'hour' => '3', 'day' => '*', 'month' => '*', 'wday' => '*',
		'cmd' => 'find /tmp -type f -mtime +7 -delete 2>/dev/null; find /var/tmp -type f -mtime +30 -delete 2>/dev/null',
		'icon' => '&#128465;',
		'color' => '#e74c3c',
		},
	{
		'name' => 'Update System Packages',
		'desc' => 'Check and apply security updates automatically.',
		'min' => '30', 'hour' => '4', 'day' => '*', 'month' => '*', 'wday' => '1',
		'cmd' => 'apt-get update -qq && apt-get upgrade -y -qq --with-new-pkgs 2>/dev/null || yum update -y -q 2>/dev/null',
		'icon' => '&#128230;',
		'color' => '#9b59b6',
		},
	{
		'name' => 'Verify Services',
		'desc' => 'Check that critical services (Apache, MySQL, Postfix) are running and restart if needed.',
		'min' => '*/5', 'hour' => '*', 'day' => '*', 'month' => '*', 'wday' => '*',
		'cmd' => 'systemctl is-active apache2 || systemctl start apache2; systemctl is-active mysql || systemctl start mysql; systemctl is-active postfix || systemctl start postfix',
		'icon' => '&#9989;',
		'color' => '#1abc9c',
		},
	{
		'name' => 'Sync DNS Zones',
		'desc' => 'Synchronize DNS zone files with slave servers.',
		'min' => '0', 'hour' => '*/6', 'day' => '*', 'month' => '*', 'wday' => '*',
		'cmd' => 'rndc reload 2>/dev/null; systemctl reload bind9 2>/dev/null',
		'icon' => '&#127760;',
		'color' => '#2c3e50',
		},
	{
		'name' => 'Generate Reports',
		'desc' => 'Generate daily server usage and bandwidth reports.',
		'min' => '0', 'hour' => '1', 'day' => '*', 'month' => '*', 'wday' => '*',
		'cmd' => 'vnstat -d > /var/log/bandwidth_report.txt 2>/dev/null; df -h > /var/log/disk_report.txt 2>/dev/null',
		'icon' => '&#128202;',
		'color' => '#f39c12',
		},
	);

&ui_print_header(undef, 'Cron Task Templates', '');

print <<EOF;
<style>
.ovmcr-grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(320px,1fr)); gap:15px; margin:15px 0; }
.ovmcr-tpl-card { background:#fff; border:1px solid #dee2e6; border-radius:8px; padding:15px; border-left:4px solid #3498db; transition:box-shadow 0.2s; }
.ovmcr-tpl-card:hover { box-shadow:0 2px 8px rgba(0,0,0,0.1); }
.ovmcr-tpl-header { display:flex; align-items:center; gap:10px; margin-bottom:10px; }
.ovmcr-tpl-icon { font-size:24px; }
.ovmcr-tpl-name { font-size:15px; font-weight:bold; color:#2c3e50; }
.ovmcr-tpl-desc { font-size:12px; color:#6c757d; margin-bottom:10px; line-height:1.4; }
.ovmcr-tpl-schedule { background:#f8f9fa; padding:8px; border-radius:4px; margin-bottom:10px; }
.ovmcr-tpl-schedule code { font-size:11px; color:#2c3e50; }
.ovmcr-tpl-schedule small { display:block; margin-top:3px; color:#6c757d; }
.ovmcr-tpl-cmd { background:#2c3e50; color:#ecf0f1; padding:8px; border-radius:4px; font-family:monospace; font-size:11px; word-break:break-all; margin-bottom:10px; max-height:60px; overflow-y:auto; }
.ovmcr-btn { display:inline-block; padding:5px 12px; border-radius:4px; font-size:12px; text-decoration:none; color:#fff; cursor:pointer; border:none; }
.ovmcr-btn-green { background:#27ae60; }
.ovmcr-btn-green:hover { background:#219a52; }
</style>
EOF

print '<p style="color:#6c757d;">Select a template to pre-fill the cron job editor. You can customize the schedule and command after selecting.</p>';

print '<div class="ovmcr-grid">';

foreach my $tpl (@task_templates) {
	my $schedule_human = ovmcr_human_schedule($tpl->{'min'}, $tpl->{'hour'}, $tpl->{'day'}, $tpl->{'month'}, $tpl->{'wday'});
	my $schedule_raw = "$tpl->{'min'} $tpl->{'hour'} $tpl->{'day'} $tpl->{'month'} $tpl->{'wday'}";

	print '<div class="ovmcr-tpl-card" style="border-left-color:' . $tpl->{'color'} . ';">';
	print '<div class="ovmcr-tpl-header">';
	print '<span class="ovmcr-tpl-icon">' . $tpl->{'icon'} . '</span>';
	print '<span class="ovmcr-tpl-name">' . &html_escape($tpl->{'name'}) . '</span>';
	print '</div>';
	print '<div class="ovmcr-tpl-desc">' . &html_escape($tpl->{'desc'}) . '</div>';
	print '<div class="ovmcr-tpl-schedule">';
	print '<strong>Schedule:</strong> ' . &html_escape($schedule_human);
	print '<br><code>' . &html_escape($schedule_raw) . '</code>';
	print '</div>';
	print '<div class="ovmcr-tpl-cmd">' . &html_escape($tpl->{'cmd'}) . '</div>';

	# Use template button - link to edit_job.cgi with pre-filled values
	my $use_url = 'edit_job.cgi?new=1'
		. '&min=' . &urlize($tpl->{'min'})
		. '&hour=' . &urlize($tpl->{'hour'})
		. '&day=' . &urlize($tpl->{'day'})
		. '&month=' . &urlize($tpl->{'month'})
		. '&wday=' . &urlize($tpl->{'wday'})
		. '&cmd=' . &urlize($tpl->{'cmd'});
	print '<a href="' . $use_url . '" class="ovmcr-btn ovmcr-btn-green">Use This Template</a>';

	print '</div>';
	}

print '</div>';

# Also show common schedule templates
my $schedule_templates = ovmcr_common_templates();

print '<div style="margin:30px 0;">';
print '<h2 style="font-size:16px;color:#2c3e50;border-bottom:2px solid #3498db;padding-bottom:5px;">Common Schedule Patterns</h2>';
print '<table style="width:100%;border-collapse:collapse;margin:10px 0;">';
print '<tr style="background:#2c3e50;color:#fff;"><th style="padding:8px;text-align:left;">Name</th><th style="padding:8px;text-align:left;">Description</th><th style="padding:8px;text-align:left;">Schedule</th><th style="padding:8px;text-align:left;">Human</th><th style="padding:8px;">Action</th></tr>';

foreach my $st (@$schedule_templates) {
	my $human = ovmcr_human_schedule($st->{'min'}, $st->{'hour'}, $st->{'day'}, $st->{'month'}, $st->{'wday'});
	my $raw = "$st->{'min'} $st->{'hour'} $st->{'day'} $st->{'month'} $st->{'wday'}";
	my $use_url = 'edit_job.cgi?new=1'
		. '&min=' . &urlize($st->{'min'})
		. '&hour=' . &urlize($st->{'hour'})
		. '&day=' . &urlize($st->{'day'})
		. '&month=' . &urlize($st->{'month'})
		. '&wday=' . &urlize($st->{'wday'});

	print '<tr style="border-bottom:1px solid #dee2e6;">';
	print '<td style="padding:6px 8px;font-size:13px;"><strong>' . &html_escape($st->{'name'}) . '</strong></td>';
	print '<td style="padding:6px 8px;font-size:12px;color:#6c757d;">' . &html_escape($st->{'desc'}) . '</td>';
	print '<td style="padding:6px 8px;font-size:12px;font-family:monospace;">' . &html_escape($raw) . '</td>';
	print '<td style="padding:6px 8px;font-size:12px;">' . &html_escape($human) . '</td>';
	print '<td style="padding:6px 8px;text-align:center;"><a href="' . $use_url . '" class="ovmcr-btn ovmcr-btn-green" style="font-size:11px;padding:3px 8px;">Use</a></td>';
	print '</tr>';
	}

print '</table></div>';

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return to Cron Jobs');
