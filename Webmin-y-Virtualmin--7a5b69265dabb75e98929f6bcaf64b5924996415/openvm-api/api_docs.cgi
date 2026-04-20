#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-api-lib.pl';
&ReadParse();

ovm_api_init();

# Generar especificación OpenAPI/Swagger JSON
my $host = $ENV{'SERVER_NAME'} || 'localhost';
my $port = $ENV{'SERVER_PORT'} || '10000';
my $scheme = $ENV{'HTTPS'} ? 'https' : 'http';
my $base_url = "$scheme://$host:$port";

my %spec = (
	'openapi' => '3.0.3',
	'info'    => {
		'title'       => 'OpenVM Panel REST API',
		'description' => 'REST API for OpenVM panel integration, billing systems and automation. Provides endpoints for domain management, server monitoring, DNS, SSL, backups and user management.',
		'version'     => '1.0.0',
		'contact'     => {
			'name'  => 'OpenVM Panel',
			'url'   => 'https://github.com/openvm-panel',
			},
		'license'     => {
			'name' => 'MIT',
			'url'  => 'https://opensource.org/licenses/MIT',
			},
		},
	'servers' => [
		{
			'url'       => "$base_url/openvm-api/v1.cgi",
			'description' => 'Current server',
			},
		],
	'components' => {
		'securitySchemes' => {
			'bearerAuth' => {
				'type'         => 'http',
				'scheme'       => 'bearer',
				'bearerFormat' => 'JWT',
				},
			'apiKey' => {
				'type' => 'apiKey',
				'in'   => 'header',
				'name' => 'X-API-Key',
				},
			},
		'schemas' => {
			'Domain' => {
				'type'       => 'object',
				'properties' => {
					'id'             => { 'type' => 'string', 'description' => 'Domain ID' },
					'dom'            => { 'type' => 'string', 'description' => 'Domain name' },
					'user'           => { 'type' => 'string', 'description' => 'Owner username' },
					'home'           => { 'type' => 'string', 'description' => 'Home directory path' },
					'web'            => { 'type' => 'boolean', 'description' => 'Web feature enabled' },
					'mail'           => { 'type' => 'boolean', 'description' => 'Mail feature enabled' },
					'ssl'            => { 'type' => 'boolean', 'description' => 'SSL feature enabled' },
					'dns'            => { 'type' => 'boolean', 'description' => 'DNS feature enabled' },
					'quota'          => { 'type' => 'integer', 'description' => 'Disk quota in MB' },
					'bandwidth_used' => { 'type' => 'integer', 'description' => 'Bandwidth used in bytes' },
					},
				},
			'ServerStatus' => {
				'type'       => 'object',
				'properties' => {
					'load_1min'           => { 'type' => 'string' },
					'load_5min'           => { 'type' => 'string' },
					'load_15min'          => { 'type' => 'string' },
					'uptime_seconds'      => { 'type' => 'integer' },
					'uptime_human'        => { 'type' => 'string' },
					'cpu_cores'           => { 'type' => 'integer' },
					'cpu_usage_percent'   => { 'type' => 'number' },
					'memory_total_mb'     => { 'type' => 'integer' },
					'memory_used_mb'      => { 'type' => 'integer' },
					'memory_available_mb' => { 'type' => 'integer' },
					'memory_usage_percent'=> { 'type' => 'integer' },
					'swap_total_mb'       => { 'type' => 'integer' },
					'swap_free_mb'        => { 'type' => 'integer' },
					'disk_total_gb'       => { 'type' => 'number' },
					'disk_used_gb'        => { 'type' => 'number' },
					'disk_free_gb'        => { 'type' => 'number' },
					'disk_usage_percent'  => { 'type' => 'integer' },
					'timestamp'           => { 'type' => 'integer' },
					},
				},
			'Error' => {
				'type'       => 'object',
				'properties' => {
					'error'   => { 'type' => 'integer', 'example' => 1 },
					'message' => { 'type' => 'string', 'example' => 'Error description' },
					'status'  => { 'type' => 'integer', 'example' => 400 },
					},
				},
			'DNSRecord' => {
				'type'       => 'object',
				'properties' => {
					'name'  => { 'type' => 'string' },
					'type'  => { 'type' => 'string' },
					'value' => { 'type' => 'string' },
					'ttl'   => { 'type' => 'string' },
					},
				},
			'SSLInfo' => {
				'type'       => 'object',
				'properties' => {
					'domain'       => { 'type' => 'string' },
					'ssl_enabled'  => { 'type' => 'boolean' },
					'subject'      => { 'type' => 'string' },
					'issuer'       => { 'type' => 'string' },
					'valid_from'   => { 'type' => 'string' },
					'valid_until'  => { 'type' => 'string' },
					},
				},
			'Backup' => {
				'type'       => 'object',
				'properties' => {
					'file' => { 'type' => 'string' },
					'size' => { 'type' => 'integer' },
					'date' => { 'type' => 'integer' },
					},
				},
			'User' => {
				'type'       => 'object',
				'properties' => {
					'user'  => { 'type' => 'string' },
					'email' => { 'type' => 'string' },
					'type'  => { 'type' => 'string' },
					},
				},
			},
		},
	'paths' => {
		'/domains' => {
			'get' => {
				'summary'     => 'List all accessible domains',
				'description' => 'Returns a list of all domains accessible by the authenticated user.',
				'security'    => [{'bearerAuth' => []}, {'apiKey' => []}],
				'responses'   => {
					'200' => {
						'description' => 'Successful response',
						'content'     => {
							'application/json' => {
								'schema' => {
									'type'       => 'object',
									'properties' => {
										'success' => { 'type' => 'integer', 'example' => 1 },
										'data'    => { 'type' => 'array', 'items' => { '$ref' => '#/components/schemas/Domain' } },
										'count'   => { 'type' => 'integer' },
										},
									},
								},
							},
						},
					'401' => { 'description' => 'Unauthorized', 'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } } },
					'429' => { 'description' => 'Rate limit exceeded', 'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } } },
					},
				},
			'post' => {
				'summary'     => 'Create a new domain',
				'description' => 'Creates a new virtual server domain.',
				'security'    => [{'bearerAuth' => []}, {'apiKey' => []}],
				'requestBody' => {
					'required'   => 1,
					'content'    => {
						'application/json' => {
							'schema' => {
								'type'       => 'object',
								'required'   => ['dom'],
								'properties' => {
									'dom'      => { 'type' => 'string', 'description' => 'Domain name' },
									'user'     => { 'type' => 'string', 'description' => 'Username' },
									'password' => { 'type' => 'string', 'description' => 'Password' },
									'email'    => { 'type' => 'string', 'description' => 'Admin email' },
									'web'      => { 'type' => 'boolean', 'description' => 'Enable web' },
									'mail'     => { 'type' => 'boolean', 'description' => 'Enable mail' },
									'dns'      => { 'type' => 'boolean', 'description' => 'Enable DNS' },
									'ssl'      => { 'type' => 'boolean', 'description' => 'Enable SSL' },
									},
								},
							},
						},
					},
				},
				'responses' => {
					'201' => { 'description' => 'Domain created', 'content' => { 'application/json' => { 'schema' => { 'type' => 'object', 'properties' => { 'success' => { 'type' => 'integer' }, 'data' => { '$ref' => '#/components/schemas/Domain' } } } } } },
					'400' => { 'description' => 'Bad request', 'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } } },
					},
				},
			},
		'/domains/{id}' => {
			'get' => {
				'summary'     => 'Get domain details',
				'description' => 'Returns detailed information about a specific domain.',
				'security'    => [{'bearerAuth' => []}, {'apiKey' => []}],
				'parameters'  => [
					{ 'name' => 'id', 'in' => 'path', 'required' => 1, 'schema' => { 'type' => 'string' }, 'description' => 'Domain ID' },
					],
				'responses' => {
					'200' => { 'description' => 'Domain details', 'content' => { 'application/json' => { 'schema' => { 'type' => 'object', 'properties' => { 'success' => { 'type' => 'integer' }, 'data' => { '$ref' => '#/components/schemas/Domain' } } } } } },
					'404' => { 'description' => 'Domain not found', 'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } } },
					},
				},
			'delete' => {
				'summary'     => 'Delete a domain',
				'description' => 'Deletes a virtual server domain by ID.',
				'security'    => [{'bearerAuth' => []}, {'apiKey' => []}],
				'parameters'  => [
					{ 'name' => 'id', 'in' => 'path', 'required' => 1, 'schema' => { 'type' => 'string' }, 'description' => 'Domain ID' },
					],
				'responses' => {
					'200' => { 'description' => 'Domain deleted', 'content' => { 'application/json' => { 'schema' => { 'type' => 'object', 'properties' => { 'success' => { 'type' => 'integer' }, 'message' => { 'type' => 'string' } } } } } },
					'400' => { 'description' => 'Bad request', 'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } } },
					},
				},
			},
		'/server' => {
			'get' => {
				'summary'     => 'Get server status',
				'description' => 'Returns CPU, RAM, disk, uptime and load average information.',
				'security'    => [{'bearerAuth' => []}, {'apiKey' => []}],
				'responses'   => {
					'200' => { 'description' => 'Server status', 'content' => { 'application/json' => { 'schema' => { 'type' => 'object', 'properties' => { 'success' => { 'type' => 'integer' }, 'data' => { '$ref' => '#/components/schemas/ServerStatus' } } } } } },
					},
				},
			},
		'/dns/{domain}' => {
			'get' => {
				'summary'     => 'Get DNS records',
				'description' => 'Returns DNS records for the specified domain.',
				'security'    => [{'bearerAuth' => []}, {'apiKey' => []}],
				'parameters'  => [
					{ 'name' => 'domain', 'in' => 'path', 'required' => 1, 'schema' => { 'type' => 'string' }, 'description' => 'Domain name' },
					],
				'responses' => {
					'200' => { 'description' => 'DNS records', 'content' => { 'application/json' => { 'schema' => { 'type' => 'object', 'properties' => { 'success' => { 'type' => 'integer' }, 'domain' => { 'type' => 'string' }, 'records' => { 'type' => 'array', 'items' => { '$ref' => '#/components/schemas/DNSRecord' } }, 'count' => { 'type' => 'integer' } } } } } },
					'404' => { 'description' => 'Domain not found', 'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } } },
					},
				},
			},
		'/ssl/{domain}' => {
			'get' => {
				'summary'     => 'Get SSL certificate info',
				'description' => 'Returns SSL certificate information for the specified domain.',
				'security'    => [{'bearerAuth' => []}, {'apiKey' => []}],
				'parameters'  => [
					{ 'name' => 'domain', 'in' => 'path', 'required' => 1, 'schema' => { 'type' => 'string' }, 'description' => 'Domain name' },
					],
				'responses' => {
					'200' => { 'description' => 'SSL info', 'content' => { 'application/json' => { 'schema' => { 'type' => 'object', 'properties' => { 'success' => { 'type' => 'integer' }, 'data' => { '$ref' => '#/components/schemas/SSLInfo' } } } } } },
					'404' => { 'description' => 'Domain not found', 'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } } },
					},
				},
			},
		'/backup/{domain}' => {
			'get' => {
				'summary'     => 'List backups',
				'description' => 'Returns a list of backups for the specified domain.',
				'security'    => [{'bearerAuth' => []}, {'apiKey' => []}],
				'parameters'  => [
					{ 'name' => 'domain', 'in' => 'path', 'required' => 1, 'schema' => { 'type' => 'string' }, 'description' => 'Domain name' },
					],
				'responses' => {
					'200' => { 'description' => 'Backup list', 'content' => { 'application/json' => { 'schema' => { 'type' => 'object', 'properties' => { 'success' => { 'type' => 'integer' }, 'domain' => { 'type' => 'string' }, 'backups' => { 'type' => 'array', 'items' => { '$ref' => '#/components/schemas/Backup' } }, 'count' => { 'type' => 'integer' } } } } } },
					'404' => { 'description' => 'Domain not found', 'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } } },
					},
				},
			'post' => {
				'summary'     => 'Create backup',
				'description' => 'Initiates a backup for the specified domain.',
				'security'    => [{'bearerAuth' => []}, {'apiKey' => []}],
				'parameters'  => [
					{ 'name' => 'domain', 'in' => 'path', 'required' => 1, 'schema' => { 'type' => 'string' }, 'description' => 'Domain name' },
					],
				'responses' => {
					'202' => { 'description' => 'Backup initiated', 'content' => { 'application/json' => { 'schema' => { 'type' => 'object', 'properties' => { 'success' => { 'type' => 'integer' }, 'message' => { 'type' => 'string' } } } } } },
					'500' => { 'description' => 'Backup failed', 'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } } },
					},
				},
			},
		'/users/{domain}' => {
			'get' => {
				'summary'     => 'List domain users',
				'description' => 'Returns a list of users associated with the specified domain.',
				'security'    => [{'bearerAuth' => []}, {'apiKey' => []}],
				'parameters'  => [
					{ 'name' => 'domain', 'in' => 'path', 'required' => 1, 'schema' => { 'type' => 'string' }, 'description' => 'Domain name' },
					],
				'responses' => {
					'200' => { 'description' => 'User list', 'content' => { 'application/json' => { 'schema' => { 'type' => 'object', 'properties' => { 'success' => { 'type' => 'integer' }, 'domain' => { 'type' => 'string' }, 'users' => { 'type' => 'array', 'items' => { '$ref' => '#/components/schemas/User' } }, 'count' => { 'type' => 'integer' } } } } } },
					'404' => { 'description' => 'Domain not found', 'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } } },
					},
				},
			},
		},
	);

# Emitir JSON response
my $json = ovm_api_encode_json(\%spec);

print "Status: 200\r\n";
print "Content-Type: application/json; charset=utf-8\r\n";
ovm_api_cors_headers();
print "\r\n";
print $json;
