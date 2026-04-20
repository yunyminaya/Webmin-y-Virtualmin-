#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-api-lib.pl';
&ReadParse();

ovm_api_init();

my $config = \%ovm_api_config;
my $endpoints = ovm_api_list_endpoints();
my $tokens = ovm_api_list_tokens();

&ui_print_header(undef, 'OpenVM API Management', '', 'index');

print qq{<style>
.ovm-api-box { background: #f8f9fa; border: 1px solid #dee2e6; border-radius: 8px; padding: 16px; margin-bottom: 16px; }
.ovm-api-method { display: inline-block; padding: 2px 8px; border-radius: 4px; font-weight: bold; font-size: 12px; color: #fff; }
.ovm-api-get    { background: #28a745; }
.ovm-api-post   { background: #007bff; }
.ovm-api-put    { background: #ffc107; color: #333; }
.ovm-api-delete { background: #dc3545; }
.ovm-api-table  { width: 100%; border-collapse: collapse; }
.ovm-api-table th, .ovm-api-table td { padding: 8px 12px; border-bottom: 1px solid #dee2e6; text-align: left; }
.ovm-api-table th { background: #e9ecef; }
.ovm-api-code   { background: #2d2d2d; color: #f8f8f2; padding: 12px; border-radius: 6px; font-family: monospace; font-size: 13px; overflow-x: auto; }
.ovm-api-badge  { display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 11px; font-weight: bold; }
</style>
};

# --- Sección: Estado de la API ---
print qq{<div class="ovm-api-box">\n};
print qq{<h3>API Status</h3>\n};
my $api_status = $config->{'api_enabled'} ? '<span style="color:green">&#10004; Enabled</span>' : '<span style="color:red">&#10008; Disabled</span>';
print qq{<p>API Status: $api_status</p>\n};
print qq{<p>Rate Limit: <strong>}.&html_escape($config->{'api_rate_limit'} || '100').qq{</strong> requests/minute</p>\n};
print qq{<p>Token Expiry: <strong>}.&html_escape($config->{'api_token_expiry'} || '3600').qq{</strong> seconds</p>\n};
print qq{<p>CORS: <strong>}.&html_escape($config->{'cors_enabled'} ? 'Enabled ('.($config->{'cors_origins'} || '*').')' : 'Disabled').qq{</strong></p>\n};
print qq{</div>\n};

# --- Sección: Generar API Key ---
print qq{<div class="ovm-api-box">\n};
print qq{<h3>Generate API Key</h3>\n};
print qq{<form method="post" action="index.cgi">\n};
print qq{<input type="hidden" name="action" value="generate_token">\n};
print qq{<table>\n};
print qq{<tr><td>Permissions:</td><td><select name="permissions">\n};
print qq{<option value="read">Read Only</option>\n};
print qq{<option value="write">Read & Write</option>\n};
print qq{<option value="all">Full Access</option>\n};
print qq{</select></td></tr>\n};
print qq{<tr><td colspan="2"><input type="submit" value="Generate Key" class="btn"></td></tr>\n};
print qq{</table>\n};
print qq{</form>\n};

# Procesar generación de token
if ($in{'action'} eq 'generate_token') {
	my $perms = $in{'permissions'} || 'read';
	my @perm_list = ($perms eq 'all') ? ('read','write','delete','admin') :
	                ($perms eq 'write') ? ('read','write') : ('read');
	my $token_data = ovm_api_generate_token($base_remote_user, \@perm_list);
	if ($token_data) {
		print qq{<div style="background:#d4edda; border:1px solid #c3e6cb; padding:12px; border-radius:6px; margin-top:12px;">\n};
		print qq{<strong>Token Generated Successfully</strong><br>\n};
		print qq{<code>}.&html_escape($token_data->{'token'}).qq{</code><br>\n};
		print qq{<small>Copy this token now. It will not be shown again.</small>\n};
		print qq{</div>\n};
		}
	}

# Procesar revocación de token
if ($in{'action'} eq 'revoke_token' && $in{'token'}) {
	ovm_api_delete_token($in{'token'});
	print qq{<div style="background:#d4edda; border:1px solid #c3e6cb; padding:12px; border-radius:6px; margin-top:12px;">\n};
	print qq{<strong>Token Revoked</strong><br>\n};
	print qq{</div>\n};
	}

print qq{</div>\n};

# --- Sección: Tokens Activos ---
print qq{<div class="ovm-api-box">\n};
print qq{<h3>Active Tokens</h3>\n};
if (@$tokens) {
	print qq{<table class="ovm-api-table">\n};
	print qq{<tr><th>Token</th><th>User</th><th>Permissions</th><th>Created</th><th>Expires</th><th>Action</th></tr>\n};
	for my $t (@$tokens) {
		print qq{<tr>};
		print qq{<td><code>}.&html_escape($t->{'token'}).qq{</code></td>};
		print qq{<td>}.&html_escape($t->{'user'}).qq{</td>};
		print qq{<td>}.&html_escape(join(', ', @{$t->{'permissions'} || []})).qq{</td>};
		print qq{<td>}.&html_escape(scalar(localtime($t->{'created'}))).qq{</td>};
		print qq{<td>}.&html_escape(scalar(localtime($t->{'expires'}))).qq{</td>};
		print qq{<td><form method="post" action="index.cgi" style="display:inline">};
		print qq{<input type="hidden" name="action" value="revoke_token">};
		print qq{<input type="hidden" name="token" value="}.&html_escape($t->{'token'}).qq{">};
		print qq{<input type="submit" value="Revoke" class="btn" style="background:#dc3545;color:#fff">};
		print qq{</form></td>};
		print qq{</tr>\n};
		}
	print qq{</table>\n};
	}
else {
	print qq{<p>No active tokens found.</p>\n};
	}
print qq{</div>\n};

# --- Sección: Endpoints ---
print qq{<div class="ovm-api-box">\n};
print qq{<h3>API Endpoints</h3>\n};
print qq{<table class="ovm-api-table">\n};
print qq{<tr><th>Method</th><th>Endpoint</th><th>Description</th><th>Auth</th></tr>\n};
for my $ep (@$endpoints) {
	my $method_class = 'ovm-api-'.lc($ep->{'method'});
	print qq{<tr>};
	print qq{<td><span class="ovm-api-method $method_class">}.$ep->{'method'}.qq{</span></td>};
	print qq{<td><code>}.&html_escape($ep->{'path'}).qq{</code></td>};
	print qq{<td>}.&html_escape($ep->{'desc'}).qq{</td>};
	print qq{<td>}.$ep->{'auth'}.qq{</td>};
	print qq{</tr>\n};
	}
print qq{</table>\n};
print qq{</div>\n};

# --- Sección: Ejemplos de uso ---
print qq{<div class="ovm-api-box">\n};
print qq{<h3>Usage Examples</h3>\n};

print qq{<h4>List Domains</h4>\n};
print qq{<div class="ovm-api-code">curl -H "Authorization: Bearer YOUR_TOKEN" \\\n};
print qq{  https://your-server:10000/openvm-api/v1.cgi/domains</div>\n};

print qq{<h4>Get Server Status</h4>\n};
print qq{<div class="ovm-api-code">curl -H "X-API-Key: YOUR_KEY" \\\n};
print qq{  https://your-server:10000/openvm-api/v1.cgi/server</div>\n};

print qq{<h4>Create Domain</h4>\n};
print qq{<div class="ovm-api-code">curl -X POST \\\n};
print qq{  -H "Authorization: Bearer YOUR_TOKEN" \\\n};
print qq{  -H "Content-Type: application/json" \\\n};
print qq{  -d '{"dom":"example.com","password":"secret","web":true,"mail":true}' \\\n};
print qq{  https://your-server:10000/openvm-api/v1.cgi/domains</div>\n};

print qq{<h4>Get Domain Info</h4>\n};
print qq{<div class="ovm-api-code">curl -H "Authorization: Bearer YOUR_TOKEN" \\\n};
print qq{  https://your-server:10000/openvm-api/v1.cgi/domains/12345</div>\n};

print qq{</div>\n};

# --- Sección: OpenAPI Docs ---
print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row('api_docs.cgi', 'OpenAPI/Swagger JSON', 'View the full OpenAPI specification in JSON format for integration with Swagger UI or other tools.');
print &ui_buttons_end();

&ui_print_footer('/', $text{'index_return'} || 'Return');
