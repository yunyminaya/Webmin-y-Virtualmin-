#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-db-lib.pl';
&ReadParse();

ovmdb_require_access();
my $config = ovmdb_init();
my $db = $in{'db'};
my $query = $in{'query'};
my $result;

# Execute query
if ($in{'execute'} && $db && $query) {
	$result = ovmdb_run_query($db, $query);
	}

# Quick queries
if ($in{'quick_tables'} && $db) {
	$query = 'SHOW TABLES';
	$result = ovmdb_run_query($db, $query);
	}
elsif ($in{'quick_status'} && $db) {
	$query = 'SHOW STATUS';
	$result = ovmdb_run_query($db, $query);
	}
elsif ($in{'quick_processlist'} && $db) {
	$query = 'SHOW PROCESSLIST';
	$result = ovmdb_run_query($db, $query);
	}
elsif ($in{'quick_databases'}) {
	$query = 'SHOW DATABASES';
	$result = ovmdb_run_query($db || 'mysql', $query);
	}

my $dbs = ovmdb_list_databases();

&ui_print_header(undef, 'SQL Query Interface', '');

print <<EOF;
<style>
.ovmdb-query-area { width:100%; min-height:150px; font-family:monospace; font-size:13px; padding:10px; border:1px solid #dee2e6; border-radius:4px; resize:vertical; }
.ovmdb-table { width:100%; border-collapse:collapse; margin:15px 0; font-size:12px; }
.ovmdb-table th { background:#2c3e50; color:#fff; padding:6px 8px; text-align:left; }
.ovmdb-table td { padding:5px 8px; border-bottom:1px solid #dee2e6; }
.ovmdb-table tr:hover { background:#f1f3f5; }
.ovmdb-result-box { background:#f8f9fa; border:1px solid #dee2e6; border-radius:4px; padding:15px; margin:15px 0; }
.ovmdb-btn { display:inline-block; padding:4px 10px; margin:2px; border-radius:4px; font-size:12px; cursor:pointer; border:none; color:#fff; }
.ovmdb-btn-blue { background:#3498db; }
.ovmdb-btn-gray { background:#6c757d; }
.ovmdb-btn-orange { background:#f39c12; }
.ovmdb-section { margin:20px 0; }
.ovmdb-section h2 { font-size:15px; color:#2c3e50; border-bottom:2px solid #3498db; padding-bottom:5px; }
.ovmdb-error { background:#f8d7da; border:1px solid #f5c6cb; color:#721c24; padding:10px; border-radius:4px; margin:10px 0; }
.ovmdb-success { background:#d4edda; border:1px solid #c3e6cb; color:#155724; padding:10px; border-radius:4px; margin:10px 0; }
</style>
EOF

# Query form
print &ui_form_start('query.cgi', 'post');
print &ui_table_start('SQL Query', 'width=100%', 2);

my $db_options = '';
foreach my $d (@$dbs) {
	my $sel = ($d->{'name'} eq $db) ? ' selected' : '';
	$db_options .= '<option value="' . &html_escape($d->{'name'}) . "\"$sel>" . &html_escape($d->{'name'}) . "</option>\n";
	}
print &ui_table_row('Database', '<select name="db" style="padding:5px;min-width:200px;">' . $db_options . '</select>');
print &ui_table_row('Query', '<textarea name="query" class="ovmdb-query-area">' . &html_escape($query || '') . '</textarea>');
print &ui_table_end();

print '<div style="margin:10px 0;">';
print '<input type="submit" name="execute" value="Execute Query" class="ovmdb-btn ovmdb-btn-blue"> ';
print '<input type="submit" name="quick_tables" value="SHOW TABLES" class="ovmdb-btn ovmdb-btn-gray"> ';
print '<input type="submit" name="quick_status" value="SHOW STATUS" class="ovmdb-btn ovmdb-btn-gray"> ';
print '<input type="submit" name="quick_processlist" value="SHOW PROCESSLIST" class="ovmdb-btn ovmdb-btn-gray"> ';
print '<input type="submit" name="quick_databases" value="SHOW DATABASES" class="ovmdb-btn ovmdb-btn-gray"> ';
print '</div>';
print &ui_form_end();

# Display results
if ($result) {
	if ($result->{'ok'}) {
		my $rows = $result->{'rows'};
		my $count = $result->{'count'};
		print '<div class="ovmdb-success">Query executed successfully. ' . &html_escape($count) . ' row(s) returned.</div>';

		if ($count > 0 && $count <= 500) {
			print '<div class="ovmdb-section">';
			print '<h2>Results (' . &html_escape($count) . ' rows)</h2>';
			print '<div style="overflow-x:auto;">';
			print '<table class="ovmdb-table">';
			print '<tr>';
			my $first_row = $rows->[0];
			if ($first_row) {
				for (my $i = 0; $i < scalar(@$first_row); $i++) {
					print '<th>Column ' . ($i + 1) . '</th>';
					}
				}
			print '</tr>';
			foreach my $row (@$rows) {
				print '<tr>';
				foreach my $col (@$row) {
					print '<td>' . &html_escape($col // '') . '</td>';
					}
				print '</tr>';
				}
			print '</table></div></div>';
			}
		elsif ($count > 500) {
			print '<div class="ovmdb-result-box">Too many results (' . &html_escape($count) . ' rows). Showing first 500.';
			print '<table class="ovmdb-table"><tr>';
			my $first_row = $rows->[0];
			for (my $i = 0; $i < scalar(@$first_row); $i++) {
				print '<th>Column ' . ($i + 1) . '</th>';
				}
			print '</tr>';
			my $limit = 500;
			$limit = scalar(@$rows) if (scalar(@$rows) < $limit);
			for (my $r = 0; $r < $limit; $r++) {
				print '<tr>';
				foreach my $col (@{$rows->[$r]}) {
					print '<td>' . &html_escape($col // '') . '</td>';
					}
				print '</tr>';
				}
			print '</table></div>';
			}
		}
	else {
		print '<div class="ovmdb-error">Error: ' . &html_escape($result->{'error'}) . '</div>';
		}
	}

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return to Databases');
