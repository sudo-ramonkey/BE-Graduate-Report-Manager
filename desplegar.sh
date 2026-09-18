#!/bin/bash
# Despliegue del Sistema de Gestion de Residencias.
#
# Un solo comando desde un clon limpio:
#   ./desplegar.sh
#
# Construye las dos imagenes desde el codigo local, levanta los servicios y deja
# la base de datos lista (tablas, migraciones, procedimientos, catalogo,
# superusuario y semestres del año). No hace falta escribir SQL a mano ni
# editar el .env: si falta, se genera con secretos aleatorios.
#
# Opciones:
#   --con-registro   Descarga las imagenes de ghcr.io en vez de construirlas.
#                    Requiere `docker login ghcr.io`: los paquetes son privados.
#   --sin-cache      Reconstruye las imagenes ignorando la cache de Docker.
set -euo pipefail

cd "$(dirname "$0")"

REPO_FRONTEND="https://github.com/Artdryy/FE-Graduate-Report-Manager.git"
DIR_FRONTEND="../FE-Graduate-Report-Manager"

USAR_REGISTRO=0
SIN_CACHE=0
for argumento in "$@"; do
    case "$argumento" in
        --con-registro) USAR_REGISTRO=1 ;;
        --sin-cache)    SIN_CACHE=1 ;;
        -h|--help)
            sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "ERROR: opcion desconocida '$argumento' (usa --help)" >&2
            exit 1
            ;;
    esac
done

echo "=== Despliegue del Sistema de Gestion de Residencias ==="

# ---------------------------------------------------------------------------
# 1. Archivo .env
# ---------------------------------------------------------------------------
# Antes habia que copiar .env.example a mano y reemplazar cuatro secretos, y el
# despliegue abortaba hasta que estuvieran todos. Ahora se genera solo.
generar_secreto() {
    # Solo alfanumericos: el valor viaja por .env, docker compose y sentencias
    # SQL de inicializacion, y asi no hay nada que escapar en ningun paso.
    LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "${1:-24}"
}

if [ ! -f .env ]; then
    if [ ! -f .env.example ]; then
        echo "ERROR: no hay .env ni .env.example de donde partir" >&2
        exit 1
    fi

    echo ""
    echo ">>> No hay .env: generando uno con secretos aleatorios..."

    # Cada asignacion "VARIABLE=cambiar_*" de .env.example recibe un valor real.
    # Los comentarios y el resto de las lineas se copian tal cual, para que el
    # .env generado siga siendo tan legible como el ejemplo.
    while IFS= read -r linea; do
        if [[ "$linea" =~ ^[[:space:]]*([A-Z_]+)=cambiar_ ]]; then
            variable="${BASH_REMATCH[1]}"
            if [ "$variable" = "JWT_SECRET" ]; then
                echo "$variable=$(openssl rand -hex 32)"
            else
                echo "$variable=$(generar_secreto 24)"
            fi
        else
            echo "$linea"
        fi
    done < .env.example > .env

    chmod 600 .env
    echo ">>> .env generado."
else
    echo ""
    echo ">>> Usando el .env existente."

    # Un .env escrito a mano puede seguir teniendo los valores de ejemplo. El
    # backend los rechaza al arrancar (config/envSchema.js), asi que es mejor
    # avisar aqui que dejar que el contenedor muera sin explicacion.
    if grep -qE '^[[:space:]]*[A-Z_]+=cambiar_' .env; then
        echo "ERROR: .env todavia contiene valores de ejemplo (cambiar_*)." >&2
        echo "Configura estas variables, o borra el .env para regenerarlo:" >&2
        grep -nE '^[[:space:]]*[A-Z_]+=cambiar_' .env | sed 's/^/  /' >&2
        exit 1
    fi
fi

# shellcheck disable=SC1091
set -a; . ./.env; set +a

# ---------------------------------------------------------------------------
# 2. Codigo del frontend
# ---------------------------------------------------------------------------
# El frontend es otro repositorio. La imagen se construye desde el directorio
# hermano, asi que si no esta hay que traerlo.
ARCHIVOS_COMPOSE=(-f docker-compose.yml)

