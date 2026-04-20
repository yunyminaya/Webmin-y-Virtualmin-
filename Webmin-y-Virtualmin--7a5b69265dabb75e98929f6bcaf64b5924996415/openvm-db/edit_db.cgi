#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-db-lib.pl';
&ReadParse();

ovmdb_require_access();
my $config = ovmdb_init();
my $db = $in{'db'};
my $new = $in{'new'};

# Handle form actions
if ($in{'create_db'} && $in{'new_name'}) {
	my $res = ovmdb_create_database($in{'new_name'}, $in{'new_charset'});
	if ($res->{'ok'}) {
		$db = $in{'new_name'};
		$new = 0;
		print "Location: edit_db.cgi?db=" . &urlize($db) . "\n\n";
		exit(0);
		}
	else {
		&error("Failed to create database: " . &html_escape($res->{'error'}));
		}
	}

if ($in{'drop_db'} && $db) {
	my $res = ovmdb_drop_database($db);
	if ($res->{'ok'}) {
		print "Location: index.cgi\n\n";
		exit(0);
		}
	else {
		&error("Failed to drop database: " . &html_escape($res->{'error'}));
		}
	}

if ($in{'optimize_db'} && $db) {
	my $res = ovmdb_optimize_database($db);
	if (!$res->{'ok'}) {
		&error("Optimize failed: " . &html_escape($res->{'error'}));
		}
	}

if ($in{'check_db'} && $db) {
	my $res = ovmdb_check_database($db);
	if (!$res->{'ok'}) {
		&error("Check failed: " . &html_escape($res->{'error'}));
		}
	}

if ($in{'backup_db'} && $db) {
	my $ts = `date +%Y%m%d_%H%M%S`;
	chomp($ts);
	my $file = "${db}_backup_${ts}.sql";
	my $res = ovmdb_backup_database($db, $file);
	if (!$res->{'ok'}) {
		&error("Backup failed: " . &html_escape($res->{'error'}));
		}
	}

# New database form
if ($new) {
	&ui_print_header(undef, 'Create New Database', '');
	print &ui_form_start('edit_db.cgi', 'post');
	print &ui_hidden('new', '1');
	print &ui_table_start('New Database', 'width=100%', 2);
	print &ui_table_row('Database Name', &ui_textbox('new_name', '', 40));
	print &ui_table_row('Character Set', &ui_textbox('new_charset', $config->{'default_charset'} || 'utf8mb4', 20));
	print &ui_table_end();
	print &ui_form_end([ [ 'create_db', 'Create Database' ], [ 'cancel', 'Cancel' ] ]);
	&ui_print_footer('index.cgi', $text{'index_return'} || 'Return to Databases');
	exit(0);
	}

# Existing database view
&error("No database specified") unless ($db);

my $tables = ovmdb_list_tables($db);
my $size = ovmdb_get_db_size($db);
my $users = ovmdb_list_users();

&ui_print_header(undef, "Database: " . &html_escape($db), '');

