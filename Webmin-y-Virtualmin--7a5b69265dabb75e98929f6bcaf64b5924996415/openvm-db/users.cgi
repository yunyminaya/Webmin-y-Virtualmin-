#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-db-lib.pl';
&ReadParse();

ovmdb_require_access();
my $config = ovmdb_init();

# Handle create user
if ($in{'create_user'}) {
	my $res = ovmdb_create_user($in{'new_user'}, $in{'new_pass'}, $in{'new_host'});
	if ($res->{'ok'}) {
		# Grant privileges if specified
		if ($in{'grant_db'} && $in{'grant_db'} ne '') {
			ovmdb_grant_privileges($in{'new_user'}, $in{'grant_db'}, $in{'grant_privs'} || 'ALL');
			}
		}
	else {
		&error("Failed to create user: " . &html_escape($res->{'error'}));
		}
	}

# Handle drop user
if ($in{'drop_user'}) {
	my $res = ovmdb_drop_user($in{'drop_user'}, $in{'drop_host'});
	if (!$res->{'ok'}) {
		&error("Failed to drop user: " . &html_escape($res->{'error'}));
		}
	}

# Handle grant privileges
if ($in{'grant_privileges'}) {
	my $res = ovmdb_grant_privileges($in{'guser'}, $in{'gdb'}, $in{'gprivs'});
	if (!$res->{'ok'}) {
		&error("Failed to grant privileges: " . &html_escape($res->{'error'}));
		}
	}

# Handle revoke privileges
if ($in{'revoke_privileges'}) {
	my $res = ovmdb_revoke_privileges($in{'ruser'}, $in{'rdb'});
	if (!$res->{'ok'}) {
		&error("Failed to revoke privileges: " . &html_escape($res->{'error'}));
		}
	}

my $users = ovmdb_list_users();
my $dbs = ovmdb_list_databases();

&ui_print_header(undef, 'Database Users', '');

