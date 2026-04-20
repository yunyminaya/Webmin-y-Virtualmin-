#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-cron-lib.pl';
&ReadParse();

ovmcr_require_access();
my $config = ovmcr_init();
my $user = $in{'user'} || $config->{'cron_user'} || 'root';
my $line_num = $in{'line'};
my $new = $in{'new'};
my $delete = $in{'delete'};

# Handle delete
if ($delete && $line_num) {
	my $res = ovmcr_delete_job($user, $line_num);
	if ($res->{'ok'}) {
		print "Location: index.cgi?user=" . &urlize($user) . "\n\n";
		exit(0);
		}
	else {
		&error("Failed to delete job: " . &html_escape($res->{'error'}));
		}
	}

# Handle save (new or edit)
if ($in{'save_job'}) {
	my $min = $in{'min'} || '*';
	my $hour = $in{'hour'} || '*';
	my $day = $in{'day'} || '*';
	my $month = $in{'month'} || '*';
	my $wday = $in{'wday'} || '*';
	my $cmd = $in{'cmd'};

	&error("No command specified") unless ($cmd);

	my $res;
	if ($new) {
		$res = ovmcr_add_job($user, $min, $hour, $day, $month, $wday, $cmd);
		}
	else {
		$res = ovmcr_edit_job($user, $line_num, $min, $hour, $day, $month, $wday, $cmd);
		}

	if ($res->{'ok'}) {
		print "Location: index.cgi?user=" . &urlize($user) . "\n\n";
		exit(0);
		}
	else {
		&error("Failed to save job: " . &html_escape($res->{'error'}));
		}
	}

# Load existing job for editing
my $job;
if (!$new && $line_num) {
	my $jobs = ovmcr_list_jobs($user);
	$job = $jobs->[$line_num - 1];
	&error("Job not found at line $line_num") unless ($job);
	}

my $min_val = $job ? $job->{'min'} : '*';
my $hour_val = $job ? $job->{'hour'} : '*';
my $day_val = $job ? $job->{'day'} : '*';
my $month_val = $job ? $job->{'month'} : '*';
my $wday_val = $job ? $job->{'wday'} : '*';
my $cmd_val = $job ? $job->{'cmd'} : '';
my $title = $new ? 'Create New Cron Job' : 'Edit Cron Job';

&ui_print_header(undef, $title, '');

