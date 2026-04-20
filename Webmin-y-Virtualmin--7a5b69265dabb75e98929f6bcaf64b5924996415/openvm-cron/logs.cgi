#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-cron-lib.pl';
&ReadParse();

ovmcr_require_access();
my $config = ovmcr_init();

# Handle clear log
if ($in{'clear_log'}) {
	if (-r '/var/log/cron') {
		eval { truncate('/var/log/cron', 0); };
		}
	elsif (-r '/var/log/syslog') {
		# Cannot safely truncate syslog, just note it
		}
	else {
		eval { `journalctl --vacuum-time=1s 2>/dev/null`; };
		}
	}

my $filter_user = $in{'filter_user'} || '';
my $filter_date = $in{'filter_date'} || '';
my $filter_status = $in{'filter_status'} || '';

# Get cron log
my $log_content = ovmcr_get_cron_log();

# Parse log entries
my @entries;
foreach my $line (split(/\n/, $log_content)) {
	next unless ($line);
	chomp($line);
	my $entry = {
		'raw' => $line,
		'date' => '',
		'time' => '',
		'user' => '',
		'cmd' => '',
		'status' => 'info',
		};

	# Try to parse common cron log formats
	# Format: Month Day HH:MM:SS hostname CRON[pid]: (user) CMD (command)
	if ($line =~ /^(\w+\s+\d+\s+\d+:\d+:\d+)\s+\S+\s+CRON\[\d+\]:\s+\((\w+)\)\s+CMD\s+\((.+)\)$/i) {
		$entry->{'date'} = $1;
		$entry->{'user'} = $2;
		$entry->{'cmd'} = $3;
		$entry->{'status'} = 'success';
		}
	elsif ($line =~ /^(\w+\s+\d+\s+\d+:\d+:\d+)/) {
		$entry->{'date'} = $1;
		if ($line =~ /\((\w+)\)/) {
			$entry->{'user'} = $1;
			}
		if ($line =~ /CMD\s+\((.+)\)/) {
			$entry->{'cmd'} = $1;
			}
		if ($line =~ /error|fail|fatal/i) {
			$entry->{'status'} = 'error';
			}
		}
	elsif ($line =~ /^--\s+(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})/) {
		# journalctl format
		$entry->{'date'} = "$1 $2";
		if ($line =~ /CRON\[\d+\]:\s+\((\w+)\)\s+CMD\s+\((.+)\)/) {
			$entry->{'user'} = $1;
			$entry->{'cmd'} = $2;
			}
		}

	# Apply filters
	if ($filter_user && $entry->{'user'} !~ /$filter_user/i) {
		next;
		}
	if ($filter_date && $entry->{'date'} !~ /$filter_date/i) {
		next;
		}
	if ($filter_status eq 'error' && $entry->{'status'} ne 'error') {
		next;
		}
	elsif ($filter_status eq 'success' && $entry->{'status'} ne 'success') {
		next;
		}

	push(@entries, $entry);
	}

# Limit to last 500 entries
if (scalar(@entries) > 500) {
	@entries = @entries[-500 .. -1];
	}

my $total_entries = scalar(@entries);
my $error_count = scalar(grep { $_->{'status'} eq 'error' } @entries);
my $success_count = scalar(grep { $_->{'status'} eq 'success' } @entries);

&ui_print_header(undef, 'Cron Execution Logs', '');

