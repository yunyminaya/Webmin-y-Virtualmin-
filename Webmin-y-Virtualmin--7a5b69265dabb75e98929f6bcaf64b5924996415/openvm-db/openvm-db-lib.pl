#!/usr/bin/perl

use strict;
use warnings;

our (%in, %text, $module_config_directory, $base_remote_user);
our $OPENVM_DB_VIRTUALMIN_LOADED = 0;

###############################################################################
# SECURITY: Sanitization helpers for SQL and shell inputs
###############################################################################

# Whitelist of valid MySQL charsets
my %OVMDB_ALLOWED_CHARSETS = map { $_ => 1 } qw(
	utf8 utf8mb4 latin1 ascii binary big5 cp1252 cp850 dec8 euckr gb2312 gbk
	geostd8 greek hebrew hp8 keybcs2 koi8r koi8u latin2 latin5 latin7 macce
	macroman sjis swe7 tis620 ucs2 ujis utf16 utf16le utf32
);

# Whitelist of valid MySQL/PostgreSQL privilege names
my %OVMDB_ALLOWED_PRIVS = map { $_ => 1 } qw(
	ALL ALTER CREATE DELETE DROP EXECUTE GRANT INDEX INSERT REFERENCES SELECT
	UPDATE USAGE CREATE ROUTINE ALTER ROUTINE CREATE VIEW CREATE TEMPORARY TABLES
	LOCK TABLES EVENT TRIGGER SHOW VIEW RELOAD SHUTDOWN PROCESS FILE
	CONNECT TEMPORARY CREATE USER REPLICATION SLAVE REPLICATION CLIENT
	SHOW DATABASES SUPER
);

# ovmdb_sanitize_sql_identifier - Only allow word chars in SQL identifiers
sub ovmdb_sanitize_sql_identifier
{
my ($id) = @_;
return undef unless (defined($id) && $id =~ /^[\w]+$/);
return $id;
}

# ovmdb_sanitize_sql_string - Escape single quotes for SQL string literals
sub ovmdb_sanitize_sql_string
{
my ($str) = @_;
return '' unless (defined($str));
$str =~ s/'/''/g;
$str =~ s/\\/\\\\/g;
return $str;
}

# ovmdb_sanitize_charset - Validate charset against whitelist
sub ovmdb_sanitize_charset
{
my ($charset) = @_;
return undef unless (defined($charset) && exists($OVMDB_ALLOWED_CHARSETS{lc($charset)}));
return $charset;
}

# ovmdb_sanitize_privs - Validate privilege list against whitelist
sub ovmdb_sanitize_privs
{
my ($privs) = @_;
return undef unless (defined($privs) && $privs ne '');
return 'ALL' if ($privs eq 'ALL' || $privs eq 'ALL PRIVILEGES');
my @parts = split(/,\s*/, $privs);
my @safe;
foreach my $p (@parts) {
	$p =~ s/^\s+//; $p =~ s/\s+$//;
	$p = uc($p);
	return undef unless (exists($OVMDB_ALLOWED_PRIVS{$p}));
	push(@safe, $p);
	}
return join(', ', @safe);
}

