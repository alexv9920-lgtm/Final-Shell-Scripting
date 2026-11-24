# Scripting de shell final

![CI](https://github.com/alexv9920-lgtm/Final-Shell-Scripting/actions/workflows/ci.yml/badge.svg)

Proyecto final del curso **Shell Scripting (IDAT)**: un conjunto de scripts en Bash que automatiza tareas críticas del área de TI con validaciones, manejo de errores, registros (logs), reportes, respaldo/rollback e integración continua.

| Integrante | Carpeta | Script | Caso que resuelve |
|---|---|---|---|
| Alex Yarlequé | `Alex Yarlequé/` | `monitor_servidor.sh` | **Monitoreo de logs con detección de eventos críticos** y de recursos (CPU, memoria, discos, servicios) |
| Bryan Alvares | `Bryan Alvares/` | `gestion_usuarios.sh` | **Gestión de usuarios y permisos basada en roles**, sin contraseñas en archivos |
| Dengelo Rojas | `Dengelo Rojas/` | `despliegue_servicio.sh` | **Instalación remota de un servicio por SSH/SCP** con respaldo y rollback automático |

## Estructura

```
Final-Shell-Scripting/
├── lib/comun.sh                 # Librería compartida (logs, errores, validaciones)
├── Alex Yarlequé/               # Monitoreo
├── Bryan Alvares/               # Usuarios y roles
├── Dengelo Rojas/               # Despliegue remoto
│   └── remoto/                  # Script que se ejecuta en el servidor destino
├── tests/run_tests.sh           # Pruebas automáticas
├── .github/workflows/ci.yml     # CI: bash -n + ShellCheck + pruebas
└── CHANGELOG.md                 # Historial de versiones
```

## Requisitos

- Linux con Bash 4+ (probado en Ubuntu 24.04; compatible con Debian/CentOS).
- `awk`, `sed`, `grep`, `tar`, `cron`, `ssh`, `scp`, `curl` (incluidos en la mayoría de distribuciones).
- Para `gestion_usuarios.sh`: permisos de `sudo`.
- Para `despliegue_servicio.sh`: un servidor destino con acceso SSH por llave.

## Inicio rápido

```bash
git clone https://github.com/alexv9920-lgtm/Final-Shell-Scripting.git
cd Final-Shell-Scripting
chmod +x */*.sh tests/*.sh "Dengelo Rojas/remoto/"*.sh

./"Alex Yarlequé"/monitor_servidor.sh -h
sudo ./"Bryan Alvares"/gestion_usuarios.sh -h
./"Dengelo Rojas"/despliegue_servicio.sh -h

bash tests/run_tests.sh          # ejecuta todas las pruebas
```

Cada carpeta tiene su propio `README.md` con la guía de ejecución y ejemplos.

## Buenas prácticas aplicadas

| Práctica | Cómo se aplica |
|---|---|
| Modo estricto | `set -Eeuo pipefail` + `trap ERR`, que indica la línea y el comando que falló |
| Depuración | `DEBUG=1 ./script.sh` activa `set -x` con archivo y número de línea |
| Configuración externa | Archivos `.conf` leídos **sin ejecutarlos** (evita inyección de comandos) |
| Validaciones | Parámetros, rangos, archivos, permisos, dependencias y root |
| Logs | Niveles INFO / OK / WARN / ERROR / DEBUG con fecha y nombre del script |
| Códigos de salida | Estándar en todo el proyecto (tabla abajo), útiles para cron y CI |
| Seguridad | Contraseñas nunca en archivos ni en la línea de comandos; SSH por llave; archivos sensibles con permiso 600 |
| Respaldo y rollback | Antes de cada cambio se respalda; ante un fallo se restaura |
| Concurrencia | Bloqueo con `flock` para evitar dos ejecuciones a la vez |
| Calidad | ShellCheck sin advertencias y pruebas automáticas en GitHub Actions |

## Códigos de salida

| Código | Significado |
|---|---|
| 0 | Ejecución correcta |
| 1 | Alerta o errores parciales |
| 2 | Uso incorrecto (parámetros) |
| 3 | Falta una dependencia |
| 4 | Permisos insuficientes |
| 5 | Archivo inexistente o inválido |
| 6 | Ya hay otra ejecución en curso |
| 7 | Error de conexión |
| 8 | Se aplicó rollback |

## Flujo de trabajo con Git

- Rama `main` protegida: los cambios entran por **Pull Request**.
- Una rama por integrante: `feature/monitoreo`, `feature/usuarios`, `feature/despliegue`.
- Commits con la convención [Conventional Commits](https://www.conventionalcommits.org/es/): `feat:`, `fix:`, `docs:`, `test:`, `ci:`, `refactor:`.
- Versiones con etiquetas: `v1.0.0`.
