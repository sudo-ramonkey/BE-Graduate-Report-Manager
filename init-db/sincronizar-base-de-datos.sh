#!/bin/bash
# Deja el esquema de la base de datos al dia, en una instalacion nueva o en una
# que ya lleva tiempo corriendo.
#
# POR QUE EXISTE:
# los scripts de /docker-entrypoint-initdb.d solo corren cuando el volumen de
# MariaDB esta vacio. En un despliegue en marcha, un cambio en .db-tables,
# .db-migrations o .db-procedures nunca llegaba a la base de datos: habia que
# aplicarlo a mano. De ahi venian los "esto ya estaba arreglado y se volvio a
# romper" -- el codigo nuevo hablaba con procedimientos viejos.
#
# Lo llama desplegar.sh en cada despliegue. Es seguro repetirlo:
#  - .db-tables      usa "create table if not exists"
#  - .db-migrations  usa "add column if not exists" y similares
#  - .db-procedures  usa "create or replace procedure"
#
# Se conecta como root porque el usuario de la aplicacion tiene revocados
# CREATE/DROP/ALTER a proposito (ver 01-inicializar.sh).
#
# Uso:  ./init-db/sincronizar-base-de-datos.sh
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
    echo "ERROR: No se encontro el archivo .env" >&2
    exit 1
fi

# shellcheck disable=SC1091
set -a; . ./.env; set +a

if [ -z "${MARIADB_ROOT_PASSWORD:-}" ]; then
    echo "ERROR: MARIADB_ROOT_PASSWORD no esta definido en .env" >&2
    exit 1
fi

# Los objetos llevan el prefijo 'residencias.' explicito, asi que la base de
# datos por defecto de la conexion solo importa para los procedimientos.
BASE_DATOS="${DATABASE_NAME:-residencias}"

# Permite reutilizar el script desde otro proyecto de compose (por ejemplo el
# de desarrollo):  PROYECTO_COMPOSE=residencias-dev ./init-db/sincronizar...
COMPOSE=(docker compose)
if [ -n "${PROYECTO_COMPOSE:-}" ]; then
    COMPOSE=(docker compose -p "$PROYECTO_COMPOSE")
fi

ejecutar_sql() {
    "${COMPOSE[@]}" exec -T \
        -e MYSQL_PWD="$MARIADB_ROOT_PASSWORD" \
        mariadb mariadb -u root "$@"
}

# --- 1. Tablas -------------------------------------------------------------
# Crea solo las que falten. Nunca modifica una tabla existente; para eso estan
# las migraciones del paso 2.
echo ">>> Verificando tablas..."
ejecutar_sql < .db-tables

# --- 2. Migraciones de esquema --------------------------------------------
if [ -s .db-migrations ]; then
    echo ">>> Aplicando migraciones de esquema..."
    ejecutar_sql < .db-migrations
fi

# --- 3. Procedimientos almacenados ----------------------------------------
# El volcado no trae sentencias DELIMITER, asi que se envuelven aqui y se
# reescribe el 'end;' final de cada procedimiento como 'end //'. Mismo
# preprocesado que init-db/01-inicializar.sh.
echo ">>> Reaplicando procedimientos almacenados en '$BASE_DATOS'..."
archivo_tmp=$(mktemp)
trap 'rm -f "$archivo_tmp"' EXIT

echo "DELIMITER //" > "$archivo_tmp"
sed 's/^end;$/end \/\//' .db-procedures >> "$archivo_tmp"
echo "" >> "$archivo_tmp"
echo "DELIMITER ;" >> "$archivo_tmp"

ejecutar_sql "$BASE_DATOS" < "$archivo_tmp"

echo ">>> Base de datos sincronizada."