# ovmdb_sanitize_filepath - Prevent path traversal in file paths
sub ovmdb_sanitize_filepath
{
my ($file) = @_;
return undef unless (defined($file) && $file ne '');
# Remove any path traversal attempts
$file =~ s/\.\.//g;
$file =~ s/[;\|`&\$]//g;
# Only allow safe filename chars
return undef unless ($file =~ /^[\w.\-]+$/);
return $file;
}

###############################################################################
# ovmdb_text - Get text string with fallback
###############################################################################
sub ovmdb_text
{
my ($key, $fallback) = @_;
return exists($text{$key}) && defined($text{$key}) && $text{$key} ne ''
	? $text{$key}
	: $fallback;
}

###############################################################################
# ovmdb_module_config - Read module configuration
###############################################################################
sub ovmdb_module_config
{
my %config = (
	'db_manager' => 'mysql',
	'backup_dir' => '/var/db-backups',
	'max_backups' => 30,
	'allow_remote' => 'no',
	'default_charset' => 'utf8mb4',
	);
my $config_file = $module_config_directory ? "$module_config_directory/config" : undef;
if ($config_file && -r $config_file) {
	open(my $fh, '<', $config_file) || die "Failed to read $config_file : $!";
	while(my $line = <$fh>) {
		chomp($line);
		next if ($line =~ /^\s*#/ || $line !~ /=/);
		my ($key, $value) = split(/=/, $line, 2);
		next if (!defined($key) || $key eq '');
		$config{$key} = $value;
		}
	close($fh);
	}
return \%config;
}

###############################################################################
# ovmdb_init - Initialize module
###############################################################################
sub ovmdb_init
{
my $config = ovmdb_module_config();
if (!-d $config->{'backup_dir'}) {
	eval { mkdir($config->{'backup_dir'}, 0755); };
	}
return $config;
}

###############################################################################
# ovmdb_load_virtualmin - Load Virtualmin library
###############################################################################
sub ovmdb_load_virtualmin
{
return 1 if ($OPENVM_DB_VIRTUALMIN_LOADED);
&foreign_require("virtual-server", "virtual-server-lib.pl");
$OPENVM_DB_VIRTUALMIN_LOADED = 1;
return 1;
}

###############################################################################
# ovmdb_require_access - Check access permissions
###############################################################################
sub ovmdb_require_access
{
ovmdb_load_virtualmin();
return 1 if (defined(&master_admin) && &master_admin());
return 1 if (defined(&can_edit_domain) && &can_edit_domain());
&error(ovmdb_text('db_ecannot', 'You cannot manage databases from OpenVM Database Manager'));
}

###############################################################################
# ovmdb_human_size - Format bytes to human readable
###############################################################################
sub ovmdb_human_size
{
my ($bytes) = @_;
$bytes ||= 0;
return '0 B' if ($bytes == 0);
my @units = ('B', 'KB', 'MB', 'GB', 'TB');
my $i = 0;
while ($bytes >= 1024 && $i < scalar(@units) - 1) {
	$bytes /= 1024;
	$i++;
	}
return sprintf("%.2f %s", $bytes, $units[$i]);
}

###############################################################################
# ovmdb_list_databases - List all databases
###############################################################################
sub ovmdb_list_databases
{
my $config = ovmdb_module_config();
my @dbs;
if ($config->{'db_manager'} eq 'mysql') {
	my $out = `mysql -BNe "SHOW DATABASES" 2>/dev/null`;
	foreach my $line (split(/\n/, $out)) {
		chomp($line);
		next if ($line =~ /^(information_schema|performance_schema|mysql|sys)$/);
		my $size = ovmdb_get_db_size($line);
		my $charset_out = `mysql -BNe "SELECT DEFAULT_CHARACTER_SET_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$line'" 2>/dev/null`;
		chomp($charset_out);
		my $tables_out = `mysql -BNe "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='$line'" 2>/dev/null`;
		chomp($tables_out);
		push(@dbs, {
			'name' => $line,
			'charset' => $charset_out || 'unknown',
			'size' => $size,
			'size_human' => ovmdb_human_size($size),
			'tables' => $tables_out || 0,
			});
		}
	}
elsif ($config->{'db_manager'} eq 'postgresql') {
	my $out = `psql -Alt 2>/dev/null`;
	foreach my $line (split(/\n/, $out)) {
		my @fields = split(/\|/, $line);
		next if ($fields[1] =~ /^(template0|template1|postgres)$/);
		my $name = $fields[0] || $fields[1];
		next unless ($name);
		my $size = ovmdb_get_db_size($name);
		push(@dbs, {
			'name' => $name,
			'charset' => 'UTF8',
			'size' => $size,
			'size_human' => ovmdb_human_size($size),
			'tables' => 0,
			});
		}
	}
return \@dbs;
}

###############################################################################
# ovmdb_list_tables - List tables in a database
###############################################################################
sub ovmdb_list_tables
{
my ($db) = @_;
return [] unless ($db && $db =~ /^\w+$/);
my $config = ovmdb_module_config();
my @tables;
if ($config->{'db_manager'} eq 'mysql') {
	my $out = `mysql -BNe "SELECT TABLE_NAME, TABLE_ROWS, DATA_LENGTH+INDEX_LENGTH, ENGINE, TABLE_COLLATION FROM information_schema.TABLES WHERE TABLE_SCHEMA='$db' ORDER BY TABLE_NAME" 2>/dev/null`;
	foreach my $line (split(/\n/, $out)) {
		my @f = split(/\t/, $line);
		push(@tables, {
			'name' => $f[0],
			'rows' => $f[1] || 0,
			'size' => $f[2] || 0,
			'size_human' => ovmdb_human_size($f[2] || 0),
			'engine' => $f[3] || 'unknown',
			'collation' => $f[4] || 'unknown',
			});
		}
	}
elsif ($config->{'db_manager'} eq 'postgresql') {
	my $out = `psql -At -c "SELECT tablename, n_live_tup FROM pg_stat_user_tables WHERE schemaname='public'" "$db" 2>/dev/null`;
	foreach my $line (split(/\n/, $out)) {
		my @f = split(/\|/, $line);
		push(@tables, {
			'name' => $f[0],
			'rows' => $f[1] || 0,
			'size' => 0,
			'size_human' => '0 B',
			'engine' => 'PostgreSQL',
			'collation' => 'UTF8',
			});
		}
	}
return \@tables;
}

###############################################################################
# ovmdb_create_database - Create a new database
###############################################################################
sub ovmdb_create_database
{
my ($name, $charset) = @_;
return { 'ok' => 0, 'error' => 'Invalid database name' } unless ($name && $name =~ /^[\w]+$/);
$charset ||= ovmdb_module_config()->{'default_charset'} || 'utf8mb4';
# SECURITY: Validate charset against whitelist
my $safe_charset = ovmdb_sanitize_charset($charset);
return { 'ok' => 0, 'error' => 'Invalid charset name' } unless ($safe_charset);
my $config = ovmdb_module_config();
if ($config->{'db_manager'} eq 'mysql') {
my $out = `mysql -e "CREATE DATABASE \`$name\` CHARACTER SET $safe_charset" 2>&1`;
	if ($?) {
		return { 'ok' => 0, 'error' => $out };
		}
	}
elsif ($config->{'db_manager'} eq 'postgresql') {
	my $out = `createdb -E UTF8 "$name" 2>&1`;
	if ($?) {
		return { 'ok' => 0, 'error' => $out };
		}
	}
return { 'ok' => 1, 'error' => '' };
}

###############################################################################
# ovmdb_drop_database - Drop a database
###############################################################################
sub ovmdb_drop_database
{
my ($name) = @_;
return { 'ok' => 0, 'error' => 'Invalid database name' } unless ($name && $name =~ /^[\w]+$/);
my $config = ovmdb_module_config();
if ($config->{'db_manager'} eq 'mysql') {
	my $out = `mysql -e "DROP DATABASE \`$name\`" 2>&1`;
	if ($?) {
		return { 'ok' => 0, 'error' => $out };
		}
	}
elsif ($config->{'db_manager'} eq 'postgresql') {
	my $out = `dropdb "$name" 2>&1`;
	if ($?) {
		return { 'ok' => 0, 'error' => $out };
		}
	}
return { 'ok' => 1, 'error' => '' };
}

###############################################################################
# ovmdb_backup_database - Backup a database
###############################################################################
sub ovmdb_backup_database
{
my ($db, $file) = @_;
return { 'ok' => 0, 'error' => 'Invalid parameters' } unless ($db && $file);
my $config = ovmdb_module_config();
# SECURITY: Sanitize filename to prevent path traversal
my $safe_file = ovmdb_sanitize_filepath($file);
return { 'ok' => 0, 'error' => 'Invalid backup filename' } unless ($safe_file);
$file = $config->{'backup_dir'} . '/' . $safe_file unless ($safe_file =~ m{^/});
if ($config->{'db_manager'} eq 'mysql') {
	my $out = `mysqldump --single-transaction --routines --triggers "$db" > "$file" 2>&1`;
	if ($?) {
		return { 'ok' => 0, 'error' => $out };
		}
	}
elsif ($config->{'db_manager'} eq 'postgresql') {
	my $out = `pg_dump "$db" > "$file" 2>&1`;
	if ($?) {
		return { 'ok' => 0, 'error' => $out };
		}
	}
my $size = -s $file || 0;
return { 'ok' => 1, 'error' => '', 'file' => $file, 'size' => $size };
}

###############################################################################
# ovmdb_restore_database - Restore a database from backup
###############################################################################
sub ovmdb_restore_database
{
my ($db, $file) = @_;
return { 'ok' => 0, 'error' => 'Invalid parameters' } unless ($db && $file);
return { 'ok' => 0, 'error' => 'Backup file not found' } unless (-r $file);
my $config = ovmdb_module_config();
if ($config->{'db_manager'} eq 'mysql') {
	my $out = `mysql "$db" < "$file" 2>&1`;
	if ($?) {
		return { 'ok' => 0, 'error' => $out };
		}
	}
elsif ($config->{'db_manager'} eq 'postgresql') {
	my $out = `psql -d "$db" -f "$file" 2>&1`;
	if ($?) {
		return { 'ok' => 0, 'error' => $out };
		}
	}
return { 'ok' => 1, 'error' => '' };
}

###############################################################################
# ovmdb_get_db_size - Get database size in bytes
###############################################################################
sub ovmdb_get_db_size
{
my ($db) = @_;
return 0 unless ($db && $db =~ /^[\w]+$/);
my $config = ovmdb_module_config();
if ($config->{'db_manager'} eq 'mysql') {
	my $out = `mysql -BNe "SELECT SUM(data_length+index_length) FROM information_schema.TABLES WHERE table_schema='$db'" 2>/dev/null`;
	chomp($out);
	return int($out || 0);
	}
elsif ($config->{'db_manager'} eq 'postgresql') {
	my $out = `psql -At -c "SELECT pg_database_size('$db')" 2>/dev/null`;
	chomp($out);
	return int($out || 0);
	}
return 0;
}

###############################################################################
# ovmdb_list_users - List database users
###############################################################################
sub ovmdb_list_users
{
my $config = ovmdb_module_config();
my @users;
if ($config->{'db_manager'} eq 'mysql') {
	my $out = `mysql -BNe "SELECT User, Host FROM mysql.user ORDER BY User" 2>/dev/null`;
	foreach my $line (split(/\n/, $out)) {
		my @f = split(/\t/, $line);
		next unless ($f[0]);
		# SECURITY: Sanitize user/host from DB output before using in SQL
		my $safe_f0 = ovmdb_sanitize_sql_identifier($f[0]) || $f[0];
		$safe_f0 =~ s/[^a-zA-Z0-9_\-.]//g;
		my $safe_f1 = $f[1] || 'localhost';
		$safe_f1 =~ s/[^a-zA-Z0-9_\-.%]//g;
		my $privs_out = `mysql -BNe "SHOW GRANTS FOR '$safe_f0'\@'$safe_f1'" 2>/dev/null`;
		my @privs;
		foreach my $pline (split(/\n/, $privs_out)) {
			push(@privs, $pline) if ($pline);
			}
		push(@users, {
			'user' => $f[0],
			'host' => $f[1] || 'localhost',
			'privileges' => \@privs,
			});
		}
	}
elsif ($config->{'db_manager'} eq 'postgresql') {
	my $out = `psql -At -c "SELECT usename, usesuper FROM pg_user ORDER BY usename" 2>/dev/null`;
	foreach my $line (split(/\n/, $out)) {
		my @f = split(/\|/, $line);
		push(@users, {
			'user' => $f[0],
			'host' => 'localhost',
			'privileges' => [$f[1] eq 't' ? 'SUPERUSER' : 'NORMAL'],
			});
		}
	}
return \@users;
}

###############################################################################
# ovmdb_create_user - Create a database user
###############################################################################
sub ovmdb_create_user
{
my ($user, $pass, $host) = @_;
return { 'ok' => 0, 'error' => 'Invalid username' } unless ($user && $user =~ /^[\w]+$/);
$host ||= 'localhost';
my $config = ovmdb_module_config();
if ($config->{'db_manager'} eq 'mysql') {
	# SECURITY: Escape password for SQL string literal
	my $safe_pass = ovmdb_sanitize_sql_string($pass);
	my $safe_host = ovmdb_sanitize_sql_string($host);
	my $out = `mysql -e "CREATE USER '$user'\@'$safe_host' IDENTIFIED BY '$safe_pass'" 2>&1`;
	if ($?) {
		return { 'ok' => 0, 'error' => $out };
		}
	}
elsif ($config->{'db_manager'} eq 'postgresql') {
	my $out = `psql -c "CREATE USER $user WITH PASSWORD '$safe_pass'" 2>&1`;
	if ($?) {
		return { 'ok' => 0, 'error' => $out };
		}
	}
return { 'ok' => 1, 'error' => '' };
}

###############################################################################
# ovmdb_drop_user - Drop a database user
###############################################################################
sub ovmdb_drop_user
{
my ($user, $host) = @_;
return { 'ok' => 0, 'error' => 'Invalid username' } unless ($user && $user =~ /^[\w]+$/);
$host ||= 'localhost';
my $config = ovmdb_module_config();
if ($config->{'db_manager'} eq 'mysql') {
	my $out = `mysql -e "DROP USER '$user'\@'$host'" 2>&1`;
	if ($?) {
		return { 'ok' => 0, 'error' => $out };
		}
	}
elsif ($config->{'db_manager'} eq 'postgresql') {
	my $out = `psql -c "DROP USER $user" 2>&1`;
	if ($?) {
		return { 'ok' => 0, 'error' => $out };
		}
	}
return { 'ok' => 1, 'error' => '' };
}

###############################################################################
# ovmdb_grant_privileges - Grant privileges to user on database
###############################################################################
sub ovmdb_grant_privileges
{
my ($user, $db, $privs) = @_;
return { 'ok' => 0, 'error' => 'Invalid parameters' } unless ($user && $db);
$privs ||= 'ALL';
my $config = ovmdb_module_config();
if ($config->{'db_manager'} eq 'mysql') {
	# SECURITY: Validate privilege list against whitelist
	my $safe_privs = ovmdb_sanitize_privs($privs);
	return { 'ok' => 0, 'error' => 'Invalid privilege specification' } unless ($safe_privs);
	my $out = `mysql -e "GRANT $safe_privs ON \`$db\`.* TO '$user'\@'localhost'" 2>&1`;
	if ($?) {
		return { 'ok' => 0, 'error' => $out };
		}
	`mysql -e "FLUSH PRIVILEGES" 2>/dev/null`;
	}
elsif ($config->{'db_manager'} eq 'postgresql') {
	my $out = `psql -c "GRANT $safe_privs ON DATABASE $db TO $user" 2>&1`;
	if ($?) {
		return { 'ok' => 0, 'error' => $out };
		}
	}
return { 'ok' => 1, 'error' => '' };
}

###############################################################################
# ovmdb_revoke_privileges - Revoke privileges from user on database
###############################################################################
sub ovmdb_revoke_privileges
{
my ($user, $db) = @_;
return { 'ok' => 0, 'error' => 'Invalid parameters' } unless ($user && $db);
my $config = ovmdb_module_config();
if ($config->{'db_manager'} eq 'mysql') {
	my $out = `mysql -e "REVOKE ALL ON \`$db\`.* FROM '$user'\@'localhost'" 2>&1`;
	if ($?) {
		return { 'ok' => 0, 'error' => $out };
		}
	`mysql -e "FLUSH PRIVILEGES" 2>/dev/null`;
	}
elsif ($config->{'db_manager'} eq 'postgresql') {
	my $out = `psql -c "REVOKE ALL ON DATABASE $db FROM $user" 2>&1`;
	if ($?) {
		return { 'ok' => 0, 'error' => $out };
		}
	}
return { 'ok' => 1, 'error' => '' };
}

###############################################################################
# ovmdb_get_table_structure - Get table structure
###############################################################################
sub ovmdb_get_table_structure
{
my ($db, $table) = @_;
return [] unless ($db && $table);
my $config = ovmdb_module_config();
my @cols;
if ($config->{'db_manager'} eq 'mysql') {
	my $out = `mysql -BNe "SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_KEY, COLUMN_DEFAULT, EXTRA FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$db' AND TABLE_NAME='$table' ORDER BY ORDINAL_POSITION" 2>/dev/null`;
	foreach my $line (split(/\n/, $out)) {
		my @f = split(/\t/, $line);
		push(@cols, {
			'field' => $f[0],
			'type' => $f[1],
			'null' => $f[2],
			'key' => $f[3],
			'default' => $f[4],
			'extra' => $f[5],
			});
		}
	}
elsif ($config->{'db_manager'} eq 'postgresql') {
	my $out = `psql -At -c "SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_schema='public' AND table_name='$table' ORDER BY ordinal_position" "$db" 2>/dev/null`;
	foreach my $line (split(/\n/, $out)) {
		my @f = split(/\|/, $line);
		push(@cols, {
			'field' => $f[0],
			'type' => $f[1],
			'null' => $f[2],
			'key' => '',
			'default' => $f[3],
			'extra' => '',
			});
		}
	}
return \@cols;
}

###############################################################################
# ovmdb_run_query - Execute SQL query
###############################################################################
sub ovmdb_run_query
{
my ($db, $query) = @_;
return { 'ok' => 0, 'error' => 'No query provided' } unless ($query);
return { 'ok' => 0, 'error' => 'No database selected' } unless ($db);
my $config = ovmdb_module_config();
my @rows;
if ($config->{'db_manager'} eq 'mysql') {
	my $out = `mysql -BNe "$query" "$db" 2>&1`;
	if ($?) {
		return { 'ok' => 0, 'error' => $out };
		}
	foreach my $line (split(/\n/, $out)) {
		my @fields = split(/\t/, $line);
		push(@rows, \@fields);
		}
	}
elsif ($config->{'db_manager'} eq 'postgresql') {
	my $out = `psql -At -c "$query" "$db" 2>&1`;
	if ($?) {
		return { 'ok' => 0, 'error' => $out };
		}
	foreach my $line (split(/\n/, $out)) {
		my @fields = split(/\|/, $line);
		push(@rows, \@fields);
		}
	}
return { 'ok' => 1, 'error' => '', 'rows' => \@rows, 'count' => scalar(@rows) };
}

###############################################################################
# ovmdb_optimize_database - Optimize all tables in database
###############################################################################
sub ovmdb_optimize_database
{
my ($db) = @_;
return { 'ok' => 0, 'error' => 'Invalid database name' } unless ($db && $db =~ /^[\w]+$/);
my $config = ovmdb_module_config();
my @results;
if ($config->{'db_manager'} eq 'mysql') {
	my $out = `mysql -BNe "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA='$db' AND ENGINE IS NOT NULL" 2>/dev/null`;
	foreach my $table (split(/\n/, $out)) {
		chomp($table);
		next unless ($table);
		my $opt = `mysql -e "OPTIMIZE TABLE \`$table\`" "$db" 2>&1`;
		push(@results, { 'table' => $table, 'result' => $opt || 'OK' });
		}
	}
elsif ($config->{'db_manager'} eq 'postgresql') {
	my $out = `psql -At -c "SELECT tablename FROM pg_tables WHERE schemaname='public'" "$db" 2>/dev/null`;
	foreach my $table (split(/\n/, $out)) {
		chomp($table);
		next unless ($table);
		my $opt = `psql -c "VACUUM ANALYZE $table" "$db" 2>&1`;
		push(@results, { 'table' => $table, 'result' => $opt || 'OK' });
		}
	}
return { 'ok' => 1, 'error' => '', 'results' => \@results };
}

###############################################################################
# ovmdb_check_database - Check/repair tables in database
###############################################################################
sub ovmdb_check_database
{
my ($db) = @_;
return { 'ok' => 0, 'error' => 'Invalid database name' } unless ($db && $db =~ /^[\w]+$/);
my $config = ovmdb_module_config();
my @results;
if ($config->{'db_manager'} eq 'mysql') {
	my $out = `mysql -BNe "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA='$db' AND ENGINE IS NOT NULL" 2>/dev/null`;
	foreach my $table (split(/\n/, $out)) {
		chomp($table);
		next unless ($table);
		my $chk = `mysql -e "CHECK TABLE \`$table\`" "$db" 2>&1`;
		push(@results, { 'table' => $table, 'result' => $chk || 'OK' });
		}
	}
elsif ($config->{'db_manager'} eq 'postgresql') {
	my $out = `psql -At -c "SELECT tablename FROM pg_tables WHERE schemaname='public'" "$db" 2>/dev/null`;
	foreach my $table (split(/\n/, $out)) {
		chomp($table);
		next unless ($table);
		push(@results, { 'table' => $table, 'result' => 'PostgreSQL uses VACUUM for maintenance' });
		}
	}
return { 'ok' => 1, 'error' => '', 'results' => \@results };
}

###############################################################################
# ovmdb_get_server_status - Get database server status
###############################################################################
sub ovmdb_get_server_status
{
my $config = ovmdb_module_config();
my %status;
if ($config->{'db_manager'} eq 'mysql') {
	my $out = `mysqladmin status 2>/dev/null`;
	chomp($out);
	$status{'raw_status'} = $out;
	my $uptime_out = `mysql -BNe "SHOW STATUS LIKE 'Uptime'" 2>/dev/null`;
	chomp($uptime_out);
	$uptime_out =~ s/.*\t//;
	$status{'uptime'} = $uptime_out || 'unknown';
	my $qps_out = `mysql -BNe "SHOW STATUS LIKE 'Queries'" 2>/dev/null`;
	chomp($qps_out);
	$qps_out =~ s/.*\t//;
	my $qps = $uptime_out && $qps_out ? sprintf("%.2f", $qps_out / $uptime_out) : 0;
	$status{'queries_per_second'} = $qps;
	my $conn_out = `mysql -BNe "SHOW STATUS LIKE 'Threads_connected'" 2>/dev/null`;
	chomp($conn_out);
	$conn_out =~ s/.*\t//;
	$status{'connections'} = $conn_out || 0;
	my $ver_out = `mysql -V 2>/dev/null`;
	chomp($ver_out);
	$status{'version'} = $ver_out || 'unknown';
	$status{'running'} = ($out && $out !~ /error/i) ? 1 : 0;
	}
elsif ($config->{'db_manager'} eq 'postgresql') {
	my $out = `psql -At -c "SELECT version()" 2>/dev/null`;
	chomp($out);
	$status{'version'} = $out || 'unknown';
	my $uptime_out = `psql -At -c "SELECT now()-pg_postmaster_start_time()" 2>/dev/null`;
	chomp($uptime_out);
	$status{'uptime'} = $uptime_out || 'unknown';
	$status{'running'} = ($out) ? 1 : 0;
	$status{'connections'} = 0;
	$status{'queries_per_second'} = 0;
	}
return \%status;
}

###############################################################################
# ovmdb_list_backups - List existing backups
###############################################################################
sub ovmdb_list_backups
{
my ($db) = @_;
my $config = ovmdb_module_config();
my $dir = $config->{'backup_dir'};
return [] unless (-d $dir);
my @backups;
opendir(my $dh, $dir) || return [];
while(my $file = readdir($dh)) {
	next if ($file =~ /^\./);
	next if ($db && $file !~ /$db/);
	my $path = "$dir/$file";
	next unless (-f $path);
	my $size = -s $path;
	my $mtime = (stat($path))[9];
	push(@backups, {
		'file' => $file,
		'path' => $path,
		'size' => $size,
		'size_human' => ovmdb_human_size($size),
		'date' => $mtime,
		'date_human' => scalar(localtime($mtime)),
		'type' => $file =~ /\.sql$/ ? 'full' : $file =~ /\.gz$/ ? 'compressed' : 'full',
		});
	}
closedir($dh);
@backups = sort { $b->{'date'} <=> $a->{'date'} } @backups;
return \@backups;
}

1;
