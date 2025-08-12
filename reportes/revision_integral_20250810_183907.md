# Revisión integral de servicios y funciones
Fecha: Sun Aug 10 18:39:07 UTC 2025
- ID=debian VERSION_ID=12 ARCH=aarch64

## Hostname/FQDN
hostname: panel.example.com
hostname -f: panel.example.com

## Webmin/Usermin
- webmin: ACTIVO
- usermin: ACTIVO
miniserv.conf (port/ssl/bind):
port=10000
ssl=1
bind=127.0.0.1
Cert SSL: 
OK /etc/webmin/miniserv.pem
curl local https://127.0.0.1:10000:
HTTP/1.0 200 Document follows

## Servicios clave
- apache2: ACTIVO
- mysql: ACTIVO
- mariadb: ACTIVO
- postfix: ACTIVO
- dovecot: ACTIVO
- opendkim: ACTIVO
- spamassassin: INACTIVO
- clamav-daemon: ACTIVO
- clamav-freshclam: ACTIVO
- fail2ban: ACTIVO

## Puertos escuchando
udp   UNCONN 0      0            0.0.0.0:10000      0.0.0.0:*    users:(("miniserv.pl",pid=53809,fd=6)) ino:285826 sk:108b cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/webmin.service <->                                                                              
udp   UNCONN 0      0            0.0.0.0:20000      0.0.0.0:*    users:(("miniserv.pl",pid=53834,fd=6)) ino:284072 sk:108c cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/usermin.service <->                                                                             
tcp   LISTEN 0      100          0.0.0.0:995        0.0.0.0:*    users:(("dovecot",pid=43087,fd=24)) ino:262164 sk:4005 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/dovecot.service <->                                                                                
tcp   LISTEN 0      100          0.0.0.0:993        0.0.0.0:*    users:(("dovecot",pid=43087,fd=41)) ino:262179 sk:4006 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/dovecot.service <->                                                                                
tcp   LISTEN 0      100          0.0.0.0:587        0.0.0.0:*    users:(("master",pid=47580,fd=110)) ino:273655 sk:4050 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/system-postfix.slice/postfix@-.service <->                                                         
tcp   LISTEN 0      511          0.0.0.0:443        0.0.0.0:*    users:(("apache2",pid=52424,fd=5),("apache2",pid=52423,fd=5),("apache2",pid=52422,fd=5),("apache2",pid=52416,fd=5)) ino:280701 sk:4051 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/apache2.service <->
tcp   LISTEN 0      100          0.0.0.0:465        0.0.0.0:*    users:(("master",pid=47580,fd=114)) ino:273661 sk:4052 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/system-postfix.slice/postfix@-.service <->                                                         
tcp   LISTEN 0      100          0.0.0.0:143        0.0.0.0:*    users:(("dovecot",pid=43087,fd=39)) ino:262177 sk:400a cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/dovecot.service <->                                                                                
tcp   LISTEN 0      100          0.0.0.0:25         0.0.0.0:*    users:(("master",pid=47580,fd=13)) ino:273557 sk:4053 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/system-postfix.slice/postfix@-.service <->                                                          
tcp   LISTEN 0      511          0.0.0.0:80         0.0.0.0:*    users:(("apache2",pid=52424,fd=4),("apache2",pid=52423,fd=4),("apache2",pid=52422,fd=4),("apache2",pid=52416,fd=4)) ino:280699 sk:4054 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/apache2.service <->
tcp   LISTEN 0      100          0.0.0.0:110        0.0.0.0:*    users:(("dovecot",pid=43087,fd=22)) ino:262162 sk:400d cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/dovecot.service <->                                                                                
tcp   LISTEN 0      4096       127.0.0.1:10000      0.0.0.0:*    users:(("miniserv.pl",pid=53809,fd=5)) ino:285825 sk:5001 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/webmin.service <->                                                                              
tcp   LISTEN 0      4096       127.0.0.1:20000      0.0.0.0:*    users:(("miniserv.pl",pid=53834,fd=5)) ino:284071 sk:5002 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/usermin.service <->                                                                             
tcp   LISTEN 0      100             [::]:995           [::]:*    users:(("dovecot",pid=43087,fd=25)) ino:262165 sk:4044 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/dovecot.service v6only:1 <->                                                                       
tcp   LISTEN 0      100             [::]:993           [::]:*    users:(("dovecot",pid=43087,fd=42)) ino:262180 sk:4045 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/dovecot.service v6only:1 <->                                                                       
tcp   LISTEN 0      100             [::]:587           [::]:*    users:(("master",pid=47580,fd=111)) ino:273656 sk:4059 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/system-postfix.slice/postfix@-.service v6only:1 <->                                                
tcp   LISTEN 0      100             [::]:465           [::]:*    users:(("master",pid=47580,fd=115)) ino:273662 sk:405a cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/system-postfix.slice/postfix@-.service v6only:1 <->                                                
tcp   LISTEN 0      100             [::]:143           [::]:*    users:(("dovecot",pid=43087,fd=40)) ino:262178 sk:4048 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/dovecot.service v6only:1 <->                                                                       
tcp   LISTEN 0      100             [::]:25            [::]:*    users:(("master",pid=47580,fd=14)) ino:273558 sk:405b cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/system-postfix.slice/postfix@-.service v6only:1 <->                                                 
tcp   LISTEN 0      100             [::]:110           [::]:*    users:(("dovecot",pid=43087,fd=23)) ino:262163 sk:404b cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/dovecot.service v6only:1 <->                                                                       

