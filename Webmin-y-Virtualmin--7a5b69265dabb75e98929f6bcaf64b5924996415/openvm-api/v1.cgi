#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-api-lib.pl';
&ReadParse();

ovm_api_init();

# Verificar que la API está habilitada
if (!$ovm_api_config{'api_enabled'}) {
	ovm_api_error('API is disabled', 503);
	exit;
	}

# Manejar preflight OPTIONS para CORS
if (($ENV{'REQUEST_METHOD'} || '') eq 'OPTIONS') {
	print "Status: 204\r\n";
	ovm_api_cors_headers();
	print "\r\n";
	exit;
	}

# Autenticación
my $auth = ovm_api_auth();
if (!$auth) {
	ovm_api_error('Unauthorized: Invalid or missing API credentials', 401);
	exit;
	}

# Rate limiting
my $client_id = $auth->{'user'} || 'anonymous';
if (!ovm_api_check_rate_limit($client_id)) {
	ovm_api_error('Rate limit exceeded. Please try again later.', 429);
	exit;
	}

# Parsear PATH_INFO para determinar el endpoint
my $path_info = $ENV{'PATH_INFO'} || '/';
$path_info =~ s/^\s+//;
$path_info =~ s/\s+$//;

# Normalizar path
my @segments = split(m{/}, $path_info);
@segments = grep { $_ ne '' } @segments;

# Enrutar al endpoint correcto
my $endpoint = shift(@segments) || '';

# GET /domains - Listar dominios
if ($endpoint eq 'domains' && !@segments) {
	if (!ovm_api_require_method('GET')) { exit; }
	my $domains = ovm_api_list_domains($auth->{'user'});
	ovm_api_json_response({
		'success' => 1,
		'data'    => $domains,
		'count'   => scalar(@$domains),
		}, 200);
	}

# GET /domains/{id} - Info de dominio
# DELETE /domains/{id} - Eliminar dominio
elsif ($endpoint eq 'domains' && @segments == 1) {
	my $id = $segments[0];
	my $method = $ENV{'REQUEST_METHOD'} || 'GET';

	if (uc($method) eq 'GET') {
		&foreign_require("virtual-server", "virtual-server-lib.pl");
		my $d = &get_domain($id);
		if (!$d) {
			ovm_api_error("Domain with ID $id not found", 404);
			exit;
			}
		my $info = ovm_api_get_domain_info($d);
		ovm_api_json_response({
			'success' => 1,
			'data'    => $info,
			}, 200);
		}
	elsif (uc($method) eq 'DELETE') {
		my %opts;
		my $result = ovm_api_delete_domain($id, %opts);
		if ($result->{'error'}) {
			ovm_api_error($result->{'message'}, 400);
			}
		else {
			ovm_api_json_response($result, 200);
			}
		}
	else {
		ovm_api_error("Method not allowed for /domains/{id}", 405);
		}
	}

# POST /domains - Crear dominio
elsif ($endpoint eq 'domains' && !@segments && uc($ENV{'REQUEST_METHOD'} || '') eq 'POST') {
	# Leer body JSON
	my %params = ovm_api_read_json_body();
	my $result = ovm_api_create_domain(%params);
	if ($result->{'error'}) {
		ovm_api_error($result->{'message'}, 400);
		}
	else {
		ovm_api_json_response({
			'success' => 1,
			'data'    => $result,
			}, 201);
		}
	}

# GET /server - Estado del servidor
elsif ($endpoint eq 'server') {
	if (!ovm_api_require_method('GET')) { exit; }
	my $status = ovm_api_get_server_status();
	ovm_api_json_response({
		'success' => 1,
		'data'    => $status,
		}, 200);
	}

# GET /dns/{domain} - Registros DNS
elsif ($endpoint eq 'dns' && @segments >= 1) {
	if (!ovm_api_require_method('GET')) { exit; }
	my $domain = $segments[0];

	&foreign_require("virtual-server", "virtual-server-lib.pl");
	my $d = &get_domain_by('dom', $domain);
	if (!$d) {
		ovm_api_error("Domain $domain not found", 404);
		exit;
		}

	my @records;
	if ($d->{'dns'}) {
		&foreign_require("bind8", "bind8-lib.pl");
		my $zone = &get_domain_dns_zone($d);
		if ($zone) {
			my @recs = &get_zone_records($zone);
			for my $r (@recs) {
				push(@records, {
					'name'  => $r->{'name'} || '',
					'type'  => $r->{'type'} || '',
					'value' => $r->{'values'} || $r->{'value'} || '',
					'ttl'   => $r->{'ttl'} || '',
					});
				}
			}
		}

	ovm_api_json_response({
		'success' => 1,
		'domain'  => $domain,
		'records' => \@records,
		'count'   => scalar(@records),
		}, 200);
	}

