Nuevas Funciones Integradas (Resumen Ejecutivo)

- Revendedores (GPL emulado)
  - CLI `virtualmin-revendedor` para crear/listar/limitar/eliminar admins bajo un dominio paraguas.
  - Módulo Webmin `revendedor-gpl` con interfaz mínima.
  - Archivos: cuentas_revendedor.sh, webmin-revendedor/index.cgi, webmin-revendedor/module.info, webmin-revendedor/config, virtualmin-revendedor

- Validación de repositorio oficial
  - Servicio + timer que validan origen de updates y bloquean no autorizados.
  - Archivos: webmin-repo-validation.sh, webmin-repo-validation.service, webmin-repo-validation.timer

- Auto‑reparación y endurecimiento
  - Mejora: integra `virtualmin check-config` e intentos de recuperación (reinicios selectivos).
  - Archivo: webmin-self-healing-enhanced.sh

- Optimización de rendimiento
  - Servicio one‑shot para ajuste de Apache/PHP/MySQL y métrica básica.
  - Archivos: webmin-performance-optimizer.sh, webmin-performance-optimizer.service

- Backups de alta escala + remotos (opcional)
  - Programación diaria/semanal con límites de concurrencia, pigz y S3 optimizado.
  - Integrado desde instalacion_un_comando.sh (ajustes en Virtualmin y remotos opcionales).

Instalación/Despliegue (clave)

- Ejecutar instalador general: `sudo bash instalacion_un_comando.sh`
  - Instala `virtualmin-revendedor` en `/usr/local/bin/` y módulo Webmin `revendedor-gpl`.
  - Copia y habilita servicios: webmin-self-healing, webmin-repo-validation(.service + .timer), webmin-performance-optimizer, webmin-tunnel-system.
  - Ajusta backups y performance en Virtualmin.

Uso rápido

- Crear revendedor (GPL emulado):
  - `sudo /usr/local/bin/virtualmin-revendedor crear --usuario rev1 --pass 'Secreto123' --dominio-base rev1-panel.ejemplo.com --email soporte@ejemplo.com --max-doms 50`
- Listar admins del dominio base:
  - `sudo /usr/local/bin/virtualmin-revendedor listar --dominio-base rev1-panel.ejemplo.com`
- Acceso en Webmin: `/revendedor-gpl/` (UI mínima).

Verificación

- Post‑instalación: `verificar_instalacion_un_comando.sh` verifica servicios, puertos, Webmin/Virtualmin, LAMP, correo, SSL y recursos.
- Repositorios: revisar `/var/log/webmin-repo-validation.log` para estado de validaciones/bloqueos.

Notas

- Virtualmin Pro ofrece “Resellers” nativos con mayor alcance; aquí se emula en GPL bajo un dominio base.
- En producción Linux (Ubuntu/Debian). En macOS solo desarrollo/pruebas.