## Virtualmin check-config (primeras 200 líneas)
Your system has 11.91 GiB of memory, which is at or above the Virtualmin recommended minimum of 256 MiB

BIND DNS server is installed, however, the default primary DNS server panel.example.com does not resolve to an IP address

Mail server Postfix is installed and configured

Postfix is configured to support per-domain outgoing IP addresses

Apache is installed

Apache supports HTTP/2 on your system

The following CGI script execution modes are available : suexec fcgiwrap

The following PHP execution modes are available : fpm fcgid cgi

The following PHP versions are available : 8.2.29 (/bin/php-cgi8.2)

The following PHP-FPM versions are available : 8.2.29 (php8.2-fpm)

Apache is configured to host SSL websites

MariaDB 10.11.11 is installed and running, using Unix socket authentication

Logrotate is installed

SpamAssassin and Procmail are installed and configured for use

ClamAV is installed and assumed to be running

Plugin AWStats reporting is installed

Plugin Protected web directories is installed

Using network interface eth0 for virtual IPs

Default IPv4 address for virtual servers is 172.17.0.4

Detected external IPv4 address is 107.72.162.18

Quotas are not enabled on the filesystem / which contains home directories under /home and email files under /home. Quota editing has been disabled


All commands needed to create and restore backups are installed

The selected package management and update systems are installed

Chroot jails are available


## Apache prueba HTTP
HTTP/1.1 200 OK

## Roundcube (si instalado)
HTTP/1.1 404 Not Found

