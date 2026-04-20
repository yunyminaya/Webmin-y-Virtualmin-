#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-db-lib.pl';
&ReadParse();

ovmdb_require_access();
my $config = ovmdb_init();
my $dbs = ovmdb_list_databases();
my $status = ovmdb_get_server_status();
my $users = ovmdb_list_users();

my $total_dbs = scalar(@$dbs);
my $total_size = 0;
foreach my $db (@$dbs) {
	$total_size += $db->{'size'};
	}
my $total_users = scalar(@$users);
my $server_ok = $status->{'running'} ? '<span style="color:#27ae60;font-weight:bold;">&#9679; Running</span>' : '<span style="color:#e74c3c;font-weight:bold;">&#9679; Stopped</span>';

&ui_print_header(undef, 'OpenVM Database Manager', '', 'index');

print <<EOF;
<style>
.ovmdb-cards { display:flex; flex-wrap:wrap; gap:15px; margin:15px 0; }
.ovmdb-card { flex:1; min-width:200px; max-width:250px; background:#f8f9fa; border:1px solid #dee2e6; border-radius:8px; padding:15px; text-align:center; }
.ovmdb-card h3 { margin:0 0 5px 0; font-size:14px; color:#6c757d; }
.ovmdb-card .ovmdb-value { font-size:28px; font-weight:bold; color:#2c3e50; }
.ovmdb-card .ovmdb-sub { font-size:12px; color:#6c757d; margin-top:5px; }
.ovmdb-table { width:100%; border-collapse:collapse; margin:15px 0; }
.ovmdb-table th { background:#2c3e50; color:#fff; padding:10px; text-align:left; font-size:13px; }
.ovmdb-table td { padding:8px 10px; border-bottom:1px solid #dee2e6; font-size:13px; }
.ovmdb-table tr:hover { background:#f1f3f5; }
.ovmdb-btn { display:inline-block; padding:4px 10px; margin:2px; border-radius:4px; font-size:12px; text-decoration:none; color:#fff; }
.ovmdb-btn-blue { background:#3498db; }
.ovmdb-btn-green { background:#27ae60; }
.ovmdb-btn-red { background:#e74c3c; }
.ovmdb-btn-orange { background:#f39c12; }
.ovmdb-btn:hover { opacity:0.85; }
.ovmdb-section { margin:20px 0; }
.ovmdb-section h2 { font-size:16px; color:#2c3e50; border-bottom:2px solid #3498db; padding-bottom:5px; }
.ovmdb-status-grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(200px,1fr)); gap:10px; margin:10px 0; }
.ovmdb-status-item { background:#f8f9fa; padding:10px; border-radius:4px; border-left:3px solid #3498db; }
.ovmdb-status-item label { font-weight:bold; color:#2c3e50; font-size:12px; }
.ovmdb-status-item span { display:block; font-size:13px; color:#555; margin-top:3px; }
</style>

<div class="ovmdb-cards">
 <div class="ovmdb-card">
  <h3>Total Databases</h3>
  <div class="ovmdb-value">$total_dbs</div>
  <div class="ovmdb-sub">databases found</div>
 </div>
 <div class="ovmdb-card">
  <h3>Total Size</h3>
  <div class="ovmdb-value" style="font-size:22px;">@{[ovmdb_human_size($total_size)]}</div>
  <div class="ovmdb-sub">combined size</div>
 </div>
 <div class="ovmdb-card">
  <h3>Active Users</h3>
  <div class="ovmdb-value">$total_users</div>
  <div class="ovmdb-sub">database users</div>
 </div>
 <div class="ovmdb-card">
  <h3>Server Status</h3>
  <div class="ovmdb-value" style="font-size:16px;">$server_ok</div>
  <div class="ovmdb-sub">@{[&html_escape($status->{'version'} || 'Unknown')]}</div>
 </div>
</div>
EOF

print &ui_hr();

print &ui_buttons_start();
print &ui_buttons_row('edit_db.cgi?new=1', 'New Database', 'Create a new MySQL or PostgreSQL database.');
print &ui_buttons_row('backups.cgi', 'Manage Backups', 'View, create, restore and delete database backups.');
print &ui_buttons_row('users.cgi', 'Manage Users', 'Create, edit and delete database users and permissions.');
print &ui_buttons_row('query.cgi', 'SQL Query', 'Execute SQL queries against any database.');
print &ui_buttons_end();

print <<EOF;
<div class="ovmdb-section">
<h2>Server Status</h2>
<div class="ovmdb-status-grid">
 <div class="ovmdb-status-item">
  <label>Uptime</label>
  <span>@{[&html_escape($status->{'uptime'} || 'N/A')]}</span>
 </div>
 <div class="ovmdb-status-item">
  <label>Queries / Second</label>
  <span>@{[&html_escape($status->{'queries_per_second'} || 'N/A')]}</span>
 </div>
 <div class="ovmdb-status-item">
  <label>Connections</label>
  <span>@{[&html_escape($status->{'connections'} || 'N/A')]}</span>
 </div>
 <div class="ovmdb-status-item">
  <label>DB Engine</label>
  <span>@{[&html_escape(uc($config->{'db_manager'} || 'mysql'))]}</span>
 </div>
</div>
</div>
EOF

print <<EOF;
<div class="ovmdb-section">
<h2>Databases</h2>
<table class="ovmdb-table">
<tr>
 <th>Name</th>
 <th>Charset</th>
 <th>Size</th>
 <th>Tables</th>
 <th>Actions</th>
</tr>
EOF

if (scalar(@$dbs) > 0) {
	foreach my $db (@$dbs) {
		my $esc_name = &html_escape($db->{'name'});
		print <<EOF;
<tr>
 <td><strong>$esc_name</strong></td>
 <td>@{[&html_escape($db->{'charset'})]}</td>
 <td>@{[&html_escape($db->{'size_human'})]}</td>
 <td>@{[&html_escape($db->{'tables'})]}</td>
 <td>
  <a href="edit_db.cgi?db=@{[&urlize($db->{'name'})]}" class="ovmdb-btn ovmdb-btn-blue">Edit</a>
  <a href="backups.cgi?db=@{[&urlize($db->{'name'})]}" class="ovmdb-btn ovmdb-btn-green">Backup</a>
  <a href="query.cgi?db=@{[&urlize($db->{'name'})]}" class="ovmdb-btn ovmdb-btn-orange">Query</a>
 </td>
</tr>
EOF
		}
	}
else {
	print '<tr><td colspan="5" style="text-align:center;color:#6c757d;">No databases found</td></tr>';
	}

print <<EOF;
</table>
</div>
EOF

&ui_print_footer('/', $text{'index_return'} || 'Return');
