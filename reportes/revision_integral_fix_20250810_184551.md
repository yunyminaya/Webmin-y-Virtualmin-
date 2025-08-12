# Correcciones y verificación
Fecha: Sun Aug 10 18:45:51 UTC 2025

## Activando SpamAssassin
- spamd: ACTIVO

## Roundcube
HTTP/1.1 404 Not Found

## Servicios y puertos
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

## Virtualmin check-config (resumen)
BIND DNS server is installed, however, the default primary DNS server panel.example.com does not resolve to an IP address
SpamAssassin and Procmail are installed and configured for use
ClamAV is installed and assumed to be running
Quotas are not enabled on the filesystem / which contains home directories under /home and email files under /home. Quota editing has been disabled
