# Revisión funcional Webmin/Virtualmin (Docker)
Fecha: Sun Aug 10 16:24:43 UTC 2025

## Versiones
- Webmin: 
- Virtualmin: Command --version.pl was not found
NO_INSTALADO

## Servicios
- webmin: ACTIVO
- usermin: ACTIVO
- apache2: ACTIVO
- mariadb: ACTIVO
- mysql: ACTIVO
- postfix: ACTIVO
- dovecot: ACTIVO
- proftpd: ACTIVO
- bind9: ACTIVO

## Puertos
- udp 0.0.0.0:20000 users:(("perl",pid=15492,fd=6))
- udp 0.0.0.0:10000 users:(("miniserv.pl",pid=43447,fd=7))
- tcp 0.0.0.0:443 users:(("apache2",pid=45418,fd=4),("apache2",pid=45417,fd=4),("apache2",pid=45416,fd=4),("apache2",pid=42496,fd=4))
- tcp 0.0.0.0:80 users:(("apache2",pid=45418,fd=3),("apache2",pid=45417,fd=3),("apache2",pid=45416,fd=3),("apache2",pid=42496,fd=3))
- tcp 0.0.0.0:110 users:(("dovecot",pid=42312,fd=21))
- tcp 0.0.0.0:25 users:(("master",pid=45397,fd=13))
- tcp 0.0.0.0:143 users:(("dovecot",pid=42312,fd=38))
- tcp 0.0.0.0:995 users:(("dovecot",pid=42312,fd=23))
- tcp 0.0.0.0:993 users:(("dovecot",pid=42312,fd=40))
- tcp 0.0.0.0:587 users:(("master",pid=45397,fd=110))
- tcp 0.0.0.0:10000 users:(("miniserv.pl",pid=43447,fd=5))
- tcp 0.0.0.0:20000 users:(("perl",pid=15492,fd=5))
- tcp [::]:110 users:(("dovecot",pid=42312,fd=22))
- tcp [::]:25 users:(("master",pid=45397,fd=14))
- tcp [::]:143 users:(("dovecot",pid=42312,fd=39))
- tcp [::]:995 users:(("dovecot",pid=42312,fd=24))
- tcp [::]:993 users:(("dovecot",pid=42312,fd=41))
- tcp [::]:587 users:(("master",pid=45397,fd=111))
- tcp [::]:10000 users:(("miniserv.pl",pid=43447,fd=6))

## Pruebas HTTP(S)
- Webmin HTTPS -> HTTP 200
- Usermin HTTPS -> HTTP 200

## virtualmin check-config
Your system has 11.91 GiB of memory, which is at or above the Virtualmin recommended minimum of 256 MiB

BIND DNS server is installed, however, the default primary DNS server panel.example.com does not resolve to an IP address

Mail server Postfix is installed and configured

Postfix is configured to support per-domain outgoing IP addresses

Apache is installed

Apache supports HTTP/2 on your system

The following CGI script execution modes are available : suexec fcgiwrap

The following PHP execution modes are available : fpm fcgid cgi

The following PHP versions are available : 8.1.2 (/bin/php-cgi8.1)

The following PHP-FPM versions are available : 8.1.2 (php8.1-fpm)

Apache is configured to host SSL websites

MariaDB 10.6.22 is installed and running, using Unix socket authentication

Logrotate is installed

Plugin AWStats reporting is installed

Plugin Protected web directories is installed

Using network interface eth0 for virtual IPs

Default IPv4 address for virtual servers is 172.17.0.3

Detected external IPv4 address is 107.72.162.18

Quotas are not enabled on the filesystem / which contains home directories under /home and email files under /home. Quota editing has been disabled


All commands needed to create and restore backups are installed

The selected package management and update systems are installed

Chroot jails are available

Updating all Webmin users with new settings..
.. done

Updating Virtualmin library pre-load settings ..
.. done

Updating status collection job ..
.. done

Re-loading Webmin ..
.. done