print <<EOF;
<style>
.ovmdb-table { width:100%; border-collapse:collapse; margin:15px 0; }
.ovmdb-table th { background:#2c3e50; color:#fff; padding:8px; text-align:left; font-size:12px; }
.ovmdb-table td { padding:6px 8px; border-bottom:1px solid #dee2e6; font-size:12px; vertical-align:top; }
.ovmdb-table tr:hover { background:#f1f3f5; }
.ovmdb-btn { display:inline-block; padding:3px 8px; margin:1px; border-radius:3px; font-size:11px; text-decoration:none; color:#fff; border:none; cursor:pointer; }
.ovmdb-btn-blue { background:#3498db; }
.ovmdb-btn-green { background:#27ae60; }
.ovmdb-btn-red { background:#e74c3c; }
.ovmdb-section { margin:20px 0; }
.ovmdb-section h2 { font-size:15px; color:#2c3e50; border-bottom:2px solid #3498db; padding-bottom:5px; }
.ovmdb-form-box { background:#f8f9fa; border:1px solid #dee2e6; border-radius:4px; padding:15px; margin:15px 0; }
.ovmdb-form-box h3 { margin:0 0 10px 0; font-size:14px; color:#2c3e50; }
.ovmdb-priv-tag { display:inline-block; padding:2px 6px; margin:1px; background:#e9ecef; border-radius:3px; font-size:10px; color:#495057; }
</style>
EOF

# Users table
print '<div class="ovmdb-section">';
print '<h2>Database Users (' . scalar(@$users) . ')</h2>';
print '<table class="ovmdb-table">';
print '<tr><th>User</th><th>Host</th><th>Privileges</th><th>Actions</th></tr>';

if (scalar(@$users) > 0) {
	foreach my $u (@$users) {
		my $privs_html = '';
		foreach my $p (@{$u->{'privileges'}}) {
			$privs_html .= '<span class="ovmdb-priv-tag">' . &html_escape($p) . '</span> ';
			}
		print '<tr>';
		print '<td><strong>' . &html_escape($u->{'user'}) . '</strong></td>';
		print '<td>' . &html_escape($u->{'host'}) . '</td>';
		print '<td>' . $privs_html . '</td>';
		print '<td>';
		print '<form method="post" action="users.cgi" style="display:inline;">';
		print '<input type="hidden" name="drop_user" value="' . &html_escape($u->{'user'}) . '">';
		print '<input type="hidden" name="drop_host" value="' . &html_escape($u->{'host'}) . '">';
		print '<input type="submit" value="Delete" class="ovmdb-btn ovmdb-btn-red" onclick="return confirm(\'Delete user " . &html_escape($u->{'user'}) . "?\')">';
		print '</form>';
		print '</td>';
		print '</tr>';
		}
	}
else {
	print '<tr><td colspan="4" style="text-align:center;color:#6c757d;">No users found</td></tr>';
	}

print '</table></div>';

# Create user form
print <<EOF;
<div class="ovmdb-form-box">
<h3>Create New User</h3>
EOF

print &ui_form_start('users.cgi', 'post');
print &ui_table_start('New User', 'width=100%', 2);
print &ui_table_row('Username', &ui_textbox('new_user', '', 30));
print &ui_table_row('Password', &ui_password('new_pass', '', 30));
print &ui_table_row('Host', &ui_textbox('new_host', 'localhost', 30));

my $db_opts = '<option value="">-- None --</option>';
foreach my $d (@$dbs) {
	$db_opts .= '<option value="' . &html_escape($d->{'name'}) . '">' . &html_escape($d->{'name'}) . '</option>';
	}
print &ui_table_row('Grant access to DB', '<select name="grant_db">' . $db_opts . '</select>');

my $priv_opts = '<option value="ALL">ALL PRIVILEGES</option>';
$priv_opts .= '<option value="SELECT">SELECT</option>';
$priv_opts .= '<option value="SELECT,INSERT">SELECT, INSERT</option>';
$priv_opts .= '<option value="SELECT,INSERT,UPDATE,DELETE">SELECT, INSERT, UPDATE, DELETE</option>';
$priv_opts .= '<option value="SELECT,INSERT,UPDATE,DELETE,CREATE,ALTER,INDEX">Full CRUD + DDL</option>';
print &ui_table_row('Privileges', '<select name="grant_privs">' . $priv_opts . '</select>');

print &ui_table_end();
print &ui_form_end([ [ 'create_user', 'Create User' ] ]);
print '</div>';

# Grant/Revoke forms
print <<EOF;
<div class="ovmdb-form-box">
<h3>Manage Permissions</h3>
EOF

print &ui_form_start('users.cgi', 'post');
print '<div style="display:flex;gap:15px;flex-wrap:wrap;">';

# Grant form
print '<div style="flex:1;min-width:250px;">';
print '<h4 style="font-size:13px;color:#27ae60;">Grant Privileges</h4>';
my $user_opts = '';
foreach my $u (@$users) {
	$user_opts .= '<option value="' . &html_escape($u->{'user'}) . '">' . &html_escape($u->{'user'}) . '</option>';
	}
print 'User: <select name="guser" style="margin:5px 0;">' . $user_opts . '</select><br>';

my $db_opts2 = '';
foreach my $d (@$dbs) {
	$db_opts2 .= '<option value="' . &html_escape($d->{'name'}) . '">' . &html_escape($d->{'name'}) . '</option>';
	}
print 'Database: <select name="gdb" style="margin:5px 0;">' . $db_opts2 . '</select><br>';

my $priv_opts2 = '<option value="ALL">ALL</option><option value="SELECT">SELECT</option><option value="SELECT,INSERT,UPDATE,DELETE">CRUD</option>';
print 'Privileges: <select name="gprivs" style="margin:5px 0;">' . $priv_opts2 . '</select><br>';
print '<input type="submit" name="grant_privileges" value="Grant" class="ovmdb-btn ovmdb-btn-green" style="margin-top:5px;">';
print '</div>';

# Revoke form
print '<div style="flex:1;min-width:250px;">';
print '<h4 style="font-size:13px;color:#e74c3c;">Revoke Privileges</h4>';
print 'User: <select name="ruser" style="margin:5px 0;">' . $user_opts . '</select><br>';
print 'Database: <select name="rdb" style="margin:5px 0;">' . $db_opts2 . '</select><br>';
print '<input type="submit" name="revoke_privileges" value="Revoke All" class="ovmdb-btn ovmdb-btn-red" style="margin-top:5px;" onclick="return confirm(\'Revoke all privileges?\')">';
print '</div>';

print '</div>';
print &ui_form_end();
print '</div>';

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return to Databases');
