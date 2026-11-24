#!/usr/bin/env bash
# ==============================================================================
# lib/comun.sh - Libreria comun del proyecto Final-Shell-Scripting
# ------------------------------------------------------------------------------
# Funciones reutilizadas por los 3 scripts del grupo:
#   - Registro de eventos (log) con niveles: INFO, OK, WARN, ERROR, DEBUG
#   - Manejo de errores con trap ERR (muestra linea y comando que fallo)
#   - Modo depuracion: DEBUG=1 ./script.sh  (activa set -x con numero de linea)
#   - Validaciones: root, comandos requeridos, archivos, numeros, rangos
#   - Lectura SEGURA de archivos de configuracion (no ejecuta codigo)
#   - Bloqueo para evitar dos ejecuciones simultaneas (flock)
#
# Uso dentro de un script:
#   source "$(dirname "$0")/../lib/comun.sh"
#
# Codigos de salida estandar del proyecto:
#   0 OK | 1 alerta/errores parciales | 2 uso incorrecto | 3 falta dependencia
#   4 sin permisos | 5 archivo invalido | 6 ejecucion en curso | 7 conexion
#   8 rollback aplicado
# ==============================================================================

# Evita cargar la libreria dos veces
if [[ -n "${_COMUN_CARGADA:-}" ]]; then return 0; fi
_COMUN_CARGADA=1

# shellcheck disable=SC2034  # constantes usadas por los scripts que cargan la libreria
readonly LIB_VERSION="1.0.0"
# shellcheck disable=SC2034
readonly E_OK=0 E_ALERTA=1 E_USO=2 E_DEPENDENCIA=3 E_PERMISOS=4 E_ARCHIVO=5 E_BLOQUEO=6 E_CONEXION=7 E_ROLLBACK=8

# ---------- Colores (solo si la salida es una terminal) ----------
if [[ -t 1 ]]; then
    C_ROJO=$'\e[1;31m'; C_VERDE=$'\e[1;32m'; C_AMARILLO=$'\e[1;33m'
    C_AZUL=$'\e[1;36m'; C_GRIS=$'\e[0;37m'; C_RESET=$'\e[0m'
else
    C_ROJO=""; C_VERDE=""; C_AMARILLO=""; C_AZUL=""; C_GRIS=""; C_RESET=""
fi

LOG_FILE="${LOG_FILE:-/dev/null}"     # cada script define su archivo de log
SILENCIOSO="${SILENCIOSO:-0}"         # 1 = no imprime en pantalla (modo cron)

# ---------- Registro de eventos ----------
# log NIVEL "mensaje"  -> escribe en LOG_FILE y muestra en pantalla
log() {
    local nivel=$1; shift
    local mensaje="$*" fecha color
    fecha=$(date '+%Y-%m-%d %H:%M:%S')
    if [[ "$nivel" == "DEBUG" && "${DEBUG:-0}" != "1" ]]; then return 0; fi
    printf '%s [%-5s] [%s] %s\n' "$fecha" "$nivel" "${SCRIPT_NOMBRE:-script}" "$mensaje" >> "$LOG_FILE" 2>/dev/null || true
    case "$nivel" in
        OK)    color=$C_VERDE ;;
        WARN)  color=$C_AMARILLO ;;
        ERROR) color=$C_ROJO ;;
        DEBUG) color=$C_GRIS ;;
        *)     color=$C_AZUL ;;
    esac
    if [[ "$nivel" == "ERROR" || "$nivel" == "WARN" ]]; then
        printf '%s[%s]%s %s\n' "$color" "$nivel" "$C_RESET" "$mensaje" >&2
    elif [[ "$SILENCIOSO" != "1" ]]; then
        printf '%s[%s]%s %s\n' "$color" "$nivel" "$C_RESET" "$mensaje"
    fi
}
info()  { log INFO "$*"; }
ok()    { log OK "$*"; }
warn()  { log WARN "$*"; }
error() { log ERROR "$*"; }
debug() { log DEBUG "$*"; }