## Logs (tail)
### /var/webmin/miniserv.error
[10/Aug/2025:16:10:38 +0000] miniserv.pl started
[10/Aug/2025:16:10:38 +0000] IPv6 support enabled
[10/Aug/2025:16:10:38 +0000] Using MD5 module Digest::MD5
[10/Aug/2025:16:10:38 +0000] Using SHA512 module Crypt::SHA
[10/Aug/2025:16:10:38 +0000] PAM authentication enabled
[10/Aug/2025:16:19:20 +0000] Reloading configuration
[10/Aug/2025:16:19:21 +0000] Restarting
[10/Aug/2025:16:19:24 +0000] miniserv.pl started
[10/Aug/2025:16:19:24 +0000] IPv6 support enabled
[10/Aug/2025:16:19:24 +0000] Using MD5 module Digest::MD5
[10/Aug/2025:16:19:24 +0000] Using SHA512 module Crypt::SHA
[10/Aug/2025:16:19:24 +0000] PAM authentication enabled
[10/Aug/2025:16:19:26 +0000] Reloading configuration
[10/Aug/2025:16:19:27 +0000] Reloading configuration
[10/Aug/2025:16:19:28 +0000] Reloading configuration
Failed to add filter for units: No data available
Failed to add filter for units: No data available
[10/Aug/2025:16:22:16 +0000] Shutting down
[10/Aug/2025:16:22:16 +0000] Shutting down
[10/Aug/2025:16:22:18 +0000] miniserv.pl started
[10/Aug/2025:16:22:18 +0000] IPv6 support enabled
[10/Aug/2025:16:22:18 +0000] Using MD5 module Digest::MD5
[10/Aug/2025:16:22:18 +0000] Using SHA512 module Crypt::SHA
[10/Aug/2025:16:22:18 +0000] PAM authentication enabled
[10/Aug/2025:16:22:25 +0000] Reloading configuration
[10/Aug/2025:16:22:55 +0000] Reloading configuration
[10/Aug/2025:16:24:43 +0000] Reloading configuration
[10/Aug/2025:16:24:47 +0000] Restarting
[10/Aug/2025:16:24:49 +0000] miniserv.pl started
[10/Aug/2025:16:24:49 +0000] IPv6 support enabled
[10/Aug/2025:16:24:49 +0000] Using MD5 module Digest::MD5
[10/Aug/2025:16:24:49 +0000] Using SHA512 module Crypt::SHA
[10/Aug/2025:16:24:49 +0000] PAM authentication enabled
[10/Aug/2025:16:24:52 +0000] Reloading configuration

