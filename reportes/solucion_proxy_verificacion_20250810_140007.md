# Verificación del proxy de puertos (socat)
Fecha: domingo, 10 de agosto de 2025, 14:00:07 EDT

## Estado de contenedores
NAMES                STATUS          PORTS
webmin-proxy         Up 36 seconds   0.0.0.0:80->80/tcp, [::]:80->80/tcp, 0.0.0.0:443->443/tcp, [::]:443->443/tcp, 0.0.0.0:10000->10000/tcp, [::]:10000->10000/tcp, 0.0.0.0:20000->20000/tcp, [::]:20000->20000/tcp
debian12-virt-test   Up 29 minutes   

## Logs recientes del proxy
sh: socat: not found
sh: socat: not found
sh: socat: not found
Proxying to 172.17.0.4
2025/08/10 17:59:33 socat[7] N listening on AF=10 [0000:0000:0000:0000:0000:0000:0000:0000]:10000

## Pruebas de conectividad desde el HOST
- Esperando 4s para que socat esté listo...

### nc -vz localhost 10000
Connection to localhost port 10000 [tcp/ndmp] succeeded!

### curl -vkI https://localhost:10000 (solo primeras líneas)
* Host localhost:10000 was resolved.
* IPv6: ::1
* IPv4: 127.0.0.1
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0*   Trying [::1]:10000...
* Connected to localhost (::1) port 10000
* ALPN: curl offers h2,http/1.1
* (304) (OUT), TLS handshake, Client hello (1):
} [314 bytes data]
* (304) (IN), TLS handshake, Server hello (2):
{ [122 bytes data]
* (304) (IN), TLS handshake, Unknown (8):
{ [10 bytes data]
* (304) (IN), TLS handshake, Certificate (11):
{ [934 bytes data]
* (304) (IN), TLS handshake, CERT verify (15):
{ [264 bytes data]
* (304) (IN), TLS handshake, Finished (20):
{ [52 bytes data]
* (304) (OUT), TLS handshake, Finished (20):
} [52 bytes data]
* SSL connection using TLSv1.3 / AEAD-AES256-GCM-SHA384 / [blank] / UNDEF
* ALPN: server did not agree on a protocol. Uses default.
* Server certificate:

### curl -vI http://localhost:80 (solo primeras líneas)
* Host localhost:80 was resolved.
* IPv6: ::1
* IPv4: 127.0.0.1
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0*   Trying [::1]:80...
* Connected to localhost (::1) port 80
> HEAD / HTTP/1.1
> Host: localhost
> User-Agent: curl/8.7.1
> Accept: */*
> 
* Request completely sent off
* Recv failure: Connection reset by peer
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
* Closing connection
curl: (56) Recv failure: Connection reset by peer
