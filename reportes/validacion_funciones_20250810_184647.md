# Validación integral de funciones
Fecha: Sun Aug 10 18:46:47 UTC 2025

## Revisión rápida de estado
- Webmin: OK
- Apache: OK
- MySQL/MariaDB: OK
- Postfix: OK
- Dovecot: OK
- OpenDKIM: OK
- SpamAssassin: OK
- ClamAV Daemon: OK
- Fail2ban: OK

## Virtualmin check-config (resumen)
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


## Ejecución de verificadores del repositorio

### verificador_servicios.sh
+ RED='\033[0;31m'
+ GREEN='\033[0;32m'
+ YELLOW='\033[1;33m'
+ BLUE='\033[0;34m'
+ NC='\033[0m'
+ echo -e '\033[0;34m=== VERIFICADOR DE SERVICIOS WEBMIN/VIRTUALMIN ===\033[0m'
[0;34m=== VERIFICADOR DE SERVICIOS WEBMIN/VIRTUALMIN ===[0m
++ date
+ echo 'Fecha: Sun Aug 10 18:47:07 UTC 2025'
Fecha: Sun Aug 10 18:47:07 UTC 2025
++ uname -s
++ uname -r
+ echo 'Sistema: Linux 6.10.14-linuxkit'
Sistema: Linux 6.10.14-linuxkit
++ hostname
+ echo 'Hostname: panel.example.com'
Hostname: panel.example.com
+ echo ''

+ echo -e '\033[0;34m=== VERIFICACIÓN DE COMANDOS PRINCIPALES ===\033[0m'
[0;34m=== VERIFICACIÓN DE COMANDOS PRINCIPALES ===[0m
+ check_command webmin Webmin
+ local cmd=webmin
+ local display_name=Webmin
+ echo -n 'Verificando Webmin... '
Verificando Webmin... + command -v webmin
+ echo -e '\033[0;32mDISPONIBLE\033[0m'
[0;32mDISPONIBLE[0m
+ local version
+ case "$cmd" in
++ grep version= /etc/webmin/version
++ cut -d= -f2
+ version=
+ echo '  └─ Versión: '
  └─ Versión: 
+ return 0
+ check_command virtualmin Virtualmin
+ local cmd=virtualmin
+ local display_name=Virtualmin
+ echo -n 'Verificando Virtualmin... '
Verificando Virtualmin... + command -v virtualmin
+ echo -e '\033[0;32mDISPONIBLE\033[0m'
[0;32mDISPONIBLE[0m
+ local version
+ case "$cmd" in
++ virtualmin version
++ head -1
+ version='Command version.pl was not found'
+ echo '  └─ Versión: Command version.pl was not found'
  └─ Versión: Command version.pl was not found
+ return 0
+ check_command apache2 'Apache Web Server'
+ local cmd=apache2
+ local 'display_name=Apache Web Server'
+ echo -n 'Verificando Apache Web Server... '
Verificando Apache Web Server... + command -v apache2
+ echo -e '\033[0;32mDISPONIBLE\033[0m'
[0;32mDISPONIBLE[0m
+ local version
+ case "$cmd" in
++ apache2 -v
++ head -1
+ version='Server version: Apache/2.4.62 (Debian)'
+ echo '  └─ Server version: Apache/2.4.62 (Debian)'
  └─ Server version: Apache/2.4.62 (Debian)
+ return 0
+ check_command nginx 'Nginx Web Server'
+ local cmd=nginx
+ local 'display_name=Nginx Web Server'
+ echo -n 'Verificando Nginx Web Server... '
Verificando Nginx Web Server... + command -v nginx
+ echo -e '\033[0;31mNO DISPONIBLE\033[0m'
[0;31mNO DISPONIBLE[0m
+ return 1
+ check_command mysql 'MySQL Database'
+ local cmd=mysql
+ local 'display_name=MySQL Database'
+ echo -n 'Verificando MySQL Database... '
Verificando MySQL Database... + command -v mysql
+ echo -e '\033[0;32mDISPONIBLE\033[0m'
[0;32mDISPONIBLE[0m
+ local version
+ case "$cmd" in
++ mysql --version
+ version='mysql  Ver 15.1 Distrib 10.11.11-MariaDB, for debian-linux-gnu (aarch64) using  EditLine wrapper'
+ echo '  └─ mysql  Ver 15.1 Distrib 10.11.11-MariaDB, for debian-linux-gnu (aarch64) using  EditLine wrapper'
  └─ mysql  Ver 15.1 Distrib 10.11.11-MariaDB, for debian-linux-gnu (aarch64) using  EditLine wrapper
+ return 0
+ check_command postgresql 'PostgreSQL Database'
+ local cmd=postgresql
+ local 'display_name=PostgreSQL Database'
+ echo -n 'Verificando PostgreSQL Database... '
Verificando PostgreSQL Database... + command -v postgresql
+ echo -e '\033[0;31mNO DISPONIBLE\033[0m'
[0;31mNO DISPONIBLE[0m
+ return 1
+ check_command postfix 'Postfix Mail Server'
+ local cmd=postfix
+ local 'display_name=Postfix Mail Server'
+ echo -n 'Verificando Postfix Mail Server... '
Verificando Postfix Mail Server... + command -v postfix
+ echo -e '\033[0;32mDISPONIBLE\033[0m'
[0;32mDISPONIBLE[0m
+ local version
+ case "$cmd" in
+ return 0
+ check_command dovecot 'Dovecot IMAP/POP3'
+ local cmd=dovecot
+ local 'display_name=Dovecot IMAP/POP3'
+ echo -n 'Verificando Dovecot IMAP/POP3... '
Verificando Dovecot IMAP/POP3... + command -v dovecot
+ echo -e '\033[0;32mDISPONIBLE\033[0m'
[0;32mDISPONIBLE[0m
+ local version
+ case "$cmd" in
+ return 0
+ check_command named 'BIND DNS Server'
+ local cmd=named
+ local 'display_name=BIND DNS Server'
+ echo -n 'Verificando BIND DNS Server... '
Verificando BIND DNS Server... + command -v named
+ echo -e '\033[0;32mDISPONIBLE\033[0m'
[0;32mDISPONIBLE[0m
+ local version
+ case "$cmd" in
+ return 0
+ echo ''

+ echo -e '\033[0;34m=== VERIFICACIÓN DE SERVICIOS ===\033[0m'
[0;34m=== VERIFICACIÓN DE SERVICIOS ===[0m
+ services=("webmin:Webmin:10000" "apache2:Apache Web Server:80" "nginx:Nginx Web Server:80" "mysql:MySQL Database:3306" "postgresql:PostgreSQL Database:5432" "postfix:Postfix Mail:25" "dovecot:Dovecot IMAP/POP3:993" "named:BIND DNS:53" "bind9:BIND9 DNS:53" "ssh:SSH Server:22" "fail2ban:Fail2Ban:" "ufw:Firewall UFW:" "cron:Cron Scheduler:" "rsyslog:System Logging:")
+ active_services=0
+ total_services=0
+ for service_info in "${services[@]}"
+ IFS=:
+ read -r service display port
+ total_services=1
+ check_service webmin Webmin 10000
+ local service_name=webmin
+ local display_name=Webmin
+ local port=10000
+ echo -n 'Verificando Webmin... '
Verificando Webmin... + systemctl list-unit-files
+ grep -q '^webmin\.service'
+ systemctl is-active --quiet webmin
+ echo -e '\033[0;32mACTIVO\033[0m'
[0;32mACTIVO[0m
+ [[ -n 10000 ]]
+ netstat -tuln
+ grep -q ':10000 '
+ echo '  └─ Puerto 10000: \033[0;32mABIERTO\033[0m'
  └─ Puerto 10000: \033[0;32mABIERTO\033[0m
++ journalctl -u webmin --since '1 hour ago' --priority=err --no-pager -q
++ wc -l
+ local errors=4
+ [[ 4 -gt 0 ]]
+ echo '  └─ Errores recientes: \033[0;31m4\033[0m'
  └─ Errores recientes: \033[0;31m4\033[0m
+ return 0
+ active_services=1
+ for service_info in "${services[@]}"
+ IFS=:
+ read -r service display port
+ total_services=2
+ check_service apache2 'Apache Web Server' 80
+ local service_name=apache2
+ local 'display_name=Apache Web Server'
+ local port=80
+ echo -n 'Verificando Apache Web Server... '
Verificando Apache Web Server... + systemctl list-unit-files
+ grep -q '^apache2\.service'
+ systemctl is-active --quiet apache2
+ echo -e '\033[0;32mACTIVO\033[0m'
[0;32mACTIVO[0m
+ [[ -n 80 ]]
+ netstat -tuln
+ grep -q ':80 '
+ echo '  └─ Puerto 80: \033[0;32mABIERTO\033[0m'
  └─ Puerto 80: \033[0;32mABIERTO\033[0m
++ journalctl -u apache2 --since '1 hour ago' --priority=err --no-pager -q
++ wc -l
+ local errors=0
+ [[ 0 -gt 0 ]]
+ echo '  └─ Sin errores recientes: \033[0;32mOK\033[0m'
  └─ Sin errores recientes: \033[0;32mOK\033[0m
+ return 0
+ active_services=2
+ for service_info in "${services[@]}"
+ IFS=:
+ read -r service display port
+ total_services=3
+ check_service nginx 'Nginx Web Server' 80
+ local service_name=nginx
+ local 'display_name=Nginx Web Server'
+ local port=80
+ echo -n 'Verificando Nginx Web Server... '
Verificando Nginx Web Server... + systemctl list-unit-files
+ grep -q '^nginx\.service'
+ echo -e '\033[1;33mNO INSTALADO\033[0m'
[1;33mNO INSTALADO[0m

### verificar_seguridad_completa.sh
+ set -euo pipefail
+ IFS='
	'
+ trap 'echo "[ERROR] verificar_seguridad_completa.sh fallo en línea $LINENO"; exit 1' ERR
+ RED='\033[0;31m'
+ GREEN='\033[0;32m'
+ YELLOW='\033[1;33m'
+ BLUE='\033[0;34m'
+ PURPLE='\033[0;35m'
+ CYAN='\033[0;36m'
+ WHITE='\033[1;37m'
+ NC='\033[0m'
++ date +%Y%m%d_%H%M%S
+ TIMESTAMP=20250810_184711
+ LOG_FILE=seguridad_webmin_virtualmin_20250810_184711.log
+ REPORT_FILE=reporte_seguridad_20250810_184711.md
+++ dirname verificar_seguridad_completa.sh
++ cd .
++ pwd
+ BASE_DIR=/workspace
+ REPORT_DIR=/workspace/reportes
+ OS_TYPE=
+ TOTAL_CHECKS=0
+ PASSED_CHECKS=0
+ WARNING_CHECKS=0
+ FAILED_CHECKS=0
+ main
+ TOTAL_CHECKS=0
+ PASSED_CHECKS=0
+ FAILED_CHECKS=0
+ WARNING_CHECKS=0
+ '[' '!' -d /workspace/reportes ']'
++ date +%Y%m%d_%H%M%S
+ REPORT_FILE=/workspace/reportes/reporte_seguridad_20250810_184711.md
+ echo '# Reporte de Seguridad de Webmin/Virtualmin'
++ date
+ echo 'Fecha: Sun Aug 10 18:47:11 UTC 2025'
+ echo ''
+ detect_os
+ log INFO 'Detectando sistema operativo...'
+ local level=INFO
+ local 'message=Detectando sistema operativo...'
++ date '+%Y-%m-%d %H:%M:%S'
+ local 'timestamp=2025-08-10 18:47:11'
+ echo '[2025-08-10 18:47:11] [INFO] Detectando sistema operativo...'
+ case $level in
+ echo -e '\033[0;34m[INFO]\033[0m Detectando sistema operativo...'
[0;34m[INFO][0m Detectando sistema operativo...
+ '[' -f /etc/os-release ']'
+ . /etc/os-release
++ PRETTY_NAME='Debian GNU/Linux 12 (bookworm)'
++ NAME='Debian GNU/Linux'
++ VERSION_ID=12
++ VERSION='12 (bookworm)'
++ VERSION_CODENAME=bookworm
++ ID=debian
++ HOME_URL=https://www.debian.org/
++ SUPPORT_URL=https://www.debian.org/support
++ BUG_REPORT_URL=https://bugs.debian.org/
+ OS_TYPE=debian
+ log INFO 'Sistema operativo detectado: debian 12'
+ local level=INFO
+ local 'message=Sistema operativo detectado: debian 12'
++ date '+%Y-%m-%d %H:%M:%S'
+ local 'timestamp=2025-08-10 18:47:11'
+ echo '[2025-08-10 18:47:11] [INFO] Sistema operativo detectado: debian 12'
+ case $level in
+ echo -e '\033[0;34m[INFO]\033[0m Sistema operativo detectado: debian 12'
[0;34m[INFO][0m Sistema operativo detectado: debian 12
+ echo '## Sistema Operativo'
+ echo '- **Tipo**: debian'
++ date
+ echo '- **Fecha de verificación**: Sun Aug 10 18:47:11 UTC 2025'
+ echo ''
+ check_open_ports
+ log INFO 'Verificando puertos abiertos...'
+ local level=INFO
+ local 'message=Verificando puertos abiertos...'
++ date '+%Y-%m-%d %H:%M:%S'
+ local 'timestamp=2025-08-10 18:47:11'
+ echo '[2025-08-10 18:47:11] [INFO] Verificando puertos abiertos...'
+ case $level in
+ echo -e '\033[0;34m[INFO]\033[0m Verificando puertos abiertos...'
[0;34m[INFO][0m Verificando puertos abiertos...
+ TOTAL_CHECKS=1
+ echo '## Puertos Abiertos'
+ command_exists netstat
+ command -v netstat
+ log INFO 'Usando netstat para verificar puertos'
+ local level=INFO
+ local 'message=Usando netstat para verificar puertos'
++ date '+%Y-%m-%d %H:%M:%S'
+ local 'timestamp=2025-08-10 18:47:11'
+ echo '[2025-08-10 18:47:11] [INFO] Usando netstat para verificar puertos'
+ case $level in
+ echo -e '\033[0;34m[INFO]\033[0m Usando netstat para verificar puertos'
[0;34m[INFO][0m Usando netstat para verificar puertos
++ netstat -tuln
++ grep LISTEN
+ LISTENING_PORTS='tcp        0      0 127.0.0.1:6379          0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:995             0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:993             0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:587             0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:443             0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:465             0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:143             0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:25              0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:110             0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN     
tcp        0      0 172.17.0.4:53           0.0.0.0:*               LISTEN     
tcp        0      0 172.17.0.4:53           0.0.0.0:*               LISTEN     
tcp        0      0 172.17.0.4:53           0.0.0.0:*               LISTEN     
tcp        0      0 172.17.0.4:53           0.0.0.0:*               LISTEN     
tcp        0      0 172.17.0.4:53           0.0.0.0:*               LISTEN     
tcp        0      0 172.17.0.4:53           0.0.0.0:*               LISTEN     
tcp        0      0 172.17.0.4:53           0.0.0.0:*               LISTEN     
tcp        0      0 172.17.0.4:53           0.0.0.0:*               LISTEN     
tcp        0      0 172.17.0.4:53           0.0.0.0:*               LISTEN     
tcp        0      0 172.17.0.4:53           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:8891          0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:953           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:953           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:953           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:953           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:953           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:953           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:953           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:953           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:953           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:953           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:783           0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:10000         0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:11000         0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:11211         0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:3306          0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:20000         0.0.0.0:*               LISTEN     
tcp6       0      0 :::2222                 :::*                    LISTEN     
tcp6       0      0 ::1:953                 :::*                    LISTEN     
tcp6       0      0 ::1:953                 :::*                    LISTEN     
tcp6       0      0 ::1:953                 :::*                    LISTEN     
tcp6       0      0 ::1:953                 :::*                    LISTEN     
tcp6       0      0 ::1:953                 :::*                    LISTEN     
tcp6       0      0 ::1:953                 :::*                    LISTEN     
tcp6       0      0 ::1:953                 :::*                    LISTEN     
tcp6       0      0 ::1:953                 :::*                    LISTEN     
tcp6       0      0 ::1:953                 :::*                    LISTEN     
tcp6       0      0 ::1:953                 :::*                    LISTEN     
tcp6       0      0 ::1:53                  :::*                    LISTEN     
tcp6       0      0 ::1:53                  :::*                    LISTEN     
tcp6       0      0 ::1:53                  :::*                    LISTEN     
tcp6       0      0 ::1:53                  :::*                    LISTEN     
tcp6       0      0 ::1:53                  :::*                    LISTEN     
tcp6       0      0 ::1:53                  :::*                    LISTEN     
tcp6       0      0 ::1:53                  :::*                    LISTEN     
tcp6       0      0 ::1:53                  :::*                    LISTEN     
tcp6       0      0 ::1:53                  :::*                    LISTEN     
tcp6       0      0 ::1:53                  :::*                    LISTEN     
tcp6       0      0 :::995                  :::*                    LISTEN     
tcp6       0      0 :::993                  :::*                    LISTEN     
tcp6       0      0 :::587                  :::*                    LISTEN     
tcp6       0      0 :::465                  :::*                    LISTEN     
tcp6       0      0 :::143                  :::*                    LISTEN     
tcp6       0      0 :::21                   :::*                    LISTEN     
tcp6       0      0 :::25                   :::*                    LISTEN     
tcp6       0      0 :::110                  :::*                    LISTEN     
tcp6       0      0 ::1:6379                :::*                    LISTEN     '
++ grep -E ':10000 '
++ echo 'tcp        0      0 127.0.0.1:6379          0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:995             0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:993             0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:587             0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:443             0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:465             0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:143             0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:25              0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:110             0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN     
tcp        0      0 127.0.0.1:53            0.0.0.0:*               LISTEN     
tcp        0      0 172.17.0.4:53           0.0.0.0:*               LISTEN     
tcp        0      0 172.17.0.4:53           0.0.0.0:*               LISTEN     
tcp        0      0 172.17.0.4:53           0.0.0.0:*               LISTEN     

### verificar_instalacion_un_comando.sh
+ set -euo pipefail
+ RED='\033[0;31m'
+ GREEN='\033[0;32m'
+ YELLOW='\033[1;33m'
+ BLUE='\033[0;34m'
+ PURPLE='\033[0;35m'
+ CYAN='\033[0;36m'
+ NC='\033[0m'
+ TESTS_PASSED=0
+ TESTS_FAILED=0
+ WARNINGS=0
+ main
+ show_banner
+ clear
TERM environment variable not set.

## Pruebas HTTP/HTTPS locales
- Webmin HTTPS:
HTTP/1.0 200 Document follows
- Apache HTTP:
HTTP/1.1 200 OK
- Roundcube:
HTTP/1.1 404 Not Found
