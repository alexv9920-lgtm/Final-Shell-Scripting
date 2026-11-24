#!/usr/bin/env bash
# ==============================================================================
# tests/run_tests.sh - Pruebas automaticas de los 3 scripts
# ------------------------------------------------------------------------------
# Ejecuta escenarios validos e invalidos y compara el CODIGO DE SALIDA obtenido
# con el esperado. Lo usa GitHub Actions (CI) en cada push y pull request.
# Uso:  bash tests/run_tests.sh          (las pruebas de usuarios piden sudo)
# ==============================================================================
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MON="$RAIZ/Alex Yarlequé/monitor_servidor.sh"
USR="$RAIZ/Bryan Alvares/gestion_usuarios.sh"
DEP="$RAIZ/Dengelo Rojas/despliegue_servicio.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
PASA=0; FALLA=0

# prueba "descripcion" codigo_esperado comando...
prueba() {
    local desc=$1 esperado=$2; shift 2
    local obtenido arg
    # Si el script aun no se subio al repositorio, la prueba se omite
    for arg in "$@"; do
        if [[ "$arg" == *.sh && ! -f "$arg" ]]; then
            printf '  [OMITE] %-54s (falta %s)\n' "$desc" "$(basename "$arg")"; return 0
        fi
    done
    "$@" > "$TMP/salida.txt" 2>&1 < /dev/null
    obtenido=$?
    if [[ "$obtenido" == "$esperado" ]]; then
        printf '  [PASA] %-55s (codigo %s)\n' "$desc" "$obtenido"; PASA=$((PASA + 1))
    else
        printf '  [FALLA] %-54s (esperado %s, obtenido %s)\n' "$desc" "$esperado" "$obtenido"
        sed 's/^/          | /' "$TMP/salida.txt" | tail -5
        FALLA=$((FALLA + 1))
    fi
}

# Log de autenticacion simulado: 6 intentos fallidos desde la misma IP
for i in 1 2 3 4 5 6; do
    echo "Nov 24 10:0$i:00 srv sshd[100$i]: Failed password for root from 192.168.1.50 port 5000$i ssh2"
done > "$TMP/auth_ataque.log"
echo "Nov 24 11:00:00 srv sshd[2000]: Accepted publickey for alex from 10.0.0.9 port 40000 ssh2" > "$TMP/auth_normal.log"

echo "== monitor_servidor.sh (Alex) =="
prueba "Ayuda (-h)"                              0 bash "$MON" -h
prueba "Umbral no numerico (-u abc)"             2 bash "$MON" -u abc -o "$TMP/m"
prueba "Opcion inexistente (-z)"                 2 bash "$MON" -z
prueba "Log de autenticacion inexistente"        5 bash "$MON" -a /no/existe.log -o "$TMP/m"
prueba "Ataque de fuerza bruta detectado"        1 bash "$MON" -q -u 99 -s "" -a "$TMP/auth_ataque.log" -o "$TMP/m1"
prueba "Log sin eventos criticos -> OK"          0 bash "$MON" -q -u 99 -s "" -a "$TMP/auth_normal.log" -o "$TMP/m2"
prueba "Expresion cron invalida"                 2 bash "$MON" -i "* * *" -o "$TMP/m"

echo "== despliegue_servicio.sh (Dengelo) =="
prueba "Sin servidor destino"                    2 bash "$DEP" -c /dev/null
prueba "Servicio no soportado (mysql)"           2 bash "$DEP" -c /dev/null -H srv1 -u alex -s mysql
prueba "Accion invalida"                         2 bash "$DEP" -c /dev/null -H srv1 -u alex -e borrar
prueba "Host con caracteres peligrosos"          2 bash "$DEP" -c /dev/null -H 'srv;rm' -u alex
prueba "Simulacion (-n) sin conectarse"          0 bash "$DEP" -c /dev/null -H srv1 -u alex -n
prueba "Servidor inalcanzable"                   7 bash "$DEP" -c /dev/null -H 127.0.0.1 -p 2 -u alex

echo "== gestion_usuarios.sh (Bryan) =="
prueba "Ayuda (-h)"                              0 bash "$USR" -h
prueba "Accion desconocida"                      2 bash "$USR" borrar
if [[ $EUID -eq 0 ]] || sudo -n true 2>/dev/null; then
    SUDO=""; [[ $EUID -eq 0 ]] || SUDO="sudo"
    printf 'usuario,nombre_completo,rol\nqa_uno,QA Uno,desarrollo\nqa_dos,QA Dos,gerente\n' > "$TMP/qa.csv"
    printf 'usuario,clave,rol\nqa_uno,123,desarrollo\n' > "$TMP/malo.csv"
    prueba "CSV inexistente"                     5 $SUDO env SALIDA_USUARIOS="$TMP/u" bash "$USR" crear -f /no/existe.csv
    prueba "CSV con columna de contrasena"       5 $SUDO env SALIDA_USUARIOS="$TMP/u" bash "$USR" crear -f "$TMP/malo.csv"
    prueba "Simulacion con un rol invalido"      1 $SUDO env SALIDA_USUARIOS="$TMP/u" bash "$USR" crear -f "$TMP/qa.csv" -n
    prueba "Bloquear cuenta del sistema (root)"  4 $SUDO env SALIDA_USUARIOS="$TMP/u" bash "$USR" bloquear -u root
else
    echo "  (pruebas con sudo omitidas: no hay permisos de administrador)"
fi

echo
echo "Resultado: $PASA pruebas correctas, $FALLA fallidas."
(( FALLA == 0 ))
