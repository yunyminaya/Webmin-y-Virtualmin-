#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-cron-lib.pl';
&ReadParse();

ovmcr_require_access();
my $config = ovmcr_init();
my $user = $in{'user'} || $config->{'cron_user'} || 'root';
my $jobs = ovmcr_list_jobs($user);
my $timers = ovmcr_list_system_timers();

my $total_jobs = scalar(@$jobs);
my $active_jobs = $total_jobs;
my $timer_count = scalar(@$timers);

# Find next execution
my $next_run = 'N/A';
if ($total_jobs > 0) {
	$next_run = 'Within next minute';
	}

&ui_print_header(undef, 'OpenVM Cron Manager', '', 'index');

print <<EOF;
<style>
.ovmcr-cards { display:flex; flex-wrap:wrap; gap:15px; margin:15px 0; }
.ovmcr-card { flex:1; min-width:200px; max-width:250px; background:#f8f9fa; border:1px solid #dee2e6; border-radius:8px; padding:15px; text-align:center; }
.ovmcr-card h3 { margin:0 0 5px 0; font-size:14px; color:#6c757d; }
.ovmcr-card .ovmcr-value { font-size:28px; font-weight:bold; color:#2c3e50; }
.ovmcr-card .ovmcr-sub { font-size:12px; color:#6c757d; margin-top:5px; }
.ovmcr-table { width:100%; border-collapse:collapse; margin:15px 0; }
.ovmcr-table th { background:#2c3e50; color:#fff; padding:10px; text-align:left; font-size:13px; }
.ovmcr-table td { padding:8px 10px; border-bottom:1px solid #dee2e6; font-size:13px; }
.ovmcr-table tr:hover { background:#f1f3f5; }
.ovmcr-btn { display:inline-block; padding:4px 10px; margin:2px; border-radius:4px; font-size:12px; text-decoration:none; color:#fff; }
.ovmcr-btn-blue { background:#3498db; }
.ovmcr-btn-green { background:#27ae60; }
.ovmcr-btn-red { background:#e74c3c; }
.ovmcr-btn-orange { background:#f39c12; }
.ovmcr-btn-gray { background:#6c757d; }
.ovmcr-btn:hover { opacity:0.85; }
.ovmcr-section { margin:20px 0; }
.ovmcr-section h2 { font-size:16px; color:#2c3e50; border-bottom:2px solid #3498db; padding-bottom:5px; }
.ovmcr-schedule { background:#e8f4fd; padding:3px 8px; border-radius:3px; font-size:11px; color:#2c3e50; }
.ovmcr-cmd { font-family:monospace; font-size:12px; max-width:400px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; display:inline-block; }
.ovmcr-badge { display:inline-block; padding:2px 8px; border-radius:10px; font-size:11px; font-weight:bold; }
.ovmcr-badge-active { background:#d4edda; color:#155724; }
.ovmcr-user-select { margin:10px 0; padding:5px; }
</style>

<div class="ovmcr-cards">
 <div class="ovmcr-card">
  <h3>Total Jobs</h3>
  <div class="ovmcr-value">$total_jobs</div>
  <div class="ovmcr-sub">cron jobs for user @{[&html_escape($user)]}</div>
 </div>
 <div class="ovmcr-card">
  <h3>Active Jobs</h3>
  <div class="ovmcr-value">$active_jobs</div>
  <div class="ovmcr-sub">currently scheduled</div>
 </div>
 <div class="ovmcr-card">
  <h3>Next Execution</h3>
  <div class="ovmcr-value" style="font-size:16px;">@{[&html_escape($next_run)]}</div>
  <div class="ovmcr-sub">estimated</div>
 </div>
 <div class="ovmcr-card">
  <h3>System Timers</h3>
  <div class="ovmcr-value">$timer_count</div>
  <div class="ovmcr-sub">systemd timers</div>
 </div>
</div>
EOF

print &ui_hr();

# User selector
print '<div class="ovmcr-user-select">';
print '<form method="get" action="index.cgi" style="display:inline;">';
print 'Viewing cron for user: <select name="user" onchange="this.form.submit()" style="padding:5px;">';
print '<option value="root"' . ($user eq 'root' ? ' selected' : '') . '>root</option>';

# Get system users with crontabs
my $user_list = `ls /var/spool/cron/crontabs/ 2>/dev/null || ls /var/spool/cron/ 2>/dev/null`;
foreach my $u (split(/\n/, $user_list)) {
	chomp($u);
	next if ($u eq 'root' || $u eq '.' || $u eq '..');
	my $sel = ($u eq $user) ? ' selected' : '';
	print '<option value="' . &html_escape($u) . "\"$sel>" . &html_escape($u) . '</option>';
	}
print '</select></form></div>';

print &ui_buttons_start();
print &ui_buttons_row('edit_job.cgi?new=1&user=' . &urlize($user), 'New Cron Job', 'Create a new scheduled task.');
print &ui_buttons_row('templates.cgi', 'Task Templates', 'Use pre-configured templates for common scheduled tasks.');
print &ui_buttons_row('logs.cgi', 'View Logs', 'View cron execution logs and history.');
print &ui_buttons_end();

# Cron jobs table
print '<div class="ovmcr-section">';
print '<h2>Cron Jobs</h2>';
print '<table class="ovmcr-table">';
print '<tr><th>#</th><th>Schedule</th><th>Description</th><th>Command</th><th>User</th><th>Actions</th></tr>';

if (scalar(@$jobs) > 0) {
	foreach my $job (@$jobs) {
		my $schedule_raw = "$job->{'min'} $job->{'hour'} $job->{'day'} $job->{'month'} $job->{'wday'}";
		print '<tr>';
		print '<td>' . &html_escape($job->{'line'}) . '</td>';
		print '<td><span class="ovmcr-schedule">' . &html_escape($job->{'human'}) . '</span><br><small style="color:#6c757d;">' . &html_escape($schedule_raw) . '</small></td>';
		print '<td><span class="ovmcr-badge ovmcr-badge-active">Active</span></td>';
		print '<td><span class="ovmcr-cmd" title="' . &html_escape($job->{'cmd'}) . '">' . &html_escape($job->{'cmd'}) . '</span></td>';
		print '<td>' . &html_escape($job->{'user'}) . '</td>';
		print '<td>';
		print '<a href="edit_job.cgi?line=' . &urlize($job->{'line'}) . '&user=' . &urlize($user) . '" class="ovmcr-btn ovmcr-btn-blue">Edit</a> ';
		print '<a href="edit_job.cgi?delete=1&line=' . &urlize($job->{'line'}) . '&user=' . &urlize($user) . '" class="ovmcr-btn ovmcr-btn-red" onclick="return confirm(\'Delete this cron job?\')">Delete</a>';
		print '</td>';
		print '</tr>';
		}
	}
else {
	print '<tr><td colspan="6" style="text-align:center;color:#6c757d;">No cron jobs found for user ' . &html_escape($user) . '</td></tr>';
	}

print '</table></div>';

# System timers section
if ($timer_count > 0) {
	print '<div class="ovmcr-section">';
	print '<h2>Systemd Timers</h2>';
	print '<table class="ovmcr-table">';
	print '<tr><th>Next Run</th><th>Time Left</th><th>Timer Unit</th><th>Activates</th></tr>';
	foreach my $t (@$timers) {
		print '<tr>';
		print '<td>' . &html_escape($t->{'next_run'}) . '</td>';
		print '<td>' . &html_escape($t->{'left'}) . '</td>';
		print '<td>' . &html_escape($t->{'unit'}) . '</td>';
		print '<td>' . &html_escape($t->{'activates'}) . '</td>';
		print '</tr>';
		}
	print '</table></div>';
	}

&ui_print_footer('/', $text{'index_return'} || 'Return');
