# Publicación de puertos mediante contenedor proxy (socat)
Fecha: domingo, 10 de agosto de 2025, 13:59:26 EDT

IP objetivo del contenedor debian12-virt-test: 172.17.0.4

Recreando proxy...
Proxy creado: webmin-proxy

Puertos publicados en HOST:
NAMES                STATUS                  PORTS
webmin-proxy         Up Less than a second   0.0.0.0:80->80/tcp, [::]:80->80/tcp, 0.0.0.0:443->443/tcp, [::]:443->443/tcp, 0.0.0.0:10000->10000/tcp, [::]:10000->10000/tcp, 0.0.0.0:20000->20000/tcp, [::]:20000->20000/tcp

Pruebas desde HOST:
curl -kI https://localhost:10000

curl -I http://localhost:80
