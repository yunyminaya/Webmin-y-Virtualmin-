# 🔍 Verificación Profunda Webmin/Virtualmin
Fecha: lunes, 11 de agosto de 2025, 11:39:34 EDT
Host: Localhot.local

Este informe realiza validaciones profundas de:
- Núcleo Webmin y configuración SSL/Miniserv
- Núcleo Virtualmin y características
- Servicios HTTP/HTTPS, PHP
- Pila de correo (Postfix, Dovecot, DKIM, SPF)
- Seguridad (UFW/Fail2ban)
- Bases de datos (MySQL/MariaDB y PostgreSQL)
- DNS (Bind9/named)
- Usermin

## Webmin - Núcleo y configuración

- Servicio Webmin: INACTIVO
- Puerto 10000 en escucha: NO
- ssl=1: 0
- bind: desconocido
- no_tls1=1: 0
- no_tls1_1=1: 0
- Certificado SSL: AUSENTE
- Versión Webmin: (desconocida)
- Módulo filemin: NO
- Módulo cron: NO
- Módulo useradmin: NO
- Módulo software: NO
- Módulo init: NO
- Módulo mount: NO
- Módulo quota: NO
- Módulo disk: NO
- Módulo system: NO
- Módulo package-updates: NO
- Módulo logrotate: NO
- Módulo proc: NO

---


## Webmin - Enumeración de módulos

- Directorio /usr/share/webmin: NO ENCONTRADO

---


## Virtualmin - Núcleo y características

- Comando virtualmin: NO DISPONIBLE
- Módulo virtual-server: AUSENTE

---


## Virtualmin - Archivos del módulo

- Módulo virtual-server no encontrado

---


## HTTP/HTTPS - Apache/Nginx y PHP

- Apache2: INACTIVO
- Nginx: INACTIVO
- PHP: PRESENTE

Comando: `php
-v`
```

PHP 8.2.28 (cli) (built: Mar 11 2025 17:58:12) (NTS)
Copyright (c) The PHP Group
Zend Engine v4.2.28, Copyright (c) Zend Technologies
    with Zend OPcache v8.2.28, Copyright (c), by Zend Technologies

```


---


## Correo - Postfix, Dovecot, DKIM, SPF

- Postfix: INACTIVO
- Dovecot: INACTIVO (si no se usa IMAP/POP3 es opcional)
- OpenDKIM: INACTIVO
- Puertos SMTP(25,465,587) y IMAPS(993):

Comando: `bash
-lc
os="$(uname -s 2>/dev/null || echo Unknown)"; if [ "$os" = "Darwin" ]; then netstat -anv | egrep "\.(25|465|587|993)\b.*LISTEN" || true; else netstat -tln 2>/dev/null | egrep ":(25|465|587|993)\b" || true; fi`
```


```


---


## Seguridad - UFW/Fail2ban

- UFW: NO DETECTADO
- Fail2ban: INACTIVO

---


## Bases de datos - MySQL/MariaDB y PostgreSQL

- MySQL/MariaDB: INACTIVO
- PostgreSQL: INACTIVO (opcional)

---


## DNS - Bind9/named

- DNS (bind9/named): INACTIVO (opcional si no gestiona DNS)
- Puertos DNS (53/tcp, 53/udp):

Comando: `bash
-lc
os="$(uname -s 2>/dev/null || echo Unknown)"; if [ "$os" = "Darwin" ]; then netstat -anv | egrep "\.53\b.*(LISTEN|UDP)" || true; else netstat -lntu 2>/dev/null | egrep "(:53\b)" || true; fi`
```


```


---


## Usermin

- Config Usermin: AUSENTE
- Servicio Usermin: INACTIVO
- Puerto 20000 en escucha: NO

---


## Sondas de acceso Webmin

- HTTP Headers (HTTPS 10000):

Comando: `bash
-lc
curl -k -sS -D - --max-time 5 https://127.0.0.1:10000/ -o /dev/null || true`
```

curl: (7) Failed to connect to 127.0.0.1 port 10000 after 0 ms: Couldn't connect to server

```

