# Validación de tableros (Webmin, Virtualmin, Usermin)
Fecha: Sun Aug 10 19:04:02 UTC 2025

## Módulos instalados (Webmin)
- virtual-server: OK
- webminlog: OK
- system-status: OK
- fail2ban: OK
- dovecot: OK
- postfix: OK
- apache: OK
- bind8: OK
- bind9: NO ENCONTRADO
- mysql: OK
- postgresql: OK

## Pruebas HTTP/HTTPS (sin autenticación)
### Webmin raíz
URL: https://127.0.0.1:10000/
HTTP: 200
HEAD: HTTP/1.0 200 Document follows

### Webmin Sysinfo
URL: https://127.0.0.1:10000/sysinfo.cgi
HTTP: 200
HEAD: HTTP/1.0 200 Document follows

### Virtualmin módulo
URL: https://127.0.0.1:10000/virtual-server/
HTTP: 200
HEAD: HTTP/1.0 200 Document follows

### Virtualmin index
URL: https://127.0.0.1:10000/virtual-server/index.cgi
HTTP: 200
HEAD: HTTP/1.0 200 Document follows

### Usermin raíz
URL: https://127.0.0.1:20000/
HTTP: 200
HEAD: HTTP/1.0 200 Document follows

### Apache HTTP
URL: http://127.0.0.1/
HTTP: 200
HEAD: HTTP/1.1 200 OK

### Apache HTTPS
URL: https://127.0.0.1/
HTTP: 000ERR
HEAD: FALLO

## Sockets activos
udp   UNCONN 0      0            0.0.0.0:10000      0.0.0.0:*    users:(("miniserv.pl",pid=53809,fd=6)) ino:285826 sk:108b cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/webmin.service <->                                                                              
udp   UNCONN 0      0            0.0.0.0:20000      0.0.0.0:*    users:(("miniserv.pl",pid=53834,fd=6)) ino:284072 sk:108c cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/usermin.service <->                                                                             
tcp   LISTEN 0      511          0.0.0.0:443        0.0.0.0:*    users:(("apache2",pid=55196,fd=5),("apache2",pid=55195,fd=5),("apache2",pid=55194,fd=5),("apache2",pid=52416,fd=5)) ino:280701 sk:4051 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/apache2.service <->
tcp   LISTEN 0      511          0.0.0.0:80         0.0.0.0:*    users:(("apache2",pid=55196,fd=4),("apache2",pid=55195,fd=4),("apache2",pid=55194,fd=4),("apache2",pid=52416,fd=4)) ino:280699 sk:4054 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/apache2.service <->
tcp   LISTEN 0      4096       127.0.0.1:10000      0.0.0.0:*    users:(("miniserv.pl",pid=53809,fd=5)) ino:285825 sk:5001 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/webmin.service <->                                                                              
tcp   LISTEN 0      4096       127.0.0.1:20000      0.0.0.0:*    users:(("miniserv.pl",pid=53834,fd=5)) ino:284071 sk:5002 cgroup:/docker/dcf62950f2cb7e1a1485a4099ca3f1a0eff248a1a42c97771ab2f1381bb19620/system.slice/usermin.service <->                                                                             
