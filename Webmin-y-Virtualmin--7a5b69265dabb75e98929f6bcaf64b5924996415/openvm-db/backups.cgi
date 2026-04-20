#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-db-lib.pl';
&ReadParse();

ovmdb_require_access();
my $config = ovmdb_init();
my $db = $in{'db'};

# Handle create backup
if ($in{'create_backup'}) {
	my $backup_db = $in{'backup_db'} || $db;
	my $ts = `date +%Y%m%d_%H%M%S`;
	chomp($ts);
	my $ext = $in{'backup_type'} eq 'compressed' ? '.sql.gz' : '.sql';
	my $file = "${backup_db}_backup_${ts}${ext}";
	my $res = ovmdb_backup_database($backup_db, $file);
	if ($res->{'ok'}) {
		# Compress if requested
		if ($in{'backup_type'} eq 'compressed') {
			my $path = $res->{'file'};
			`gzip -f "$path" 2>/dev/null`;
			}
		}
	else {
		&error("Backup failed: " . &html_escape($res->{'error'}));
		}
	}

# Handle restore backup
if ($in{'restore_backup'} && $in{'restore_file'}) {
	my $restore_db = $in{'restore_db'} || $db;
	my $res = ovmdb_restore_database($restore_db, $in{'restore_file'});
	if (!$res->{'ok'}) {
		&error("Restore failed: " . &html_escape($res->{'error'}));
		}
	}

# Handle delete backup
if ($in{'delete_backup'} && $in{'delete_file'}) {
	if (-f $in{'delete_file'}) {
		unlink($in{'delete_file'}) || &error("Failed to delete backup: $!");
		}
	}

my $backups = ovmdb_list_backups($db);
my $dbs = ovmdb_list_databases();
my $config_obj = ovmdb_module_config();
my $backup_dir = $config_obj->{'backup_dir'};

# Calculate total backup size
my $total_backup_size = 0;
foreach my $b (@$backups) {
	$total_backup_size += $b->{'size'};
	}

# Get disk usage of backup dir
my $disk_usage = `du -sh "$backup_dir" 2>/dev/null`;
chomp($disk_usage);
$disk_usage =~ s/\s.*$//;

&ui_print_header(undef, 'Database Backups', '');

