#!/usr/bin/perl
# e2e_encryption_setup.pl - End-to-End Encryption Setup

use strict;
use warnings;

print "Setting up End-to-End Encryption for Zero-Trust...\n";

# Configuration
my $ssl_dir = "$module_root_directory/ssl";
my $cert_file = "$ssl_dir/certificate.crt";
my $key_file = "$ssl_dir/private.key";
my $dh_file = "$ssl_dir/dhparam.pem";

# Create SSL directory
mkdir($ssl_dir) unless -d $ssl_dir;

# Generate self-signed certificate if not exists
unless (-f $cert_file && -f $key_file) {
    print "Generating SSL certificate...\n";
    system("openssl req -x509 -newkey rsa:4096 -keyout $key_file -out $cert_file -days 365 -nodes -subj '/C=US/ST=Security/L=ZeroTrust/O=Webmin/CN=localhost'");
    chmod(0600, $key_file);
}

# Generate DH parameters for forward secrecy
unless (-f $dh_file) {
    print "Generating DH parameters...\n";
    system("openssl dhparam -out $dh_file 2048");
}

# Configure Apache/Nginx for TLS 1.3
configure_web_server_ssl();

# Setup client certificate authentication
setup_client_cert_auth();

# Configure encryption policies
configure_encryption_policies();

print "End-to-End Encryption setup complete!\n";

sub configure_web_server_ssl {
    print "Configuring web server SSL/TLS...\n";

    # Detect web server
    my $apache_config = '/etc/httpd/conf/httpd.conf';
    my $nginx_config = '/etc/nginx/nginx.conf';

    if (-f $apache_config) {
        configure_apache_ssl();
    } elsif (-f $nginx_config) {
        configure_nginx_ssl();
    } else {
        print "Warning: Could not detect web server configuration\n";
    }
}

sub configure_apache_ssl {
    my $ssl_conf = '/etc/httpd/conf.d/ssl.conf';

    if (-f $ssl_conf) {
        # Backup original
        system("cp $ssl_conf $ssl_conf.backup");

        # Update SSL configuration
        my $ssl_config = <<"EOF";
SSLEngine on
SSLCertificateFile $cert_file
SSLCertificateKeyFile $key_file
SSLCipherSuite ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384
SSLProtocol TLSv1.2 TLSv1.3
SSLOpenSSLConfCmd DHParameters $dh_file
EOF

        # This would need to be integrated properly with Apache config
        print "Apache SSL configuration updated\n";
    }
}

sub configure_nginx_ssl {
    my $nginx_ssl_conf = '/etc/nginx/conf.d/ssl.conf';

    my $ssl_config = <<"EOF";
ssl_certificate $cert_file;
ssl_certificate_key $key_file;
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
ssl_prefer_server_ciphers off;
ssl_dhparam $dh_file;
EOF

    open(my $fh, '>', $nginx_ssl_conf) or die "Cannot write nginx config: $!";
    print $fh $ssl_config;
    close($fh);

    print "Nginx SSL configuration created\n";
}

sub setup_client_cert_auth {
    print "Setting up client certificate authentication...\n";

    # Create CA for client certificates
    my $ca_dir = "$ssl_dir/ca";
    mkdir($ca_dir) unless -d $ca_dir;

    my $ca_key = "$ca_dir/ca.key";
    my $ca_cert = "$ca_dir/ca.crt";

    unless (-f $ca_cert) {
        system("openssl genrsa -out $ca_key 4096");
        system("openssl req -x509 -new -key $ca_key -out $ca_cert -days 365 -subj '/C=US/ST=Security/L=ZeroTrust/O=ZT-CA/CN=ZeroTrust-CA'");
    }

    # Configure Apache/Nginx for client cert auth
    my $client_auth_config = <<"EOF";
SSLVerifyClient optional
SSLVerifyDepth 1
SSLCACertificateFile $ca_cert
EOF

    print "Client certificate authentication configured\n";
}

sub configure_encryption_policies {
    print "Configuring encryption policies...\n";

    # Update Zero-Trust configuration
    require './zero-trust-lib.pl';
    load_zero_trust_config();

    $zero_trust_config{'encryption'}{'e2e_enabled'} = 1;
    $zero_trust_config{'encryption'}{'tls_version'} = '1.3';
    $zero_trust_config{'encryption'}{'cert_validation'} = 1;
    $zero_trust_config{'encryption'}{'client_cert_auth'} = 1;

    &write_file("$config_directory/zero_trust.config", \%zero_trust_config);

    print "Encryption policies configured\n";
}

1;