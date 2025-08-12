# Cierre de exposición pública Webmin/Usermin
Fecha: domingo, 10 de agosto de 2025, 14:07:37 EDT

1) Eliminando contenedor proxy (webmin-proxy)
Error response from daemon: No such container: webmin-proxy

2) Reconfigurando bind a 127.0.0.1 dentro del contenedor

Escuchando actualmente:
LISTEN 0      4096       127.0.0.1:10000      0.0.0.0:*    users:(("miniserv.pl",pid=53809,fd=5))                                                                             
LISTEN 0      4096       127.0.0.1:20000      0.0.0.0:*    users:(("miniserv.pl",pid=53834,fd=5))                                                                             

3) Estado de contenedores
NAMES                STATUS          PORTS
debian12-virt-test   Up 36 minutes   

4) Prueba acceso directo desde host (debe fallar):

5) Acceso recomendado vía túnel SSH:
ssh -N -L 10000:127.0.0.1:10000 usuario@SERVIDOR
