#!/usr/bin/perl

use strict;
use warnings;
use File::Path qw(make_path);
use File::Spec;

our (%in, %text, %config, $base_remote_user, $module_config_directory, $module_root_directory);
our $OPENVM_API_LOADED = 0;
our %ovm_api_config;

# ---------------------------------------------------------------------------
# ovm_api_init() - Inicializa el sistema API, carga configuración
# ---------------------------------------------------------------------------
sub ovm_api_init
{
return 1 if ($OPENVM_API_LOADED);

# Cargar configuración por defecto
%ovm_api_config = (
	'api_enabled'      => 1,
	'api_rate_limit'   => 100,
	'api_token_expiry' => 3600,
	'cors_enabled'     => 1,
	'cors_origins'     => '*',
	);

# Leer archivo config del módulo
my $config_file = $module_config_directory
	? "$module_config_directory/config"
	: undef;

if ($config_file && -r $config_file) {
	open(my $fh, '<', $config_file) || return 0;
	while(my $line = <$fh>) {
		chomp($line);
		next if ($line =~ /^\s*#/ || $line !~ /=/);
		my ($key, $value) = split(/=/, $line, 2);
		next if (!defined($key) || $key eq '');
		$ovm_api_config{$key} = $value;
		}
	close($fh);
	}

# Asegurar directorio de tokens
my $token_dir = $module_config_directory
	? "$module_config_directory/api_tokens"
	: '/tmp/openvm_api_tokens';
if (!-d $token_dir) {
	make_path($token_dir) || warn "ovm_api_init: cannot create $token_dir: $!";
	}

$OPENVM_API_LOADED = 1;
return 1;
}

# ---------------------------------------------------------------------------
# ovm_api_auth($request) - Autenticación via API Key o Bearer token
#   Retorna hash con user info o undef
# ---------------------------------------------------------------------------
sub ovm_api_auth
{
my ($request) = @_;
$request ||= {};

# 1. Intentar Bearer Token desde HTTP_AUTHORIZATION
my $auth_header = $ENV{'HTTP_AUTHORIZATION'} || '';
if ($auth_header =~ /^Bearer\s+(.+)$/i) {
	my $token = $1;
	my $info = ovm_api_validate_token($token);
	return $info if ($info);
	}

# 2. Intentar API Key desde header X-API-Key
my $api_key = $ENV{'HTTP_X_API_KEY'} || '';
if ($api_key ne '') {
	my $info = ovm_api_validate_token($api_key);
	return $info if ($info);
	}

# 3. Intentar API Key desde parámetro query
$api_key = $in{'api_key'} || '';
if ($api_key ne '') {
	my $info = ovm_api_validate_token($api_key);
	return $info if ($info);
	}

# 4. Fallback: sesión Webmin activa (acceso desde navegador)
if ($base_remote_user && $base_remote_user ne '') {
	return {
		'user'        => $base_remote_user,
		'permissions' => ['all'],
		'source'      => 'session',
		};
	}

return undef;
}

# ---------------------------------------------------------------------------
# ovm_api_check_rate_limit($client_id) - Verifica rate limiting por cliente
# ---------------------------------------------------------------------------
sub ovm_api_check_rate_limit
{
my ($client_id) = @_;
$client_id ||= 'anonymous';

my $limit = int($ovm_api_config{'api_rate_limit'} || 100);
my $rate_dir = $module_config_directory
	? "$module_config_directory/api_rate"
	: '/tmp/openvm_api_rate';

if (!-d $rate_dir) {
	make_path($rate_dir);
	}

my $now = time();
my $window = 60; # 1 minuto
my $rate_file = "$rate_dir/$client_id";

my $count = 0;
my $window_start = $now - $window;

if (-r $rate_file) {
	open(my $fh, '<', $rate_file);
	while(my $line = <$fh>) {
		chomp($line);
		my ($ts, $req_count) = split(/,/, $line, 2);
		next if (!defined($ts) || $ts < $window_start);
		$count += ($req_count || 1);
		}
	close($fh);
	}

if ($count >= $limit) {
	return 0; # Rate limit excedido
	}

# Registrar este request
if (open(my $fh, '>>', $rate_file)) {
	print $fh "$now,1\n";
	close($fh);
	}

# Limpiar entradas viejas (aprox cada 100 requests)
if (($count % 100) == 0 && -r $rate_file) {
	my @kept;
	if (open(my $rfh, '<', $rate_file)) {
		while(my $line = <$rfh>) {
			chomp($line);
			my ($ts) = split(/,/, $line, 2);
			push(@kept, $line) if (defined($ts) && $ts >= $window_start);
			}
		close($rfh);
		}
	if (open(my $wfh, '>', $rate_file)) {
		print $wfh join("\n", @kept)."\n";
		close($wfh);
		}
	}

return 1;
}

# ---------------------------------------------------------------------------
# ovm_api_json_response($data, $status) - Genera respuesta JSON
# ---------------------------------------------------------------------------
sub ovm_api_json_response
{
my ($data, $status) = @_;
$status ||= 200;

my $json = ovm_api_encode_json($data);

print "Status: $status\r\n";
print "Content-Type: application/json; charset=utf-8\r\n";
ovm_api_cors_headers();
print "\r\n";
print $json;
}

# ---------------------------------------------------------------------------
# ovm_api_error($message, $status) - Genera respuesta de error JSON
# ---------------------------------------------------------------------------
sub ovm_api_error
{
my ($message, $status) = @_;
$status ||= 400;

ovm_api_json_response({
	'error'   => 1,
	'message' => $message,
	'status'  => $status,
	}, $status);
}

# ---------------------------------------------------------------------------
# ovm_api_list_endpoints() - Retorna array de endpoints disponibles
# ---------------------------------------------------------------------------
sub ovm_api_list_endpoints
{
my @endpoints = (
	{
		'method'    => 'GET',
		'path'      => '/v1/domains',
		'desc'      => 'List all accessible domains',
		'auth'      => 1,
	},
	{
		'method'    => 'GET',
		'path'      => '/v1/domains/{id}',
		'desc'      => 'Get domain details by ID',
		'auth'      => 1,
	},
	{
		'method'    => 'POST',
		'path'      => '/v1/domains',
		'desc'      => 'Create a new domain',
		'auth'      => 1,
	},
	{
		'method'    => 'DELETE',
		'path'      => '/v1/domains/{id}',
		'desc'      => 'Delete a domain by ID',
		'auth'      => 1,
	},
	{
		'method'    => 'GET',
		'path'      => '/v1/server',
		'desc'      => 'Get server status (CPU, RAM, disk, uptime)',
		'auth'      => 1,
	},
	{
		'method'    => 'GET',
		'path'      => '/v1/dns/{domain}',
		'desc'      => 'Get DNS records for a domain',
		'auth'      => 1,
	},
	{
		'method'    => 'GET',
		'path'      => '/v1/ssl/{domain}',
		'desc'      => 'Get SSL certificate info for a domain',
		'auth'      => 1,
	},
	{
		'method'    => 'GET',
		'path'      => '/v1/backup/{domain}',
		'desc'      => 'List backups for a domain',
		'auth'      => 1,
	},
	{
		'method'    => 'POST',
		'path'      => '/v1/backup/{domain}',
		'desc'      => 'Create backup for a domain',
		'auth'      => 1,
	},
	{
		'method'    => 'GET',
		'path'      => '/v1/users/{domain}',
		'desc'      => 'List users for a domain',
		'auth'      => 1,
	},
	);

return \@endpoints;
}

# ---------------------------------------------------------------------------
# ovm_api_get_domain_info($d) - Retorna hash con info de dominio
# ---------------------------------------------------------------------------
sub ovm_api_get_domain_info
{
my ($d) = @_;
return undef if (!$d);

my %info = (
	'dom'            => $d->{'dom'} || '',
	'user'           => $d->{'user'} || '',
	'home'           => $d->{'dir'} || $d->{'home'} || '',
	'web'            => $d->{'web'} ? \1 : \0,
	'mail'           => $d->{'mail'} ? \1 : \0,
	'ssl'            => $d->{'ssl'} ? \1 : \0,
	'dns'            => $d->{'dns'} ? \1 : \0,
	'quota'          => $d->{'quota'} || 0,
	'bandwidth_used' => $d->{'bw_usage'} || 0,
	);

if ($d->{'id'}) {
	$info{'id'} = $d->{'id'};
	}
if ($d->{'parent'}) {
	$info{'parent'} = $d->{'parent'};
	}
if ($d->{'created'}) {
	$info{'created'} = $d->{'created'};
	}

return \%info;
}

# ---------------------------------------------------------------------------
# ovm_api_list_domains($user) - Lista dominios accesibles por un usuario
# ---------------------------------------------------------------------------
sub ovm_api_list_domains
{
my ($user) = @_;

&foreign_require("virtual-server", "virtual-server-lib.pl");

my @domains;
my @all_doms = &list_domains();

for my $d (@all_doms) {
	if (!$user || $user eq 'root' || $user eq 'admin' ||
	    $d->{'user'} eq $user ||
	    &can_edit_domain($d)) {
		push(@domains, ovm_api_get_domain_info($d));
		}
	}

return \@domains;
}

# ---------------------------------------------------------------------------
# ovm_api_create_domain(%params) - Crea dominio usando virtual-server
# ---------------------------------------------------------------------------
sub ovm_api_create_domain
{
my (%params) = @_;

my $dom = $params{'dom'};
if (!$dom || $dom eq '') {
	return {'error' => 1, 'message' => 'Domain name is required'};
	}

&foreign_require("virtual-server", "virtual-server-lib.pl");

# Verificar si el dominio ya existe
my $existing = &get_domain_by('dom', $dom);
if ($existing) {
	return {'error' => 1, 'message' => "Domain $dom already exists"};
	}

# Construir opciones de creación
my %opts;
$opts{'dom'}   = $dom;
$opts{'user'}  = $params{'user'} || $dom;
$opts{'pass'}  = $params{'password'} || '';
$opts{'email'} = $params{'email'} || '';
$opts{'web'}   = defined($params{'web'}) ? $params{'web'} : 1;
$opts{'mail'}  = defined($params{'mail'}) ? $params{'mail'} : 1;
$opts{'dns'}   = defined($params{'dns'}) ? $params{'dns'} : 1;
$opts{'ssl'}   = defined($params{'ssl'}) ? $params{'ssl'} : 0;

# Intentar crear el dominio
eval {
	&create_virtual_server(\%opts, $base_remote_user);
	};
if ($@) {
	return {'error' => 1, 'message' => "Failed to create domain: $@"};
	}

my $new_d = &get_domain_by('dom', $dom);
return ovm_api_get_domain_info($new_d);
}

# ---------------------------------------------------------------------------
# ovm_api_delete_domain($id, %opts) - Elimina dominio
# ---------------------------------------------------------------------------
sub ovm_api_delete_domain
{
my ($id, %opts) = @_;

if (!$id || $id eq '') {
	return {'error' => 1, 'message' => 'Domain ID is required'};
	}

&foreign_require("virtual-server", "virtual-server-lib.pl");

my $d = &get_domain($id);
if (!$d) {
	return {'error' => 1, 'message' => "Domain with ID $id not found"};
	}

eval {
	&delete_virtual_server($d);
	};
if ($@) {
	return {'error' => 1, 'message' => "Failed to delete domain: $@"};
	}

return {'success' => 1, 'message' => "Domain $d->{'dom'} deleted"};
}

# ---------------------------------------------------------------------------
# ovm_api_get_server_status() - Retorna CPU, RAM, disco, uptime, load average
# ---------------------------------------------------------------------------
sub ovm_api_get_server_status
{
my %status;

# Load average
my $load = '';
if (open(my $fh, '<', '/proc/loadavg')) {
	$load = <$fh>;
	close($fh);
	chomp($load);
	my @parts = split(/\s+/, $load);
	$status{'load_1min'}  = $parts[0] || '0';
	$status{'load_5min'}  = $parts[1] || '0';
	$status{'load_15min'} = $parts[2] || '0';
	}

# Uptime
if (open(my $fh, '<', '/proc/uptime')) {
	my $line = <$fh>;
	close($fh);
	my ($secs) = split(/\s+/, $line);
	$status{'uptime_seconds'} = int($secs || 0);
	my $days = int($secs / 86400);
	my $hours = int(($secs % 86400) / 3600);
	my $mins  = int(($secs % 3600) / 60);
	$status{'uptime_human'} = "${days}d ${hours}h ${mins}m";
	}

# CPU info
my $cpu_count = 0;
if (open(my $fh, '<', '/proc/cpuinfo')) {
	while(my $line = <$fh>) {
		$cpu_count++ if ($line =~ /^processor\s*:/i);
		}
	close($fh);
	}
$status{'cpu_cores'} = $cpu_count || 1;

# CPU usage (from /proc/stat sample)
$status{'cpu_usage_percent'} = _ovm_api_cpu_usage();

# Memory
if (open(my $fh, '<', '/proc/meminfo')) {
	while(my $line = <$fh>) {
		if ($line =~ /^MemTotal:\s+(\d+)\s+kB/i) {
			$status{'memory_total_mb'} = int($1 / 1024);
			}
		elsif ($line =~ /^MemAvailable:\s+(\d+)\s+kB/i) {
			$status{'memory_available_mb'} = int($1 / 1024);
			}
		elsif ($line =~ /^SwapTotal:\s+(\d+)\s+kB/i) {
			$status{'swap_total_mb'} = int($1 / 1024);
			}
		elsif ($line =~ /^SwapFree:\s+(\d+)\s+kB/i) {
			$status{'swap_free_mb'} = int($1 / 1024);
			}
		}
	close($fh);
	}
if ($status{'memory_total_mb'}) {
	my $used = $status{'memory_total_mb'} - ($status{'memory_available_mb'} || 0);
	$status{'memory_used_mb'} = $used;
	$status{'memory_usage_percent'} = int(($used / $status{'memory_total_mb'}) * 100);
	}

# Disk usage
my $df_output = `df -k / 2>/dev/null`;
if ($df_output =~ /(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%\s+\//) {
	$status{'disk_total_gb'}  = int($1 / 1048576 * 100) / 100;
	$status{'disk_used_gb'}   = int($2 / 1048576 * 100) / 100;
	$status{'disk_free_gb'}   = int($3 / 1048576 * 100) / 100;
	$status{'disk_usage_percent'} = int($4);
	}

$status{'timestamp'} = time();

return \%status;
}

# ---------------------------------------------------------------------------
# ovm_api_generate_token($user, $permissions) - Genera API token seguro
# ---------------------------------------------------------------------------
sub ovm_api_generate_token
{
my ($user, $permissions) = @_;
$user ||= $base_remote_user || 'api';
$permissions ||= ['read'];

my $token_dir = $module_config_directory
	? "$module_config_directory/api_tokens"
	: '/tmp/openvm_api_tokens';

if (!-d $token_dir) {
	make_path($token_dir);
	}

# Generar token aleatorio (64 caracteres hex)
my $token = '';
for (my $i = 0; $i < 64; $i++) {
	$token .= sprintf('%x', int(rand(16)));
	}

my $expiry = time() + int($ovm_api_config{'api_token_expiry'} || 3600);

my %token_data = (
	'token'       => $token,
	'user'        => $user,
	'permissions' => $permissions,
	'created'     => time(),
	'expires'     => $expiry,
	);

# Guardar como archivo JSON simple
my $token_file = "$token_dir/$token.json";
my $json = ovm_api_encode_json(\%token_data);
if (open(my $fh, '>', $token_file)) {
	print $fh $json;
	close($fh);
	}
else {
	return undef;
	}

return \%token_data;
}

# ---------------------------------------------------------------------------
# ovm_api_validate_token($token) - Valida token contra archivo de tokens
# ---------------------------------------------------------------------------
sub ovm_api_validate_token
{
my ($token) = @_;
return undef if (!$token || $token eq '');

my $token_dir = $module_config_directory
	? "$module_config_directory/api_tokens"
	: '/tmp/openvm_api_tokens';

my $token_file = "$token_dir/$token.json";
return undef if (!-r $token_file);

my $json_str = '';
if (open(my $fh, '<', $token_file)) {
	local $/ = undef;
	$json_str = <$fh>;
	close($fh);
	}
else {
	return undef;
	}

my $data = ovm_api_decode_json($json_str);
return undef if (!$data);

# Verificar expiración
if ($data->{'expires'} && $data->{'expires'} < time()) {
	# Token expirado, eliminar
	unlink($token_file);
	return undef;
	}

return $data;
}

# ---------------------------------------------------------------------------
# ovm_api_cors_headers() - Emite headers CORS si están habilitados
# ---------------------------------------------------------------------------
sub ovm_api_cors_headers
{
return if (!$ovm_api_config{'cors_enabled'});

my $origin = $ovm_api_config{'cors_origins'} || '*';
print "Access-Control-Allow-Origin: $origin\r\n";
print "Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS\r\n";
print "Access-Control-Allow-Headers: Content-Type, Authorization, X-API-Key\r\n";
print "Access-Control-Max-Age: 86400\r\n";
}

# ---------------------------------------------------------------------------
# ovm_api_require_method($method) - Verifica request method
# ---------------------------------------------------------------------------
sub ovm_api_require_method
{
my ($method) = @_;
my $request_method = $ENV{'REQUEST_METHOD'} || 'GET';

if (uc($request_method) ne uc($method)) {
	ovm_api_error("Method not allowed. Expected: $method", 405);
	return 0;
	}

return 1;
}

# ---------------------------------------------------------------------------
# ovm_api_list_tokens() - Lista todos los tokens activos
# ---------------------------------------------------------------------------
sub ovm_api_list_tokens
{
my $token_dir = $module_config_directory
	? "$module_config_directory/api_tokens"
	: '/tmp/openvm_api_tokens';

my @tokens;
if (opendir(my $dh, $token_dir)) {
	while(my $file = readdir($dh)) {
		next if ($file !~ /\.json$/);
		my $path = "$token_dir/$file";
		if (open(my $fh, '<', $path)) {
			local $/ = undef;
			my $json_str = <$fh>;
			close($fh);
			my $data = ovm_api_decode_json($json_str);
			next if (!$data);
			# Verificar expiración
			if ($data->{'expires'} && $data->{'expires'} < time()) {
				unlink($path);
				next;
				}
			# No exponer el token completo
			my $safe_token = $data->{'token'};
			$safe_token =~ s/^(.{8}).+$/$1.../ if (defined($safe_token));
			push(@tokens, {
				'token'       => $safe_token,
				'user'        => $data->{'user'},
				'permissions' => $data->{'permissions'},
				'created'     => $data->{'created'},
				'expires'     => $data->{'expires'},
				});
			}
		}
	closedir($dh);
	}

return \@tokens;
}

# ---------------------------------------------------------------------------
# ovm_api_delete_token($token) - Elimina un token específico
# ---------------------------------------------------------------------------
sub ovm_api_delete_token
{
my ($token) = @_;
return 0 if (!$token || $token eq '');

my $token_dir = $module_config_directory
	? "$module_config_directory/api_tokens"
	: '/tmp/openvm_api_tokens';

my $token_file = "$token_dir/$token.json";
if (-f $token_file) {
	unlink($token_file);
	return 1;
	}

# Intentar buscar por prefijo
if (opendir(my $dh, $token_dir)) {
	while(my $file = readdir($dh)) {
		next if ($file !~ /\.json$/);
		if (index($file, $token) == 0) {
			unlink("$token_dir/$file");
			closedir($dh);
			return 1;
			}
		}
	closedir($dh);
	}

return 0;
}

# ===========================================================================
# FUNCIONES AUXILIARES PRIVADAS
# ===========================================================================

# _ovm_api_cpu_usage() - Calcula uso de CPU muestreando /proc/stat
sub _ovm_api_cpu_usage
{
my $sample1 = _ovm_api_cpu_sample();
return 0 if (!$sample1);
select(undef, undef, undef, 0.1); # sleep 100ms
my $sample2 = _ovm_api_cpu_sample();
return 0 if (!$sample2);

my $diff_idle  = $sample2->{'idle'}  - $sample1->{'idle'};
my $diff_total = $sample2->{'total'} - $sample1->{'total'};

return 0 if ($diff_total == 0);
my $usage = 100 - (100 * $diff_idle / $diff_total);
return int($usage * 100) / 100;
}

sub _ovm_api_cpu_sample
{
return undef if (!open(my $fh, '<', '/proc/stat'));
my $line = <$fh>;
close($fh);
return undef if (!$line || $line !~ /^cpu\s+/);
my @vals = split(/\s+/, $line);
shift(@vals); # remove 'cpu' label
my $total = 0;
for my $v (@vals) { $total += ($v || 0); }
my $idle = $vals[3] || 0;
return {'idle' => $idle, 'total' => $total};
}

# ---------------------------------------------------------------------------
# ovm_api_encode_json($data) - Codificador JSON simple (sin dependencias)
# ---------------------------------------------------------------------------
sub ovm_api_encode_json
{
my ($data) = @_;
return 'null' if (!defined($data));

my $ref = ref($data);

if (!$ref) {
	# Escalar
	if (!defined($data)) { return 'null'; }
	if ($data =~ /^-?\d+(?:\.\d+)?$/) { return $data; }
	$data =~ s/\\/\\\\/g;
	$data =~ s/"/\\"/g;
	$data =~ s/\n/\\n/g;
	$data =~ s/\r/\\r/g;
	$data =~ s/\t/\\t/g;
	return "\"$data\"";
	}
elsif ($ref eq 'SCALAR') {
	return ovm_api_encode_json($$data);
	}
elsif ($ref eq 'JSON::PP::Boolean') {
	return $$data ? 'true' : 'false';
	}
elsif ($ref eq 'HASH') {
	my @pairs;
	for my $key (sort keys %$data) {
		my $enc_key = ovm_api_encode_json($key);
		my $enc_val = ovm_api_encode_json($data->{$key});
		push(@pairs, "$enc_key:$enc_val");
		}
	return '{'.join(',', @pairs).'}';
	}
elsif ($ref eq 'ARRAY') {
	my @items;
	for my $item (@$data) {
		push(@items, ovm_api_encode_json($item));
		}
	return '['.join(',', @items).']';
	}
elsif ($ref eq 'CODE' || $ref eq 'GLOB') {
	return 'null';
	}
else {
	# Ref a escalar (booleanos de Perl)
	if ($$data) { return 'true'; }
	return 'false';
	}
}

# ---------------------------------------------------------------------------
# ovm_api_decode_json($json_str) - Decodificador JSON simple
# ---------------------------------------------------------------------------
sub ovm_api_decode_json
{
my ($json) = @_;
return undef if (!defined($json) || $json eq '');

$json =~ s/^\s+//;
$json =~ s/\s+$//;

return _ovm_api_parse_json(\$json);
}

sub _ovm_api_parse_json
{
my ($strref) = @_;
$$strref =~ s/^\s+//;

# null
if ($$strref =~ s/^null//) { return undef; }
# true
if ($$strref =~ s/^true//) { my $v = 1; return \$v; }
# false
if ($$strref =~ s/^false//) { my $v = 0; return \$v; }
# number
if ($$strref =~ s/^(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)//) { return $1 + 0; }
# string
if ($$strref =~ s/^"//) {
	my $s = '';
	while($$strref ne '' && $$strref !~ s/^"//) {
		if ($$strref =~ s/^\\n//)      { $s .= "\n"; }
		elsif ($$strref =~ s/^\\r//)   { $s .= "\r"; }
		elsif ($$strref =~ s/^\\t//)   { $s .= "\t"; }
		elsif ($$strref =~ s/^\\\\"//) { $s .= '"'; }
		elsif ($$strref =~ s/^\\\\//)  { $s .= '\\'; }
		elsif ($$strref =~ s/^\\u([0-9a-fA-F]{4})//) { $s .= chr(hex($1)); }
		elsif ($$strref =~ s/^(.)//)   { $s .= $1; }
		}
	return $s;
	}
# array
if ($$strref =~ s/^\[//) {
	my @arr;
	$$strref =~ s/^\s+//;
	if ($$strref !~ /^\]/) {
		while(1) {
			push(@arr, _ovm_api_parse_json($strref));
			$$strref =~ s/^\s+//;
			last if ($$strref !~ s/^,//);
			}
		}
	$$strref =~ s/^\s*//;
	$$strref =~ s/^\]//;
	return \@arr;
	}
# object
if ($$strref =~ s/^\{//) {
	my %hash;
	$$strref =~ s/^\s+//;
	if ($$strref !~ /^\}/) {
		while(1) {
			$$strref =~ s/^\s+//;
			my $key = _ovm_api_parse_json($strref);
			$$strref =~ s/^\s*:\s*//;
			my $val = _ovm_api_parse_json($strref);
			$hash{$key} = $val if (defined($key));
			$$strref =~ s/^\s+//;
			last if ($$strref !~ s/^,//);
			}
		}
	$$strref =~ s/^\s*//;
	$$strref =~ s/^\}//;
	return \%hash;
	}

return undef;
}

1;
