#!/bin/bash

# ==============================================================================
# 1. CARGA DE CONFIGURACIÓN Y VALIDACIÓN
# ==============================================================================
SCRIPT_PATH="$(dirname "$(readlink -f "$0")")"

if [ -f "$SCRIPT_PATH/my.conf" ]; then
    # Limpiamos posibles retornos de carro de Windows (\r)
    source <(sed 's/\r$//' "$SCRIPT_PATH/my.conf")
else
    echo "❌ Error: No se encontró my.conf en $SCRIPT_PATH"
    exit 1
fi

# Validar variables críticas
if [ -z "$BACKUP_DIR" ] || [ -z "$GITLAB_HOME" ] || [ -z "$EDITION" ] || [ -z "$SERVICE_NAME" ]; then
    echo "❌ Error: Faltan variables críticas (BACKUP_DIR, GITLAB_HOME, EDITION, SERVICE_NAME) en my.conf."
    exit 1
fi

echo "⚙️ Configuración cargada correctamente."

# ==============================================================================
# 2. ANÁLISIS Y DESCOMPRESIÓN DEL BACKUP
# ==============================================================================
echo "📂 Verificando ruta de backup: $BACKUP_DIR"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Error: La carpeta '$BACKUP_DIR' no existe."
    exit 1
fi

# Buscar y descomprimir ZIP si existe
ZIP_FILE=$(find "$BACKUP_DIR" -maxdepth 1 -name "*.zip" | head -n 1)

if [ -n "$ZIP_FILE" ]; then
    echo "📦 ZIP detectado: $(basename "$ZIP_FILE")"
    echo "🔓 Descomprimiendo en la carpeta de destino..."
    if ! unzip -q -o "$ZIP_FILE" -d "$BACKUP_DIR"; then
        echo "❌ Error al descomprimir el archivo .zip."
        exit 1
    fi
    echo "✅ Descompresión completada."
else
    echo "ℹ️ No se encontró ningún .zip. Buscando directamente .tar..."
fi

# Localizar el TAR resultante (o existente)
BACKUP_FILE=$(find "$BACKUP_DIR" -maxdepth 1 -name "*_gitlab_backup.tar" | head -n 1)

if [ -z "$BACKUP_FILE" ]; then
    echo "❌ Error: No se encontró ningún archivo .tar de backup en $BACKUP_DIR"
    exit 1
fi

FILENAME=$(basename "$BACKUP_FILE")
echo "📄 Backup identificado: $FILENAME"

# ==============================================================================
# 3. DETECTAR VERSIÓN DE GITLAB
# ==============================================================================
echo "⚙️ Detectando versión de GitLab del backup..."

# Intento 1: Leer el archivo interno del tar (es el método más fiable)
GITLAB_VERSION=$(tar -O -xf "$BACKUP_FILE" backup_information.yml 2>/dev/null | grep ":gitlab_version:" | awk '{print $2}')

# Intento 2: Si el anterior falla, extraer del nombre del archivo
if [ -z "$GITLAB_VERSION" ]; then
    GITLAB_VERSION=$(echo "$FILENAME" | grep -oP '\d+\.\d+\.\d+')
fi

if [ -z "$GITLAB_VERSION" ]; then
    echo "❌ Error crítico: No se pudo determinar la versión del backup."
    exit 1
fi

# Limpiamos el tag para Docker (ej: 16.1.2-ce.0)
CLEAN_VERSION=$(echo "$GITLAB_VERSION" | sed -e 's/-ce//g' -e 's/-ee//g')
DOCKER_TAG="${CLEAN_VERSION}-${EDITION}.0"

echo "✅ Versión detectada: $GITLAB_VERSION"
echo "🛠️ Generando imagen objetivo: gitlab/gitlab-${EDITION}:${DOCKER_TAG}"

# ==============================================================================
# 4. PREPARACIÓN DE ENTORNO Y DOCKER COMPOSE
# ==============================================================================
echo "📁 Creando estructura de directorios en $GITLAB_HOME..."
mkdir -p "$GITLAB_HOME/config" "$GITLAB_HOME/logs" "$GITLAB_HOME/data"

echo "📄 Generando docker-compose.yml..."
cat <<EOF > "$SCRIPT_PATH/docker-compose.yml"
version: '3.6'
services:
  $SERVICE_NAME:
    image: 'gitlab/gitlab-${EDITION}:${DOCKER_TAG}'
    restart: always
    hostname: 'gitlab.example.com'
    container_name: '$SERVICE_NAME'
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://localhost'
        # Añade aquí más configuración si la necesitas
    ports:
      - '80:80'
      - '443:443'
      - '2222:22'
    volumes:
      - '${GITLAB_HOME}/config:/etc/gitlab'
      - '${GITLAB_HOME}/logs:/var/log/gitlab'
      - '${GITLAB_HOME}/data:/var/opt/gitlab'
    shm_size: '256m'
EOF
echo "✅ Archivo 'docker-compose.yml' creado."

# ==============================================================================
# 5. LIMPIEZA DE CONTENEDORES PREVIOS Y ARRANQUE
# ==============================================================================
echo "🧹 Comprobando si existe algún contenedor conflictivo..."

# Buscamos específicamente por el nombre que le vamos a dar, para no romper otros contenedores
if docker ps -a --format '{{.Names}}' | grep -Eq "^${SERVICE_NAME}$"; then
    echo "⚠️  Contenedor '$SERVICE_NAME' detectado. Deteniendo y eliminando..."
    docker rm -f "$SERVICE_NAME" >/dev/null 2>&1
    echo "✅ Contenedor anterior eliminado."
fi

echo "⬇️ Descargando imagen de GitLab (${DOCKER_TAG})..."
if ! docker compose -f "$SCRIPT_PATH/docker-compose.yml" pull -q; then
    echo "❌ Error al descargar la imagen de GitLab. ¿Existe la versión ${DOCKER_TAG}?"
    exit 1
fi

echo "🚀 Levantando contenedor de GitLab..."
if ! docker compose -f "$SCRIPT_PATH/docker-compose.yml" up -d; then
    echo "❌ Error al levantar el contenedor de Docker."
    exit 1
fi

echo "----------------------------------------------------------------"
echo "✅ ENTORNO DOCKER PREPARADO CORRECTAMENTE."
echo "----------------------------------------------------------------"