print <<EOF;
<style>
.ovmdb-cards { display:flex; flex-wrap:wrap; gap:15px; margin:15px 0; }
.ovmdb-card { flex:1; min-width:180px; max-width:220px; background:#f8f9fa; border:1px solid #dee2e6; border-radius:8px; padding:15px; text-align:center; }
.ovmdb-card h3 { margin:0 0 5px 0; font-size:13px; color:#6c757d; }
.ovmdb-card .ovmdb-value { font-size:22px; font-weight:bold; color:#2c3e50; }
.ovmdb-table { width:100%; border-collapse:collapse; margin:15px 0; }
.ovmdb-table th { background:#2c3e50; color:#fff; padding:8px; text-align:left; font-size:12px; }
.ovmdb-table td { padding:6px 8px; border-bottom:1px solid #dee2e6; font-size:12px; }
.ovmdb-table tr:hover { background:#f1f3f5; }
.ovmdb-btn { display:inline-block; padding:3px 8px; margin:1px; border-radius:3px; font-size:11px; text-decoration:none; color:#fff; border:none; cursor:pointer; }
.ovmdb-btn-blue { background:#3498db; }
.ovmdb-btn-green { background:#27ae60; }
.ovmdb-btn-red { background:#e74c3c; }
.ovmdb-btn-orange { background:#f39c12; }
.ovmdb-section { margin:20px 0; }
.ovmdb-section h2 { font-size:15px; color:#2c3e50; border-bottom:2px solid #3498db; padding-bottom:5px; }
.ovmdb-form-box { background:#f8f9fa; border:1px solid #dee2e6; border-radius:4px; padding:15px; margin:15px 0; }
.ovmdb-form-box h3 { margin:0 0 10px 0; font-size:14px; color:#2c3e50; }
</style>

<div class="ovmdb-cards">
 <div class="ovmdb-card">
  <h3>Total Backups</h3>
  <div class="ovmdb-value">@{[scalar(@$backups)]}</div>
 </div>
 <div class="ovmdb-card">
  <h3>Backup Size</h3>
  <div class="ovmdb-value" style="font-size:18px;">@{[ovmdb_human_size($total_backup_size)]}</div>
 </div>
 <div class="ovmdb-card">
  <h3>Disk Usage</h3>
  <div class="ovmdb-value" style="font-size:18px;">@{[&html_escape($disk_usage || 'N/A')]}</div>
 </div>
 <div class="ovmdb-card">
  <h3>Backup Dir</h3>
  <div class="ovmdb-value" style="font-size:12px;">@{[&html_escape($backup_dir)]}</div>
 </div>
</div>
EOF

print &ui_hr();

# Create backup form
print '<div class="ovmdb-form-box">';
print '<h3>Create New Backup</h3>';
print &ui_form_start('backups.cgi', 'post');

my $db_opts = '';
foreach my $d (@$dbs) {
	my $sel = ($d->{'name'} eq $db) ? ' selected' : '';
	$db_opts .= '<option value="' . &html_escape($d->{'name'}) . "\"$sel>" . &html_escape($d->{'name'}) . '</option>';
	}
print '<div style="display:flex;gap:10px;flex-wrap:wrap;align-items:center;">';
print 'Database: <select name="backup_db" style="padding:4px;">' . $db_opts . '</select> ';
print 'Type: <select name="backup_type" style="padding:4px;"><option value="full">Full SQL</option><option value="compressed">Compressed (.gz)</option></select> ';
print '<input type="submit" name="create_backup" value="Create Backup" class="ovmdb-btn ovmdb-btn-green">';
print '</div>';
print &ui_form_end();
print '</div>';

# Backups table
print '<div class="ovmdb-section">';
print '<h2>Existing Backups</h2>';
print '<table class="ovmdb-table">';
print '<tr><th>Database</th><th>Date</th><th>Size</th><th>Type</th><th>Actions</th></tr>';

if (scalar(@$backups) > 0) {
	foreach my $b (@$backups) {
		my $bname = $b->{'file'};
		$bname =~ s/^(.+)_backup_.+$/$1/;

		print '<tr>';
		print '<td><strong>' . &html_escape($bname) . '</strong></td>';
		print '<td>' . &html_escape($b->{'date_human'}) . '</td>';
		print '<td>' . &html_escape($b->{'size_human'}) . '</td>';
		print '<td>' . &html_escape($b->{'type'}) . '</td>';
		print '<td>';

		# Restore form
		print '<form method="post" action="backups.cgi" style="display:inline;">';
		print '<input type="hidden" name="restore_file" value="' . &html_escape($b->{'path'}) . '">';
		print '<select name="restore_db" style="padding:2px;font-size:11px;">' . $db_opts . '</select> ';
		print '<input type="submit" name="restore_backup" value="Restore" class="ovmdb-btn ovmdb-btn-blue" onclick="return confirm(\'Restore backup? This will overwrite existing data.\')">';
		print '</form> ';

		# Delete form
		print '<form method="post" action="backups.cgi" style="display:inline;">';
		print '<input type="hidden" name="delete_file" value="' . &html_escape($b->{'path'}) . '">';
		print '<input type="submit" name="delete_backup" value="Delete" class="ovmdb-btn ovmdb-btn-red" onclick="return confirm(\'Delete this backup permanently?\')">';
		print '</form>';

		print '</td>';
		print '</tr>';
		}
	}
else {
	print '<tr><td colspan="5" style="text-align:center;color:#6c757d;">No backups found</td></tr>';
	}

print '</table></div>';

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return to Databases');