print <<EOF;
<style>
.ovmcr-form-section { background:#f8f9fa; border:1px solid #dee2e6; border-radius:4px; padding:15px; margin:15px 0; }
.ovmcr-form-section h3 { margin:0 0 10px 0; font-size:14px; color:#2c3e50; border-bottom:1px solid #dee2e6; padding-bottom:5px; }
.ovmcr-field { margin:8px 0; }
.ovmcr-field label { display:inline-block; width:120px; font-weight:bold; font-size:13px; color:#2c3e50; }
.ovmcr-field input, .ovmcr-field select, .ovmcr-field textarea { padding:5px; border:1px solid #dee2e6; border-radius:3px; font-size:13px; }
.ovmcr-field textarea { width:100%; min-height:80px; font-family:monospace; }
.ovmcr-preview { background:#e8f4fd; border:1px solid #b8daff; border-radius:4px; padding:10px; margin:10px 0; }
.ovmcr-preview strong { color:#004085; }
.ovmcr-quick-btns { display:flex; flex-wrap:wrap; gap:5px; margin:10px 0; }
.ovmcr-quick-btn { padding:5px 10px; border:1px solid #dee2e6; border-radius:4px; background:#fff; cursor:pointer; font-size:12px; }
.ovmcr-quick-btn:hover { background:#e9ecef; }
.ovmcr-quick-btn.active { background:#3498db; color:#fff; border-color:#3498db; }
.ovmcr-btn { display:inline-block; padding:6px 15px; margin:3px; border-radius:4px; font-size:13px; cursor:pointer; border:none; color:#fff; }
.ovmcr-btn-blue { background:#3498db; }
.ovmcr-btn-green { background:#27ae60; }
.ovmcr-btn-red { background:#e74c3c; }
.ovmcr-btn-gray { background:#6c757d; }
</style>
EOF

print &ui_form_start('edit_job.cgi', 'post');
print &ui_hidden('user', $user);
print &ui_hidden('line', $line_num) if ($line_num);
print &ui_hidden('new', '1') if ($new);

# Quick templates
print '<div class="ovmcr-form-section">';
print '<h3>Quick Schedule Templates</h3>';
print '<div class="ovmcr-quick-btns">';
print '<button type="button" class="ovmcr-quick-btn" onclick="setSchedule(\'*\',\'*\',\'*\',\'*\',\'*\')">Every minute</button>';
print '<button type="button" class="ovmcr-quick-btn" onclick="setSchedule(\'*/5\',\'*\',\'*\',\'*\',\'*\')">Every 5 min</button>';
print '<button type="button" class="ovmcr-quick-btn" onclick="setSchedule(\'*/15\',\'*\',\'*\',\'*\',\'*\')">Every 15 min</button>';
print '<button type="button" class="ovmcr-quick-btn" onclick="setSchedule(\'*/30\',\'*\',\'*\',\'*\',\'*\')">Every 30 min</button>';
print '<button type="button" class="ovmcr-quick-btn" onclick="setSchedule(\'0\',\'*\',\'*\',\'*\',\'*\')">Hourly</button>';
print '<button type="button" class="ovmcr-quick-btn" onclick="setSchedule(\'0\',\'0\',\'*\',\'*\',\'*\')">Daily midnight</button>';
print '<button type="button" class="ovmcr-quick-btn" onclick="setSchedule(\'0\',\'2\',\'*\',\'*\',\'*\')">Daily 2 AM</button>';
print '<button type="button" class="ovmcr-quick-btn" onclick="setSchedule(\'0\',\'0\',\'*\',\'*\',\'0\')">Weekly Sunday</button>';
print '<button type="button" class="ovmcr-quick-btn" onclick="setSchedule(\'0\',\'0\',\'1\',\'*\',\'*\')">Monthly 1st</button>';
print '</div>';
print '</div>';

# Schedule fields
print '<div class="ovmcr-form-section">';
print '<h3>Schedule</h3>';

print '<div class="ovmcr-field">';
print '<label>Minute:</label>';
print '<input type="text" name="min" id="min_field" value="' . &html_escape($min_val) . '" size="10" placeholder="*"> ';
print '<select onchange="document.getElementById(\'min_field\').value=this.value">';
print '<option value="">--</option>';
print '<option value="*">Every minute (*)</option>';
print '<option value="*/5">Every 5 min</option>';
print '<option value="*/10">Every 10 min</option>';
print '<option value="*/15">Every 15 min</option>';
print '<option value="*/30">Every 30 min</option>';
print '<option value="0">At 0</option>';
print '</select>';
print '</div>';

print '<div class="ovmcr-field">';
print '<label>Hour:</label>';
print '<input type="text" name="hour" id="hour_field" value="' . &html_escape($hour_val) . '" size="10" placeholder="*"> ';
print '<select onchange="document.getElementById(\'hour_field\').value=this.value">';
print '<option value="">--</option>';
print '<option value="*">Every hour (*)</option>';
print '<option value="*/2">Every 2 hours</option>';
print '<option value="*/6">Every 6 hours</option>';
print '<option value="0">Midnight</option>';
print '<option value="2">2 AM</option>';
print '<option value="6">6 AM</option>';
print '<option value="12">Noon</option>';
print '</select>';
print '</div>';

print '<div class="ovmcr-field">';
print '<label>Day of Month:</label>';
print '<input type="text" name="day" id="day_field" value="' . &html_escape($day_val) . '" size="10" placeholder="*"> ';
print '<select onchange="document.getElementById(\'day_field\').value=this.value">';
print '<option value="">--</option>';
print '<option value="*">Every day (*)</option>';
print '<option value="1">1st</option>';
print '<option value="15">15th</option>';
print '<option value="28">28th</option>';
print '</select>';
print '</div>';

print '<div class="ovmcr-field">';
print '<label>Month:</label>';
print '<input type="text" name="month" id="month_field" value="' . &html_escape($month_val) . '" size="10" placeholder="*"> ';
print '<select onchange="document.getElementById(\'month_field\').value=this.value">';
print '<option value="">--</option>';
print '<option value="*">Every month (*)</option>';
print '<option value="1">January</option>';
print '<option value="*/3">Quarterly</option>';
print '<option value="*/6">Biannual</option>';
print '</select>';
print '</div>';

print '<div class="ovmcr-field">';
print '<label>Day of Week:</label>';
print '<input type="text" name="wday" id="wday_field" value="' . &html_escape($wday_val) . '" size="10" placeholder="*"> ';
print '<select onchange="document.getElementById(\'wday_field\').value=this.value">';
print '<option value="">--</option>';
print '<option value="*">Every day (*)</option>';
print '<option value="0">Sunday</option>';
print '<option value="1">Monday</option>';
print '<option value="2">Tuesday</option>';
print '<option value="3">Wednesday</option>';
print '<option value="4">Thursday</option>';
print '<option value="5">Friday</option>';
print '<option value="6">Saturday</option>';
print '<option value="1-5">Mon-Fri</option>';
print '</select>';
print '</div>';

print '</div>';

# Command
print '<div class="ovmcr-form-section">';
print '<h3>Command</h3>';
print '<div class="ovmcr-field">';
print '<label>User:</label>';
print '<input type="text" name="user" value="' . &html_escape($user) . '" size="20" readonly style="background:#e9ecef;">';
print '</div>';
print '<div class="ovmcr-field">';
print '<label>Command:</label>';
print '<textarea name="cmd" placeholder="/path/to/script.sh arg1 arg2">' . &html_escape($cmd_val) . '</textarea>';
print '</div>';
print '</div>';

# Preview
my $preview = ovmcr_human_schedule($min_val, $hour_val, $day_val, $month_val, $wday_val);
print '<div class="ovmcr-preview">';
print '<strong>Schedule Preview:</strong> ' . &html_escape($preview);
print '<br><small>' . &html_escape("$min_val $hour_val $day_val $month_val $wday_val") . '</small>';
print '</div>';

# Buttons
print '<div style="margin:15px 0;">';
print '<input type="submit" name="save_job" value="Save Job" class="ovmcr-btn ovmcr-btn-green"> ';
if (!$new && $line_num) {
	print '<a href="edit_job.cgi?delete=1&line=' . &urlize($line_num) . '&user=' . &urlize($user) . '" class="ovmcr-btn ovmcr-btn-red" onclick="return confirm(\'Delete this cron job?\')">Delete Job</a> ';
	}
print '<a href="index.cgi?user=' . &urlize($user) . '" class="ovmcr-btn ovmcr-btn-gray">Cancel</a>';
print '</div>';

print &ui_form_end();

print <<EOF;
<script>
function setSchedule(min, hour, day, month, wday) {
	document.getElementById('min_field').value = min;
	document.getElementById('hour_field').value = hour;
	document.getElementById('day_field').value = day;
	document.getElementById('month_field').value = month;
	document.getElementById('wday_field').value = wday;
	}
</script>
EOF

&ui_print_footer('index.cgi?user=' . &urlize($user), $text{'index_return'} || 'Return to Cron Jobs');
