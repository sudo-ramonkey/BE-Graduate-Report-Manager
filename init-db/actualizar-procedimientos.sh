#!/bin/bash
# Compatibilidad: este script ahora es un envoltorio de
# init-db/sincronizar-base-de-datos.sh, que ademas de los procedimientos
# aplica las tablas que falten y las migraciones de esquema.
#
# Ya no hace falta ejecutarlo a mano: desplegar.sh sincroniza la base de datos
# en cada despliegue.
set -euo pipefail

echo ">>> (actualizar-procedimientos.sh ahora llama a sincronizar-base-de-datos.sh)"
exec "$(dirname "$0")/sincronizar-base-de-datos.sh" "$@"
