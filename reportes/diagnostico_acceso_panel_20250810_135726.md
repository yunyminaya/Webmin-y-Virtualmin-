# Diagnóstico de acceso a Webmin/Virtualmin
Fecha: domingo, 10 de agosto de 2025, 13:57:26 EDT

## Estado en HOST
Contenedor:
NAMES                STATUS          PORTS
debian12-virt-test   Up 26 minutes   

Puertos publicados (docker port):

IP del contenedor:
172.17.0.4 

Prueba curl al host https://localhost:10000

## Estado dentro del contenedor
- webmin activo?
active

- sockets escuchando (10000/20000/80/443):
LISTEN 0      4096         0.0.0.0:20000      0.0.0.0:*    users:(("miniserv.pl",pid=46419,fd=5))                                                                             
LISTEN 0      4096         0.0.0.0:10000      0.0.0.0:*    users:(("perl",pid=46484,fd=5))                                                                                    
LISTEN 0      511          0.0.0.0:443        0.0.0.0:*    users:(("apache2",pid=52424,fd=5),("apache2",pid=52423,fd=5),("apache2",pid=52422,fd=5),("apache2",pid=52416,fd=5))
LISTEN 0      511          0.0.0.0:80         0.0.0.0:*    users:(("apache2",pid=52424,fd=4),("apache2",pid=52423,fd=4),("apache2",pid=52422,fd=4),("apache2",pid=52416,fd=4))

- miniserv.conf bind:
bind=0.0.0.0

- hostname -f:
panel.example.com

- UFW status:

- IPs de interfaces:
11: eth0    inet 172.17.0.4/16 brd 172.17.255.255 scope global eth0\       valid_lft forever preferred_lft forever

- curl local a https://127.0.0.1:10000:
HTTP/1.0 200 Document follows

- últimos logs de Webmin (miniserv.error):
[10/Aug/2025:17:35:39 +0000] IPv6 support enabled
[10/Aug/2025:17:35:39 +0000] Using MD5 module Digest::MD5
[10/Aug/2025:17:35:39 +0000] Using SHA512 module Crypt::SHA
[10/Aug/2025:17:35:39 +0000] PAM authentication enabled
[10/Aug/2025:17:49:56 +0000] Reloading configuration
[10/Aug/2025:17:49:57 +0000] Restarting
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