### /tmp/virtualmin-install.log
update-alternatives: using /usr/bin/identify-im6.q16 to provide /usr/bin/identify-im6 (identify-im6) in auto mode
update-alternatives: warning: skip creation of /usr/share/man/man1/identify-im6.1.gz because associated file /usr/share/man/man1/identify-im6.q16.1.gz (of link group identify-im6) doesn't exist
update-alternatives: using /usr/bin/stream-im6.q16 to provide /usr/bin/stream (stream) in auto mode
update-alternatives: warning: skip creation of /usr/share/man/man1/stream.1.gz because associated file /usr/share/man/man1/stream-im6.q16.1.gz (of link group stream) doesn't exist
update-alternatives: using /usr/bin/stream-im6.q16 to provide /usr/bin/stream-im6 (stream-im6) in auto mode
update-alternatives: warning: skip creation of /usr/share/man/man1/stream-im6.1.gz because associated file /usr/share/man/man1/stream-im6.q16.1.gz (of link group stream-im6) doesn't exist
update-alternatives: using /usr/bin/display-im6.q16 to provide /usr/bin/display (display) in auto mode
update-alternatives: warning: skip creation of /usr/share/man/man1/display.1.gz because associated file /usr/share/man/man1/display-im6.q16.1.gz (of link group display) doesn't exist
update-alternatives: using /usr/bin/display-im6.q16 to provide /usr/bin/display-im6 (display-im6) in auto mode
update-alternatives: warning: skip creation of /usr/share/man/man1/display-im6.1.gz because associated file /usr/share/man/man1/display-im6.q16.1.gz (of link group display-im6) doesn't exist
update-alternatives: using /usr/bin/montage-im6.q16 to provide /usr/bin/montage (montage) in auto mode
update-alternatives: warning: skip creation of /usr/share/man/man1/montage.1.gz because associated file /usr/share/man/man1/montage-im6.q16.1.gz (of link group montage) doesn't exist
update-alternatives: using /usr/bin/montage-im6.q16 to provide /usr/bin/montage-im6 (montage-im6) in auto mode
update-alternatives: warning: skip creation of /usr/share/man/man1/montage-im6.1.gz because associated file /usr/share/man/man1/montage-im6.q16.1.gz (of link group montage-im6) doesn't exist
update-alternatives: using /usr/bin/mogrify-im6.q16 to provide /usr/bin/mogrify (mogrify) in auto mode
update-alternatives: warning: skip creation of /usr/share/man/man1/mogrify.1.gz because associated file /usr/share/man/man1/mogrify-im6.q16.1.gz (of link group mogrify) doesn't exist
update-alternatives: using /usr/bin/mogrify-im6.q16 to provide /usr/bin/mogrify-im6 (mogrify-im6) in auto mode
update-alternatives: warning: skip creation of /usr/share/man/man1/mogrify-im6.1.gz because associated file /usr/share/man/man1/mogrify-im6.q16.1.gz (of link group mogrify-im6) doesn't exist
Setting up imagemagick (8:6.9.11.60+dfsg-1.3ubuntu0.22.04.5) ...
Setting up libwww-perl (6.61-1) ...
Setting up liblwp-protocol-https-perl (6.10-1) ...
Setting up libxml-parser-perl:arm64 (2.46-3build1) ...
Setting up libxml-sax-expat-perl (0.51-1) ...
update-perl-sax-parsers: Registering Perl SAX parser XML::SAX::Expat with priority 50...
update-perl-sax-parsers: Updating overall Perl SAX parser modules info file...
Replacing config file /etc/perl/XML/SAX/ParserDetails.ini with new version
Processing triggers for libc-bin (2.35-0ubuntu3.10) ...
Processing triggers for dbus (1.12.20-2ubuntu4.1) ...
Processing triggers for shared-mime-info (2.1-2) ...
Processing triggers for sgml-base (1.30) ...
Setting up docutils-common (0.17.1+dfsg-2) ...
Processing triggers for sgml-base (1.30) ...
Setting up python3-docutils (0.17.1+dfsg-2) ...
Setting up awscli (1.22.34-1) ...
Processing triggers for dovecot-core (1:2.3.16+dfsg1-3ubuntu2.4) ...
Processing triggers for php8.1-cli (8.1.2-1ubuntu2.22) ...
Processing triggers for php8.1-cgi (8.1.2-1ubuntu2.22) ...
Processing triggers for php8.1-fpm (8.1.2-1ubuntu2.22) ...
NOTICE: Not enabling PHP 8.1 FPM by default.
NOTICE: To enable PHP 8.1 FPM in Apache2 do:
NOTICE: a2enmod proxy_fcgi setenvif
NOTICE: a2enconf php8.1-fpm
NOTICE: You are seeing this message because you have apache2 package installed.
[2025-08-10 16:18:47 UTC] [INFO]  Installing Virtualmin 7 and all related packages: [2025-08-10 16:18:47 UTC] [INFO]  Success.
./virtualmin-install.sh: 1220: /usr/sbin/ntpdate-debian: not found
[2025-08-10 16:21:43 UTC] [INFO]  Spin pid is: 42391
Reading package lists...
Building dependency tree...
Reading state information...
virtualmin-lamp-stack-minimal is already the newest version (7.0.6-1).
0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
[2025-08-10 16:21:43 UTC] [INFO]  Installing Virtualmin 7 related package updates: [2025-08-10 16:21:43 UTC] [INFO]  Success.
[2025-08-10 16:21:46 UTC] [DEBUG] Phase 4 of 4: Configuration
[2025-08-10 16:23:00 UTC] [DEBUG] SSL certificate request for the hostname : 0 : Failed to set up SSL certificate for the panel.example.com hostname
[2025-08-10 16:23:00 UTC] [DEBUG] Cleaning up temporary files in /tmp/.virtualmin-12513.
[2025-08-10 16:23:00 UTC] [DEBUG] Primary address detected as 172.17.0.3
[2025-08-10 16:23:00 UTC] [SUCCESS] Installation Complete!
[2025-08-10 16:23:00 UTC] [SUCCESS] If there were no errors above, Virtualmin should be ready
[2025-08-10 16:23:00 UTC] [SUCCESS] to configure at https://panel.example.com:10000 (or https://172.17.0.3:10000).
[2025-08-10 16:23:00 UTC] [SUCCESS] You may receive a security warning in your browser on your first visit.
