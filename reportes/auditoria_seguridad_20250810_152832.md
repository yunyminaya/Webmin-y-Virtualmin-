# Auditoría de seguridad
Fecha: Sun Aug 10 19:28:32 UTC 2025
SO: Debian GNU/Linux 12 (bookworm) (debian 12)
Hostname: panel.example.com

## Servicios de seguridad
- fail2ban: ACTIVO
- clamav-daemon: ACTIVO
- clamav-freshclam: ACTIVO
- spamassassin: INACTIVO
- spamd: ACTIVO
- opendkim: ACTIVO
- apparmor: INACTIVO

## Fail2ban
Status
|- Number of jail:	6
`- Jail list:	dovecot, postfix, postfix-sasl, proftpd, sshd, webmin-auth

## SSH (sshd_config)

## Webmin SSL
port=10000
ssl=1
bind=127.0.0.1
subject=C = ES, ST = Local, L = Local, O = Webmin, CN = panel.example.com
issuer=C = ES, ST = Local, L = Local, O = Webmin, CN = panel.example.com
notBefore=Aug 10 17:54:35 2025 GMT
notAfter=Aug 10 17:54:35 2026 GMT
curl https://127.0.0.1:10000 (HEAD):
HTTP/1.0 200 Document follows

## Apache seguridad
Módulos de interés:
 -  headers_module (shared)
 -  http2_module (shared)
 -  rewrite_module (shared)
 -  security2_module (shared)
 -  ssl_module (shared)
HSTS (si existe):
sin HSTS

## Postfix TLS (postconf -n)
 - smtp_tls_CApath = /etc/ssl/certs
 - smtp_tls_security_level = dane
 - smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache
 - smtpd_tls_cert_file = /etc/ssl/certs/ssl-cert-snakeoil.pem
 - smtpd_tls_key_file = /etc/ssl/private/ssl-cert-snakeoil.key
 - smtpd_tls_security_level = may

## Dovecot (doveconf -n)
 - auth_mechanisms = plain login
 - disable_plaintext_auth = no
 - ssl_cert = </etc/dovecot/private/dovecot.pem
 - ssl_client_ca_dir = /etc/ssl/certs
 - ssl_dh = # hidden, use -P to show it
 - ssl_key = # hidden, use -P to show it

## OpenDKIM socket
tcp   LISTEN 0      4096       127.0.0.1:8891       0.0.0.0:*    users:(("opendkim",pid=44611,fd=3))                                                                                

## ClamAV actualizaciones
Sun Aug 10 19:07:59 2025 -> DON'T PANIC! Read https://docs.clamav.net/manual/Installing.html
Sun Aug 10 19:07:59 2025 -> daily.cvd database is up-to-date (version: 27728, sigs: 2076423, f-level: 90, builder: raynman)
Sun Aug 10 19:07:59 2025 -> main.cvd database is up-to-date (version: 62, sigs: 6647427, f-level: 90, builder: sigmgr)
Sun Aug 10 19:07:59 2025 -> bytecode.cvd database is up-to-date (version: 336, sigs: 83, f-level: 90, builder: nrandolp)
Sun Aug 10 19:07:59 2025 -> --------------------------------------

## Firewall
UFW no instalado
nftables (primeras 60 líneas):
table ip filter {
}
table ip6 filter {
}
table inet firewalld {
}

## Actualizaciones automáticas
unattended-upgrades: NO INSTALADO
50unattended-upgrades: FALTA

## Sysctl (red)

## Puertos relevantes
udp   UNCONN 0      0            0.0.0.0:10000      0.0.0.0:*    users:(("miniserv.pl",pid=53809,fd=6)) ino:285826 sk:108b cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/webmin.service <->                                                                              
udp   UNCONN 0      0            0.0.0.0:20000      0.0.0.0:*    users:(("miniserv.pl",pid=53834,fd=6)) ino:284072 sk:108c cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/usermin.service <->                                                                             
tcp   LISTEN 0      100          0.0.0.0:995        0.0.0.0:*    users:(("dovecot",pid=43087,fd=24)) ino:262164 sk:4005 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/dovecot.service <->                                                                                
tcp   LISTEN 0      100          0.0.0.0:993        0.0.0.0:*    users:(("dovecot",pid=43087,fd=41)) ino:262179 sk:4006 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/dovecot.service <->                                                                                
tcp   LISTEN 0      100          0.0.0.0:587        0.0.0.0:*    users:(("master",pid=47580,fd=110)) ino:273655 sk:4050 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/system-postfix.slice/postfix@-.service <->                                                         
tcp   LISTEN 0      511          0.0.0.0:443        0.0.0.0:*    users:(("apache2",pid=55196,fd=5),("apache2",pid=55195,fd=5),("apache2",pid=55194,fd=5),("apache2",pid=52416,fd=5)) ino:280701 sk:4051 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/apache2.service <->
tcp   LISTEN 0      100          0.0.0.0:465        0.0.0.0:*    users:(("master",pid=47580,fd=114)) ino:273661 sk:4052 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/system-postfix.slice/postfix@-.service <->                                                         
tcp   LISTEN 0      100          0.0.0.0:143        0.0.0.0:*    users:(("dovecot",pid=43087,fd=39)) ino:262177 sk:400a cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/dovecot.service <->                                                                                
tcp   LISTEN 0      100          0.0.0.0:25         0.0.0.0:*    users:(("master",pid=47580,fd=13)) ino:273557 sk:4053 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/system-postfix.slice/postfix@-.service <->                                                          
tcp   LISTEN 0      511          0.0.0.0:80         0.0.0.0:*    users:(("apache2",pid=55196,fd=4),("apache2",pid=55195,fd=4),("apache2",pid=55194,fd=4),("apache2",pid=52416,fd=4)) ino:280699 sk:4054 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/apache2.service <->
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

## Observaciones
- INFO: UFW no instalado (usando nft/iptables o ninguno)
- INFO: HSTS no detectado en vhost SSL