# die "mensaje" [codigo]  -> registra el error y termina con el codigo indicado
die() {
    error "$1"
    exit "${2:-$E_ALERTA}"
}

# ---------- Manejo de errores y depuracion ----------
_al_fallar() {
    local codigo=$? linea=$1 comando=$2
    error "Fallo inesperado en la linea $linea (codigo $codigo): $comando"
}

# Activa modo estricto: -e (sale ante error), -u (variables sin definir),
# -o pipefail (falla si falla cualquier comando de un pipe), -E (hereda trap ERR)
habilitar_modo_estricto() {
    set -Eeuo pipefail
    trap '_al_fallar "$LINENO" "$BASH_COMMAND"' ERR
    if [[ "${DEBUG:-0}" == "1" ]]; then
        export PS4='+ [${BASH_SOURCE##*/}:${LINENO}] '
        set -x
    fi
}

# ---------- Validaciones reutilizables ----------
requiere_root() {
    if [[ $EUID -ne 0 ]]; then
        die "Esta accion requiere privilegios de administrador. Ejecuta con: sudo $0 $*" "$E_PERMISOS"
    fi
}

requiere_comandos() {
    local faltantes=() cmd
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || faltantes+=("$cmd")
    done
    if (( ${#faltantes[@]} > 0 )); then
        die "Faltan comandos requeridos: ${faltantes[*]}. Instalalos con: sudo apt install <paquete>" "$E_DEPENDENCIA"
    fi
}

archivo_legible() {
    [[ -e "$1" ]] || die "No existe el archivo: $1" "$E_ARCHIVO"
    [[ -f "$1" ]] || die "No es un archivo regular: $1" "$E_ARCHIVO"
    [[ -r "$1" ]] || die "Sin permiso de lectura sobre: $1" "$E_PERMISOS"
}

es_entero() { [[ "${1:-}" =~ ^[0-9]+$ ]]; }

en_rango() {   # en_rango valor minimo maximo
    es_entero "$1" && (( 10#$1 >= $2 && 10#$1 <= $3 ))
}

# Carga un archivo CLAVE=valor SIN ejecutarlo (evita inyeccion de comandos).
# Solo acepta claves en MAYUSCULAS; ignora comentarios y lineas vacias.
cargar_config() {
    local archivo=$1 clave valor n=0
    archivo_legible "$archivo"
    while IFS='=' read -r clave valor || [[ -n "$clave" ]]; do
        n=$((n + 1))
        clave="${clave//[[:space:]]/}"
        [[ -z "$clave" || "$clave" == \#* ]] && continue
        if [[ ! "$clave" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
            warn "Config $archivo linea $n ignorada (clave invalida): $clave"
            continue
        fi
        valor="${valor%%#*}"                       # quita comentario al final
        valor="${valor#"${valor%%[![:space:]]*}"}" # quita espacios iniciales
        valor="${valor%"${valor##*[![:space:]]}"}" # quita espacios finales
        valor="${valor%\"}"; valor="${valor#\"}"   # quita comillas
        printf -v "$clave" '%s' "$valor"
        debug "Config: $clave=$valor"
    done < "$archivo"
}

# Evita ejecuciones simultaneas del mismo script
adquirir_bloqueo() {
    local nombre=$1
    local archivo
    archivo="${TMPDIR:-/tmp}/${nombre}_$(id -u).lock"   # un bloqueo por usuario
    exec 9> "$archivo" || die "No se pudo crear el bloqueo $archivo" "$E_BLOQUEO"
    if command -v flock >/dev/null 2>&1; then
        flock -n 9 || die "Ya hay una ejecucion de $nombre en curso. Intenta mas tarde." "$E_BLOQUEO"
    fi
}

# Dibuja una linea de N caracteres
linea() { local n=${1:-70} c=${2:--}; printf '%*s\n' "$n" '' | tr ' ' "$c"; }

# Cronometro simple por fases
inicio_fase() { _T_FASE=$(date +%s); }
fin_fase()    { echo $(( $(date +%s) - ${_T_FASE:-$(date +%s)} )); }