if [ "$USAR_REGISTRO" -eq 1 ]; then
    ARCHIVOS_COMPOSE+=(-f docker-compose.registro.yml)
    echo ""
    echo ">>> Modo registro: se descargaran las imagenes de ghcr.io."
else
    if [ ! -d "$DIR_FRONTEND" ]; then
        echo ""
        echo ">>> Falta el repositorio del frontend: clonando en $DIR_FRONTEND..."
        git clone "$REPO_FRONTEND" "$DIR_FRONTEND"
    else
        echo ""
        echo ">>> Frontend encontrado en $DIR_FRONTEND"
    fi
fi

# ---------------------------------------------------------------------------
# 3. Imagenes
# ---------------------------------------------------------------------------
echo ""
if [ "$USAR_REGISTRO" -eq 1 ]; then
    echo ">>> Descargando imagenes..."
    docker compose "${ARCHIVOS_COMPOSE[@]}" pull
else
    echo ">>> Construyendo imagenes desde el codigo local..."
    if [ "$SIN_CACHE" -eq 1 ]; then
        docker compose "${ARCHIVOS_COMPOSE[@]}" build --no-cache
    else
        docker compose "${ARCHIVOS_COMPOSE[@]}" build
    fi
fi

# ---------------------------------------------------------------------------
# 4. Base de datos primero
# ---------------------------------------------------------------------------
# Solo MariaDB: el backend no debe arrancar hasta que las credenciales y el
# esquema esten al dia. Antes se levantaba todo junto; si el backend no
# llegaba a "healthy" (contraseña desalineada, esquema viejo), `up -d` fallaba,
# set -e cortaba el script y la sincronizacion que lo habria arreglado nunca
# corria.
echo ""
echo ">>> Levantando MariaDB..."
docker compose "${ARCHIVOS_COMPOSE[@]}" up -d mariadb

echo ""
echo ">>> Esperando a que MariaDB este lista..."
contenedor_db=$(docker compose "${ARCHIVOS_COMPOSE[@]}" ps -q mariadb)
estado="starting"
for _ in $(seq 1 60); do
    estado=$(docker inspect --format '{{.State.Health.Status}}' "$contenedor_db" 2>/dev/null || echo "starting")
    [ "$estado" = "healthy" ] && break
    sleep 2
done

if [ "$estado" != "healthy" ]; then
    echo "ERROR: MariaDB no llego a estar lista. Revisa:" >&2
    echo "  docker compose logs mariadb" >&2
    exit 1
fi

# Tablas, migraciones, procedimientos y la contraseña del usuario de la
# aplicacion (los scripts de /docker-entrypoint-initdb.d solo corren con el
# volumen vacio, asi que un despliegue existente se quedaba desalineado).
echo ""
./init-db/sincronizar-base-de-datos.sh

# ---------------------------------------------------------------------------
# 5. Backend y frontend
# ---------------------------------------------------------------------------
# El backend siembra el catalogo, el superusuario y los semestres al arrancar,
# ya contra el esquema actualizado. --force-recreate para que un backend que
# quedo en bucle de reinicios con la contraseña vieja arranque limpio.
echo ""
echo ">>> Levantando backend y frontend..."
if ! docker compose "${ARCHIVOS_COMPOSE[@]}" up -d --force-recreate backend frontend; then
    echo "ERROR: el backend no arranco. Revisa:" >&2
    echo "  docker compose logs backend" >&2
    exit 1
fi

echo ""
echo "=== Despliegue completado ==="
echo "Frontend disponible en: http://localhost"
echo "Backend API en:         http://localhost/api"
echo ""
echo "Usuario inicial:"
echo "  usuario:    ${SUPERUSER_USER:-superusuario}"
echo "  contraseña: ${SUPERUSER_PASSWORD:-(ver .env)}"
echo "  (guardado en .env; cambiala despues del primer acceso)"
echo ""
echo "Comandos utiles:"
echo "  docker compose logs -f    # Ver logs en tiempo real"
echo "  docker compose down       # Detener servicios"
echo "  docker compose ps         # Ver estado de servicios"