# GET /ssl/{domain} - Info SSL
elsif ($endpoint eq 'ssl' && @segments >= 1) {
	if (!ovm_api_require_method('GET')) { exit; }
	my $domain = $segments[0];

	&foreign_require("virtual-server", "virtual-server-lib.pl");
	my $d = &get_domain_by('dom', $domain);
	if (!$d) {
		ovm_api_error("Domain $domain not found", 404);
		exit;
		}

	my %ssl_info = (
		'domain'    => $domain,
		'ssl_enabled' => $d->{'ssl'} ? \1 : \0,
		'cert_file' => $d->{'ssl_cert'} || '',
		'key_file'  => $d->{'ssl_key'} || '',
		);

	if ($d->{'ssl_cert'} && -r $d->{'ssl_cert'}) {
		my $cert_output = `openssl x509 -in "$d->{'ssl_cert'}" -noout -subject -dates -issuer 2>/dev/null`;
		if ($cert_output =~ /subject=\s*(.+)/i) {
			$ssl_info{'subject'} = $1;
			}
		if ($cert_output =~ /notBefore=\s*(.+)/i) {
			$ssl_info{'valid_from'} = $1;
			}
		if ($cert_output =~ /notAfter=\s*(.+)/i) {
			$ssl_info{'valid_until'} = $1;
			}
		if ($cert_output =~ /issuer=\s*(.+)/i) {
			$ssl_info{'issuer'} = $1;
			}
		}

	ovm_api_json_response({
		'success' => 1,
		'data'    => \%ssl_info,
		}, 200);
	}

# GET /backup/{domain} - Listar backups
# POST /backup/{domain} - Crear backup
elsif ($endpoint eq 'backup' && @segments >= 1) {
	my $domain = $segments[0];
	my $method = uc($ENV{'REQUEST_METHOD'} || 'GET');

	&foreign_require("virtual-server", "virtual-server-lib.pl");
	my $d = &get_domain_by('dom', $domain);
	if (!$d) {
		ovm_api_error("Domain $domain not found", 404);
		exit;
		}

	if ($method eq 'GET') {
		# Listar backups existentes
		my @backups;
		my $backup_dir = $d->{'dir'}.'/backups';
		if (-d $backup_dir) {
			if (opendir(my $dh, $backup_dir)) {
				while(my $f = readdir($dh)) {
					next if ($f =~ /^\./);
					my $path = "$backup_dir/$f";
					my @stat = stat($path);
					push(@backups, {
						'file' => $f,
						'size' => $stat[7] || 0,
						'date' => $stat[9] || 0,
						}) if (-f $path);
					}
				closedir($dh);
				}
			}
		ovm_api_json_response({
			'success' => 1,
			'domain'  => $domain,
			'backups' => \@backups,
			'count'   => scalar(@backups),
			}, 200);
		}
	elsif ($method eq 'POST') {
		# Crear backup
		eval {
			&backup_virtual_server($d, undef, undef);
			};
		if ($@) {
			ovm_api_error("Backup failed: $@", 500);
			}
		else {
			ovm_api_json_response({
				'success' => 1,
				'message' => "Backup initiated for $domain",
				}, 202);
			}
		}
	else {
		ovm_api_error("Method not allowed for /backup/{domain}", 405);
		}
	}

# GET /users/{domain} - Listar usuarios de dominio
elsif ($endpoint eq 'users' && @segments >= 1) {
	if (!ovm_api_require_method('GET')) { exit; }
	my $domain = $segments[0];

	&foreign_require("virtual-server", "virtual-server-lib.pl");
	my $d = &get_domain_by('dom', $domain);
	if (!$d) {
		ovm_api_error("Domain $domain not found", 404);
		exit;
		}

	my @users;
	my @dom_users = &list_domain_users($d);
	for my $u (@dom_users) {
		push(@users, {
			'user'  => $u->{'user'} || '',
			'email' => $u->{'email'} || '',
			'type'  => $u->{'type'} || '',
			});
		}

	ovm_api_json_response({
		'success' => 1,
		'domain'  => $domain,
		'users'   => \@users,
		'count'   => scalar(@users),
		}, 200);
	}

# Endpoint no encontrado
else {
	ovm_api_error("Endpoint not found: $path_info", 404);
	}

# ---------------------------------------------------------------------------
# ovm_api_read_json_body() - Lee y parsea el body JSON del request
# ---------------------------------------------------------------------------
sub ovm_api_read_json_body
{
my %params;
my $content_type = $ENV{'CONTENT_TYPE'} || '';
my $content_len = $ENV{'CONTENT_LENGTH'} || 0;

if ($content_len > 0 && $content_type =~ /json/i) {
	my $body = '';
	read(STDIN, $body, $content_len);
	my $data = ovm_api_decode_json($body);
	if ($data && ref($data) eq 'HASH') {
		%params = %$data;
		}
	}

# Fallback a parámetros de formulario
for my $key (keys %in) {
	$params{$key} ||= $in{$key};
	}

return %params;
}