## Dovecot/Postfix config (extracto)
alias_database = hash:/etc/aliases
alias_maps = hash:/etc/aliases
allow_percent_hack = no
append_dot_mydomain = no
biff = no
broken_sasl_auth_clients = yes
compatibility_level = 3.6
home_mailbox = Maildir/
inet_interfaces = all
inet_protocols = all
mailbox_command = /usr/bin/procmail-wrapper -o -a $DOMAIN -d $LOGNAME
mailbox_size_limit = 0
milter_default_action = accept
mydestination = $myhostname, dcf62950f2cb, panel.example.com, localhost.example.com, localhost
myhostname = panel.example.com
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
non_smtpd_milters = inet:127.0.0.1:8891
readme_directory = no
recipient_delimiter = +
relayhost =
resolve_dequoted_address = no
sender_bcc_maps = hash:/etc/postfix/bcc
sender_dependent_default_transport_maps = hash:/etc/postfix/dependent
smtp_dns_support_level = dnssec
smtp_host_lookup = dns
smtp_tls_CApath = /etc/ssl/certs
smtp_tls_security_level = dane
smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache
smtpd_banner = $myhostname ESMTP $mail_name (Debian/GNU)
smtpd_milters = inet:127.0.0.1:8891
smtpd_recipient_restrictions = permit_mynetworks permit_sasl_authenticated reject_unauth_destination, check_policy_service unix:private/policyd-spf
smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
smtpd_tls_cert_file = /etc/ssl/certs/ssl-cert-snakeoil.pem
smtpd_tls_key_file = /etc/ssl/private/ssl-cert-snakeoil.key
smtpd_tls_security_level = may
tls_server_sni_maps = hash:/etc/postfix/sni_map
virtual_alias_maps = hash:/etc/postfix/virtual
---
# 2.3.19.1 (9b53102964): /etc/dovecot/dovecot.conf
# Pigeonhole version 0.5.19 (4eae2f79)
# OS: Linux 6.10.14-linuxkit aarch64 Debian 12.11 
# Hostname: panel.example.com
auth_mechanisms = plain login
disable_plaintext_auth = no
mail_location = maildir:~/Maildir
mail_privileged_group = mail
namespace {
  inbox = yes
  location = 
  mailbox {
    special_use = \Drafts
    name = Drafts
  }
  mailbox {
    special_use = \Junk
    name = Junk
  }
  mailbox {
    special_use = \Sent
    name = Sent
  }
  mailbox {
    special_use = \Sent
    name = Sent Messages
  }
  mailbox {
    special_use = \Trash
    name = Trash
  }
  prefix = 
  name = inbox
}
passdb {
  driver = pam
}
protocols = imap pop3
service replication-notify-fifo {
  name = aggregator
}
service anvil-auth-penalty {
  name = anvil
}
service auth-worker {
  name = auth-worker
}
service auth-client {
  name = auth
}
service config {
  name = config
}
service dict-async {
  name = dict-async
}
service dict {
  name = dict
}
service login/proxy-notify {
  name = director
}
service dns-client {
  name = dns-client
}
service doveadm-server {
  name = doveadm
}
service imap-hibernate {
  name = imap-hibernate
}
service imap {
  name = imap-login
}
service imap-urlauth {
  name = imap-urlauth-login
}
service imap-urlauth-worker {
  name = imap-urlauth-worker
}

## OpenDKIM socket
tcp   LISTEN 0      4096       127.0.0.1:8891       0.0.0.0:*    users:(("opendkim",pid=44611,fd=3))                                                                                