print <<EOF;
<style>
.ovmcr-cards { display:flex; flex-wrap:wrap; gap:15px; margin:15px 0; }
.ovmcr-card { flex:1; min-width:180px; max-width:220px; background:#f8f9fa; border:1px solid #dee2e6; border-radius:8px; padding:15px; text-align:center; }
.ovmcr-card h3 { margin:0 0 5px 0; font-size:13px; color:#6c757d; }
.ovmcr-card .ovmcr-value { font-size:22px; font-weight:bold; color:#2c3e50; }
.ovmcr-table { width:100%; border-collapse:collapse; margin:15px 0; font-size:12px; }
.ovmcr-table th { background:#2c3e50; color:#fff; padding:8px; text-align:left; }
.ovmcr-table td { padding:6px 8px; border-bottom:1px solid #dee2e6; }
.ovmcr-table tr:hover { background:#f1f3f5; }
.ovmcr-table tr.ovmcr-error-row { background:#fff5f5; }
.ovmcr-table tr.ovmcr-error-row:hover { background:#ffebee; }
.ovmcr-btn { display:inline-block; padding:4px 10px; margin:2px; border-radius:4px; font-size:12px; text-decoration:none; color:#fff; border:none; cursor:pointer; }
.ovmcr-btn-blue { background:#3498db; }
.ovmcr-btn-red { background:#e74c3c; }
.ovmcr-btn-gray { background:#6c757d; }
.ovmcr-section { margin:20px 0; }
.ovmcr-section h2 { font-size:15px; color:#2c3e50; border-bottom:2px solid #3498db; padding-bottom:5px; }
.ovmcr-filter-box { background:#f8f9fa; border:1px solid #dee2e6; border-radius:4px; padding:15px; margin:15px 0; }
.ovmcr-cmd { font-family:monospace; max-width:400px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; display:inline-block; }
.ovmcr-badge { display:inline-block; padding:2px 8px; border-radius:10px; font-size:11px; font-weight:bold; }
.ovmcr-badge-success { background:#d4edda; color:#155724; }
.ovmcr-badge-error { background:#f8d7da; color:#721c24; }
.ovmcr-badge-info { background:#d1ecf1; color:#0c5460; }
</style>

<div class="ovmcr-cards">
 <div class="ovmcr-card">
  <h3>Total Entries</h3>
  <div class="ovmcr-value">$total_entries</div>
 </div>
 <div class="ovmcr-card">
  <h3>Successful</h3>
  <div class="ovmcr-value" style="color:#27ae60;">$success_count</div>
 </div>
 <div class="ovmcr-card">
  <h3>Errors</h3>
  <div class="ovmcr-value" style="color:#e74c3c;">$error_count</div>
 </div>
</div>
EOF

# Filter form
print '<div class="ovmcr-filter-box">';
print '<h3 style="margin:0 0 10px 0;font-size:14px;color:#2c3e50;">Filter Logs</h3>';
print '<form method="get" action="logs.cgi" style="display:flex;gap:10px;flex-wrap:wrap;align-items:center;">';
print 'User: <input type="text" name="filter_user" value="' . &html_escape($filter_user) . '" placeholder="username" style="padding:4px;width:120px;"> ';
print 'Date: <input type="text" name="filter_date" value="' . &html_escape($filter_date) . '" placeholder="Jan 01" style="padding:4px;width:120px;"> ';
print 'Status: <select name="filter_status" style="padding:4px;">';
print '<option value="">All</option>';
print '<option value="success"' . ($filter_status eq 'success' ? ' selected' : '') . '>Success</option>';
print '<option value="error"' . ($filter_status eq 'error' ? ' selected' : '') . '>Errors</option>';
print '</select> ';
print '<input type="submit" value="Filter" class="ovmcr-btn ovmcr-btn-blue"> ';
print '<a href="logs.cgi" class="ovmcr-btn ovmcr-btn-gray">Reset</a>';
print '</form>';
print '</div>';

# Clear log button
print '<div style="margin:10px 0;">';
print '<form method="post" action="logs.cgi" style="display:inline;">';
print '<input type="submit" name="clear_log" value="Clear Log" class="ovmcr-btn ovmcr-btn-red" onclick="return confirm(\'Clear all cron log entries? This cannot be undone.\')">';
print '</form>';
print '</div>';

# Log table
print '<div class="ovmcr-section">';
print '<h2>Log Entries</h2>';
print '<table class="ovmcr-table">';
print '<tr><th>Date/Time</th><th>User</th><th>Command</th><th>Status</th></tr>';

if (scalar(@entries) > 0) {
	foreach my $e (reverse @entries) {
		my $row_class = $e->{'status'} eq 'error' ? ' class="ovmcr-error-row"' : '';
		my $status_badge = $e->{'status'} eq 'error'
			? '<span class="ovmcr-badge ovmcr-badge-error">Error</span>'
			: $e->{'status'} eq 'success'
				? '<span class="ovmcr-badge ovmcr-badge-success">OK</span>'
				: '<span class="ovmcr-badge ovmcr-badge-info">Info</span>';

		print "<tr$row_class>";
		print '<td>' . &html_escape($e->{'date'}) . '</td>';
		print '<td>' . &html_escape($e->{'user'} || '-') . '</td>';
		print '<td><span class="ovmcr-cmd" title="' . &html_escape($e->{'cmd'}) . '">' . &html_escape($e->{'cmd'} || '-') . '</span></td>';
		print '<td>' . $status_badge . '</td>';
		print '</tr>';
		}
	}
else {
	print '<tr><td colspan="4" style="text-align:center;color:#6c757d;">No log entries found</td></tr>';
	}

print '</table></div>';

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return to Cron Jobs');
