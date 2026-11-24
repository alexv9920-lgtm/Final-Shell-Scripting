# Historial de versiones

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/) y [versionado semantico](https://semver.org/lang/es/).

## [1.0.0] - 2026-11
### Agregado
- `lib/comun.sh`: libreria compartida (logs con niveles, trap de errores, modo depuracion, validaciones, lectura segura de configuracion, bloqueo por usuario).
- `monitor_servidor.sh` v2.0.0 (Alex): monitoreo de CPU, memoria, discos, servicios y deteccion de eventos criticos en logs (fuerza bruta SSH, errores de sudo, errores graves). Reemplaza a `reporte.sh` y `analisis.sh` del parcial.
- `gestion_usuarios.sh` (Bryan): alta masiva de usuarios por roles desde CSV sin contrasenas, respaldo de cuentas, manifiesto y rollback.
- `despliegue_servicio.sh` (Dengelo): instalacion remota de nginx/apache2 por SSH/SCP con verificacion SHA-256, respaldo y rollback automatico.
- Pruebas automaticas (`tests/run_tests.sh`) y CI con GitHub Actions (bash -n + ShellCheck + pruebas).

### Mejoras respecto al parcial
- Rutas y umbrales en archivos `.conf` en lugar de valores fijos en el codigo.
- Manejo de errores con `set -Eeuo pipefail` y `trap ERR`.
- Codigos de salida estandar para integrarse con cron y CI.
- Lectura incremental de logs (solo lineas nuevas, detecta rotacion).

### Corregido durante las pruebas
- El bloqueo `/tmp/*.lock` creado por root impedia ejecutar los scripts con otro usuario: ahora hay un bloqueo por usuario.
- Un fallo controlado del instalador remoto disparaba el `trap ERR` local: se captura el codigo con `|| RC=$?`.
- El rollback manual repetido elegia un despliegue ya revertido: ahora se excluyen los revertidos.