print <<EOF;
<style>
.ovmdb-cards { display:flex; flex-wrap:wrap; gap:15px; margin:15px 0; }
.ovmdb-card { flex:1; min-width:150px; max-width:200px; background:#f8f9fa; border:1px solid #dee2e6; border-radius:8px; padding:15px; text-align:center; }
.ovmdb-card h3 { margin:0 0 5px 0; font-size:13px; color:#6c757d; }
.ovmdb-card .ovmdb-value { font-size:22px; font-weight:bold; color:#2c3e50; }
.ovmdb-table { width:100%; border-collapse:collapse; margin:15px 0; }
.ovmdb-table th { background:#2c3e50; color:#fff; padding:8px; text-align:left; font-size:12px; }
.ovmdb-table td { padding:6px 8px; border-bottom:1px solid #dee2e6; font-size:12px; }
.ovmdb-table tr:hover { background:#f1f3f5; }
.ovmdb-btn { display:inline-block; padding:3px 8px; margin:1px; border-radius:3px; font-size:11px; text-decoration:none; color:#fff; }
.ovmdb-btn-blue { background:#3498db; }
.ovmdb-btn-green { background:#27ae60; }
.ovmdb-btn-red { background:#e74c3c; }
.ovmdb-btn-orange { background:#f39c12; }
.ovmdb-section { margin:20px 0; }
.ovmdb-section h2 { font-size:15px; color:#2c3e50; border-bottom:2px solid #3498db; padding-bottom:5px; }
</style>

<div class="ovmdb-cards">
 <div class="ovmdb-card">
  <h3>Database</h3>
  <div class="ovmdb-value" style="font-size:16px;">@{[&html_escape($db)]}</div>
 </div>
 <div class="ovmdb-card">
  <h3>Size</h3>
  <div class="ovmdb-value" style="font-size:18px;">@{[ovmdb_human_size($size)]}</div>
 </div>
 <div class="ovmdb-card">
  <h3>Tables</h3>
  <div class="ovmdb-value">@{[scalar(@$tables)]}</div>
 </div>
 <div class="ovmdb-card">
  <h3>Charset</h3>
  <div class="ovmdb-value" style="font-size:14px;">@{[&html_escape($config->{'default_charset'})]}</div>
 </div>
</div>
EOF

print &ui_hr();

# Action buttons
print &ui_form_start('edit_db.cgi', 'post');
print &ui_hidden('db', $db);
print &ui_form_end([
	[ 'backup_db', 'Backup Now' ],
	[ 'optimize_db', 'Optimize' ],
	[ 'check_db', 'Check Tables' ],
	]);

print '<div style="margin:10px 0;">';
print '<a href="query.cgi?db=' . &urlize($db) . '" class="ovmdb-btn ovmdb-btn-orange">SQL Query</a> ';
print '<a href="backups.cgi?db=' . &urlize($db) . '" class="ovmdb-btn ovmdb-btn-green">View Backups</a> ';
print '</div>';

# Tables section
print <<EOF;
<div class="ovmdb-section">
<h2>Tables</h2>
<table class="ovmdb-table">
<tr>
 <th>Name</th>
 <th>Rows</th>
 <th>Size</th>
 <th>Engine</th>
 <th>Collation</th>
</tr>
EOF

if (scalar(@$tables) > 0) {
	foreach my $t (@$tables) {
		print '<tr>';
		print '<td><strong>' . &html_escape($t->{'name'}) . '</strong></td>';
		print '<td>' . &html_escape($t->{'rows'}) . '</td>';
		print '<td>' . &html_escape($t->{'size_human'}) . '</td>';
		print '<td>' . &html_escape($t->{'engine'}) . '</td>';
		print '<td>' . &html_escape($t->{'collation'}) . '</td>';
		print '</tr>';
		}
	}
else {
	print '<tr><td colspan="5" style="text-align:center;color:#6c757d;">No tables found</td></tr>';
	}

print '</table></div>';

# Users with access to this DB
print <<EOF;
<div class="ovmdb-section">
<h2>Users with Access</h2>
<table class="ovmdb-table">
<tr>
 <th>User</th>
 <th>Host</th>
 <th>Privileges</th>
</tr>
EOF

foreach my $u (@$users) {
	my $has_access = 0;
	foreach my $p (@{$u->{'privileges'}}) {
		$has_access = 1 if ($p =~ /$db/i || $p =~ /\*\.\*/);
		}
	if ($has_access) {
		print '<tr>';
		print '<td>' . &html_escape($u->{'user'}) . '</td>';
		print '<td>' . &html_escape($u->{'host'}) . '</td>';
		print '<td style="font-size:11px;">' . join('<br>', map { &html_escape($_) } @{$u->{'privileges'}}) . '</td>';
		print '</tr>';
		}
	}

print '</table></div>';

# Drop database form
print '<div style="margin-top:20px; padding:15px; background:#fff3cd; border:1px solid #ffc107; border-radius:4px;">';
print &ui_form_start('edit_db.cgi', 'post');
print &ui_hidden('db', $db);
print '<strong style="color:#856404;">Danger Zone:</strong> ';
print &ui_form_end([ [ 'drop_db', 'Delete Database Permanently' ] ]);
print '</div>';

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return to Databases');