## Fail2ban jails
Status
|- Number of jail:	6
`- Jail list:	dovecot, postfix, postfix-sasl, proftpd, sshd, webmin-auth

## Logs recientes
miniserv.error:
[10/Aug/2025:17:50:00 +0000] miniserv.pl started
[10/Aug/2025:17:50:00 +0000] IPv6 support enabled
[10/Aug/2025:17:50:00 +0000] Using MD5 module Digest::MD5
[10/Aug/2025:17:50:00 +0000] Using SHA512 module Crypt::SHA
[10/Aug/2025:17:50:00 +0000] PAM authentication enabled
[10/Aug/2025:17:50:03 +0000] Reloading configuration
[10/Aug/2025:17:50:04 +0000] Reloading configuration
[10/Aug/2025:17:50:05 +0000] Reloading configuration
[10/Aug/2025:17:53:30 +0000] Shutting down
[10/Aug/2025:17:53:32 +0000] miniserv.pl started
[10/Aug/2025:17:53:32 +0000] IPv6 support enabled
[10/Aug/2025:17:53:32 +0000] Using MD5 module Digest::MD5
[10/Aug/2025:17:53:32 +0000] Using SHA512 module Crypt::SHA
[10/Aug/2025:17:53:32 +0000] PAM authentication enabled
[10/Aug/2025:17:53:45 +0000] Reloading configuration
[10/Aug/2025:17:54:16 +0000] Reloading configuration
[10/Aug/2025:17:54:21 +0000] Shutting down
[10/Aug/2025:17:54:23 +0000] miniserv.pl started
[10/Aug/2025:17:54:23 +0000] IPv6 support enabled
[10/Aug/2025:17:54:23 +0000] Using MD5 module Digest::MD5
[10/Aug/2025:17:54:23 +0000] Using SHA512 module Crypt::SHA
[10/Aug/2025:17:54:23 +0000] PAM authentication enabled
[10/Aug/2025:17:54:33 +0000] Shutting down
[10/Aug/2025:17:54:35 +0000] miniserv.pl started
[10/Aug/2025:17:54:35 +0000] IPv6 support enabled
[10/Aug/2025:17:54:35 +0000] Using MD5 module Digest::MD5
[10/Aug/2025:17:54:35 +0000] Using SHA512 module Crypt::SHA
[10/Aug/2025:17:54:35 +0000] PAM authentication enabled
[10/Aug/2025:17:54:35 +0000] Shutting down
[10/Aug/2025:17:54:35 +0000] Shutting down
[10/Aug/2025:17:54:35 +0000] Shutting down
[10/Aug/2025:17:54:37 +0000] miniserv.pl started
[10/Aug/2025:17:54:37 +0000] IPv6 support enabled
[10/Aug/2025:17:54:37 +0000] Using MD5 module Digest::MD5
[10/Aug/2025:17:54:37 +0000] Using SHA512 module Crypt::SHA
[10/Aug/2025:17:54:37 +0000] PAM authentication enabled
[10/Aug/2025:17:55:06 +0000] Restarting
[10/Aug/2025:17:55:08 +0000] miniserv.pl started
[10/Aug/2025:17:55:08 +0000] IPv6 support enabled
[10/Aug/2025:17:55:08 +0000] Using MD5 module Digest::MD5
[10/Aug/2025:17:55:08 +0000] Using SHA512 module Crypt::SHA
[10/Aug/2025:17:55:08 +0000] PAM authentication enabled
[10/Aug/2025:17:55:18 +0000] Reloading configuration
[10/Aug/2025:17:55:46 +0000] Reloading configuration
[10/Aug/2025:18:07:37 +0000] Shutting down
[10/Aug/2025:18:07:39 +0000] miniserv.pl started
[10/Aug/2025:18:07:39 +0000] IPv6 support enabled
[10/Aug/2025:18:07:39 +0000] Using MD5 module Digest::MD5
[10/Aug/2025:18:07:39 +0000] Using SHA512 module Crypt::SHA
[10/Aug/2025:18:07:39 +0000] PAM authentication enabled

apache2/error.log:
[Sun Aug 10 17:51:51.467936 2025] [suexec:notice] [pid 42800:tid 42800] AH01232: suEXEC mechanism enabled (wrapper: /usr/lib/apache2/suexec)
[Sun Aug 10 17:51:51.474371 2025] [mpm_event:notice] [pid 42801:tid 42801] AH00489: Apache/2.4.62 (Debian) mod_fcgid/2.3.9 OpenSSL/3.0.17 configured -- resuming normal operations
[Sun Aug 10 17:51:51.474400 2025] [core:notice] [pid 42801:tid 42801] AH00094: Command line: '/usr/sbin/apache2'
[Sun Aug 10 17:53:45.609730 2025] [mpm_event:notice] [pid 42801:tid 42801] AH00493: SIGUSR1 received.  Doing graceful restart
[Sun Aug 10 17:53:45.674504 2025] [mpm_event:notice] [pid 42801:tid 42801] AH00489: Apache/2.4.62 (Debian) mod_fcgid/2.3.9 OpenSSL/3.0.17 configured -- resuming normal operations
[Sun Aug 10 17:53:45.674515 2025] [core:notice] [pid 42801:tid 42801] AH00094: Command line: '/usr/sbin/apache2'
[Sun Aug 10 17:54:18.975060 2025] [mpm_event:notice] [pid 42801:tid 42801] AH00493: SIGUSR1 received.  Doing graceful restart
[Sun Aug 10 17:54:19.030841 2025] [mpm_event:notice] [pid 42801:tid 42801] AH00489: Apache/2.4.62 (Debian) mod_fcgid/2.3.9 OpenSSL/3.0.17 configured -- resuming normal operations
[Sun Aug 10 17:54:19.030885 2025] [core:notice] [pid 42801:tid 42801] AH00094: Command line: '/usr/sbin/apache2'
[Sun Aug 10 17:55:39.291911 2025] [mpm_event:notice] [pid 42801:tid 42801] AH00492: caught SIGWINCH, shutting down gracefully
[Sun Aug 10 17:55:39.432159 2025] [security2:notice] [pid 52117:tid 52117] ModSecurity for Apache/2.9.7 (http://www.modsecurity.org/) configured.
[Sun Aug 10 17:55:39.432208 2025] [security2:notice] [pid 52117:tid 52117] ModSecurity: APR compiled version="1.7.2"; loaded version="1.7.2"
[Sun Aug 10 17:55:39.432210 2025] [security2:notice] [pid 52117:tid 52117] ModSecurity: PCRE2 compiled version="10.42 "; loaded version="10.42 2022-12-11"
[Sun Aug 10 17:55:39.432212 2025] [security2:notice] [pid 52117:tid 52117] ModSecurity: LUA compiled version="Lua 5.1"
[Sun Aug 10 17:55:39.432213 2025] [security2:notice] [pid 52117:tid 52117] ModSecurity: YAJL compiled version="2.1.0"
[Sun Aug 10 17:55:39.432214 2025] [security2:notice] [pid 52117:tid 52117] ModSecurity: LIBXML compiled version="2.9.14"
[Sun Aug 10 17:55:39.432215 2025] [security2:notice] [pid 52117:tid 52117] ModSecurity: Status engine is currently disabled, enable it by set SecStatusEngine to On.
[Sun Aug 10 17:55:39.432724 2025] [suexec:notice] [pid 52117:tid 52117] AH01232: suEXEC mechanism enabled (wrapper: /usr/lib/apache2/suexec)
[Sun Aug 10 17:55:39.474491 2025] [mpm_event:notice] [pid 52118:tid 52118] AH00489: Apache/2.4.62 (Debian) OpenSSL/3.0.17 mod_fcgid/2.3.9 configured -- resuming normal operations
[Sun Aug 10 17:55:39.474511 2025] [core:notice] [pid 52118:tid 52118] AH00094: Command line: '/usr/sbin/apache2'
[Sun Aug 10 17:55:40.144382 2025] [mpm_event:notice] [pid 52118:tid 52118] AH00492: caught SIGWINCH, shutting down gracefully
[Sun Aug 10 17:55:40.301010 2025] [security2:notice] [pid 52415:tid 52415] ModSecurity for Apache/2.9.7 (http://www.modsecurity.org/) configured.
[Sun Aug 10 17:55:40.301052 2025] [security2:notice] [pid 52415:tid 52415] ModSecurity: APR compiled version="1.7.2"; loaded version="1.7.2"
[Sun Aug 10 17:55:40.301054 2025] [security2:notice] [pid 52415:tid 52415] ModSecurity: PCRE2 compiled version="10.42 "; loaded version="10.42 2022-12-11"
[Sun Aug 10 17:55:40.301055 2025] [security2:notice] [pid 52415:tid 52415] ModSecurity: LUA compiled version="Lua 5.1"
[Sun Aug 10 17:55:40.301057 2025] [security2:notice] [pid 52415:tid 52415] ModSecurity: YAJL compiled version="2.1.0"
[Sun Aug 10 17:55:40.301058 2025] [security2:notice] [pid 52415:tid 52415] ModSecurity: LIBXML compiled version="2.9.14"
[Sun Aug 10 17:55:40.301059 2025] [security2:notice] [pid 52415:tid 52415] ModSecurity: Status engine is currently disabled, enable it by set SecStatusEngine to On.
[Sun Aug 10 17:55:40.301515 2025] [suexec:notice] [pid 52415:tid 52415] AH01232: suEXEC mechanism enabled (wrapper: /usr/lib/apache2/suexec)
[Sun Aug 10 17:55:40.346742 2025] [mpm_event:notice] [pid 52416:tid 52416] AH00489: Apache/2.4.62 (Debian) OpenSSL/3.0.17 mod_fcgid/2.3.9 configured -- resuming normal operations
[Sun Aug 10 17:55:40.346783 2025] [core:notice] [pid 52416:tid 52416] AH00094: Command line: '/usr/sbin/apache2'
[Sun Aug 10 18:39:16.691793 2025] [security2:error] [pid 52423:tid 52471] [client 127.0.0.1:46532] [client 127.0.0.1] ModSecurity: Warning. Pattern match "^[\\\\d.:]+$" at REQUEST_HEADERS:Host. [file "/usr/share/modsecurity-crs/rules/REQUEST-920-PROTOCOL-ENFORCEMENT.conf"] [line "736"] [id "920350"] [msg "Host header is a numeric IP address"] [data "127.0.0.1"] [severity "WARNING"] [ver "OWASP_CRS/3.3.4"] [tag "application-multi"] [tag "language-multi"] [tag "platform-multi"] [tag "attack-protocol"] [tag "paranoia-level/1"] [tag "OWASP_CRS"] [tag "capec/1000/210/272"] [tag "PCI/6.5.10"] [hostname "127.0.0.1"] [uri "/"] [unique_id "aJjnVBlHbwxykbEYwiTHSwAAAAA"]
[Sun Aug 10 18:39:16.707626 2025] [security2:error] [pid 52424:tid 52491] [client 127.0.0.1:46548] [client 127.0.0.1] ModSecurity: Warning. Pattern match "^[\\\\d.:]+$" at REQUEST_HEADERS:Host. [file "/usr/share/modsecurity-crs/rules/REQUEST-920-PROTOCOL-ENFORCEMENT.conf"] [line "736"] [id "920350"] [msg "Host header is a numeric IP address"] [data "127.0.0.1"] [severity "WARNING"] [ver "OWASP_CRS/3.3.4"] [tag "application-multi"] [tag "language-multi"] [tag "platform-multi"] [tag "attack-protocol"] [tag "paranoia-level/1"] [tag "OWASP_CRS"] [tag "capec/1000/210/272"] [tag "PCI/6.5.10"] [hostname "127.0.0.1"] [uri "/roundcube/"] [unique_id "aJjnVPdnpzuXca82tjAnrwAAAEA"]

mail.log:
sin log mail

fail2ban.log:
2025-08-10 17:53:33,799 fail2ban.filter         [44537]: INFO      findtime: 600
2025-08-10 17:53:33,799 fail2ban.actions        [44537]: INFO      banTime: 600
2025-08-10 17:53:33,799 fail2ban.filter         [44537]: INFO      encoding: UTF-8
2025-08-10 17:53:33,800 fail2ban.jail           [44537]: INFO    Creating new jail 'proftpd'
2025-08-10 17:53:33,802 fail2ban.jail           [44537]: INFO    Jail 'proftpd' uses pyinotify {}
2025-08-10 17:53:33,803 fail2ban.jail           [44537]: INFO    Initiated 'pyinotify' backend
2025-08-10 17:53:33,804 fail2ban.filter         [44537]: INFO      maxRetry: 5
2025-08-10 17:53:33,804 fail2ban.filter         [44537]: INFO      findtime: 600
2025-08-10 17:53:33,804 fail2ban.actions        [44537]: INFO      banTime: 600
2025-08-10 17:53:33,804 fail2ban.filter         [44537]: INFO      encoding: UTF-8
2025-08-10 17:53:33,804 fail2ban.filter         [44537]: INFO    Added logfile: '/var/log/proftpd/proftpd.log' (pos = 0, hash = c59fe6f11ed71ed41994696b68411ff399ca6a87)
2025-08-10 17:53:33,804 fail2ban.jail           [44537]: INFO    Creating new jail 'postfix'
2025-08-10 17:53:33,804 fail2ban.jail           [44537]: INFO    Jail 'postfix' uses systemd {}
2025-08-10 17:53:33,804 fail2ban.jail           [44537]: INFO    Initiated 'systemd' backend
2025-08-10 17:53:33,805 fail2ban.filtersystemd  [44537]: INFO    [postfix] Added journal match for: '_SYSTEMD_UNIT=postfix.service'
2025-08-10 17:53:33,805 fail2ban.filter         [44537]: INFO      maxRetry: 5
2025-08-10 17:53:33,805 fail2ban.filter         [44537]: INFO      findtime: 600
2025-08-10 17:53:33,805 fail2ban.actions        [44537]: INFO      banTime: 600
2025-08-10 17:53:33,805 fail2ban.filter         [44537]: INFO      encoding: UTF-8
2025-08-10 17:53:33,805 fail2ban.jail           [44537]: INFO    Creating new jail 'dovecot'
2025-08-10 17:53:33,805 fail2ban.jail           [44537]: INFO    Jail 'dovecot' uses systemd {}
2025-08-10 17:53:33,805 fail2ban.jail           [44537]: INFO    Initiated 'systemd' backend
2025-08-10 17:53:33,807 fail2ban.datedetector   [44537]: INFO      date pattern `''`: `{^LN-BEG}TAI64N`
2025-08-10 17:53:33,807 fail2ban.filtersystemd  [44537]: INFO    [dovecot] Added journal match for: '_SYSTEMD_UNIT=dovecot.service'
2025-08-10 17:53:33,807 fail2ban.filter         [44537]: INFO      maxRetry: 5
2025-08-10 17:53:33,807 fail2ban.filter         [44537]: INFO      findtime: 600
2025-08-10 17:53:33,807 fail2ban.actions        [44537]: INFO      banTime: 600
2025-08-10 17:53:33,807 fail2ban.filter         [44537]: INFO      encoding: UTF-8
2025-08-10 17:53:33,807 fail2ban.jail           [44537]: INFO    Creating new jail 'postfix-sasl'
2025-08-10 17:53:33,807 fail2ban.jail           [44537]: INFO    Jail 'postfix-sasl' uses systemd {}
2025-08-10 17:53:33,807 fail2ban.jail           [44537]: INFO    Initiated 'systemd' backend
2025-08-10 17:53:33,807 fail2ban.filtersystemd  [44537]: INFO    [postfix-sasl] Added journal match for: '_SYSTEMD_UNIT=postfix.service'
2025-08-10 17:53:33,807 fail2ban.filtersystemd  [44537]: INFO    [postfix-sasl] Added journal match for: '_SYSTEMD_UNIT=postfix@-.service'
2025-08-10 17:53:33,807 fail2ban.filter         [44537]: INFO      maxRetry: 5
2025-08-10 17:53:33,807 fail2ban.filter         [44537]: INFO      findtime: 600
2025-08-10 17:53:33,807 fail2ban.actions        [44537]: INFO      banTime: 600
2025-08-10 17:53:33,807 fail2ban.filter         [44537]: INFO      encoding: UTF-8
2025-08-10 17:53:33,808 fail2ban.filtersystemd  [44537]: INFO    [sshd] Jail is in operation now (process new journal entries)
2025-08-10 17:53:33,808 fail2ban.jail           [44537]: INFO    Jail 'sshd' started
2025-08-10 17:53:33,809 fail2ban.filtersystemd  [44537]: INFO    [webmin-auth] Jail is in operation now (process new journal entries)
2025-08-10 17:53:33,809 fail2ban.jail           [44537]: INFO    Jail 'webmin-auth' started
2025-08-10 17:53:33,810 fail2ban.jail           [44537]: INFO    Jail 'proftpd' started
2025-08-10 17:53:33,810 fail2ban.filtersystemd  [44537]: INFO    [postfix] Jail is in operation now (process new journal entries)
2025-08-10 17:53:33,811 fail2ban.jail           [44537]: INFO    Jail 'postfix' started
2025-08-10 17:53:33,811 fail2ban.filtersystemd  [44537]: INFO    [dovecot] Jail is in operation now (process new journal entries)
2025-08-10 17:53:33,811 fail2ban.jail           [44537]: INFO    Jail 'dovecot' started
2025-08-10 17:53:33,812 fail2ban.filtersystemd  [44537]: INFO    [postfix-sasl] Jail is in operation now (process new journal entries)
2025-08-10 17:53:33,812 fail2ban.jail           [44537]: INFO    Jail 'postfix-sasl' started
2025-08-10 18:02:02,365 fail2ban.filter         [44537]: INFO    [webmin-auth] Found 172.17.0.5 - 2025-08-10 18:02:01
2025-08-10 18:02:15,088 fail2ban.filter         [44537]: INFO    [webmin-auth] Found 172.17.0.5 - 2025-08-10 18:02:14

## Resumen rápido
Errores críticos estimados: 0
