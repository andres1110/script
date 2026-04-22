#!/bin/bash
# ==============================================================================
# 1. CARGA DE CONFIGURACIÓN
# ==============================================================================
SCRIPT_PATH="$(dirname "$(readlink -f "$0")")"
if [ -f "$SCRIPT_PATH/my.conf" ]; then
    source "$SCRIPT_PATH/my.conf"
else
    echo "❌ Error: No se encontró my.conf"
    exit 1
fi

echo "🚀 Iniciando restauración de GitLab..."

# Identificar Contenedor
CONTAINER_NAME=$(docker compose -f "$SCRIPT_PATH/docker-compose.yml" ps -q "$SERVICE_NAME")
if [ -z "$CONTAINER_NAME" ]; then
    echo "❌ Error: Contenedor '$SERVICE_NAME' no encontrado."
    exit 1
fi

# ==============================================================================
# 2. DESBLOQUEO Y LIMPIEZA DE COLISIONES
# ==============================================================================
echo "🧹 Limpiando bloqueos y colisiones..."

# Eliminar el archivo 'backups' si es un archivo plano (evita el error 'File exists')
if [ -f "${GITLAB_HOME}/data/backups" ]; then
    rm -f "${GITLAB_HOME}/data/backups"
fi
mkdir -p "${GITLAB_HOME}/data/backups"

# Matar procesos de reconfiguración que estén bloqueando
echo "🛑 Deteniendo procesos de configuración previos..."
docker exec -i "$CONTAINER_NAME" pkill -f cinc-client 2>/dev/null
docker exec -i "$CONTAINER_NAME" pkill -f chef-client 2>/dev/null

# Eliminar archivos de bloqueo (lock files)
docker exec -i "$CONTAINER_NAME" rm -f /opt/gitlab/embedded/cookbooks/cache/chef-client-running.pid 2>/dev/null

# ==============================================================================
# 3. PREPARACIÓN DE ARCHIVOS
# ==============================================================================
BACKUP_FILE=$(ls -t "${BACKUP_DIR}"/*_gitlab_backup.tar 2>/dev/null | head -n 1)

if [ -z "$BACKUP_FILE" ]; then
    echo "❌ Error: No se encontró ningún archivo de backup en ${BACKUP_DIR}"
    exit 1
fi

BACKUP_NAME=$(basename "$BACKUP_FILE" _gitlab_backup.tar)
echo "📦 Usando backup: $BACKUP_NAME"

echo "📤 Copiando configuración..."
cp "$BACKUP_FILE" "${GITLAB_HOME}/data/backups/"

if [ -f "$SCRIPT_PATH/gitlab-secrets.json" ]; then
    cp "$SCRIPT_PATH/gitlab-secrets.json" "${GITLAB_HOME}/config/"
fi

if [ -f "$SCRIPT_PATH/gitlab.rb" ]; then
    cp "$SCRIPT_PATH/gitlab.rb" "${GITLAB_HOME}/config/"
fi

# Desactivar Let's Encrypt temporalmente para evitar bloqueos
echo "🛡️  Desactivando Auto-SSL temporalmente para la restauración..."
if ! grep -q "letsencrypt\['enable'\] = false" "${GITLAB_HOME}/config/gitlab.rb"; then
    echo "letsencrypt['enable'] = false" >> "${GITLAB_HOME}/config/gitlab.rb"
fi

# Ajustar permisos
docker exec -i "$CONTAINER_NAME" chown -R git:git /var/opt/gitlab/backups
docker exec -i "$CONTAINER_NAME" chmod 700 /var/opt/gitlab/backups

# ==============================================================================
# 4. RECONFIGURACIÓN Y RESTAURACIÓN
# ==============================================================================
echo "⚙️  Ejecutando reconfiguración (limpia)..."
if ! docker exec -i "$CONTAINER_NAME" gitlab-ctl reconfigure; then
    echo "❌ ERROR: La reconfiguración ha fallado."
    exit 1
fi

echo "🛠️ Restaurando base de datos..."
docker exec -i "$CONTAINER_NAME" gitlab-ctl stop puma
docker exec -i "$CONTAINER_NAME" gitlab-ctl stop sidekiq

if ! docker exec -i "$CONTAINER_NAME" gitlab-backup restore BACKUP="$BACKUP_NAME" force=yes; then
    echo "❌ ERROR: Fallo en la restauración de datos."
    exit 1
fi

echo "🔄 Finalizando..."
docker exec -i "$CONTAINER_NAME" gitlab-ctl reconfigure
docker exec -i "$CONTAINER_NAME" gitlab-ctl restart

echo "✅ PROCESO COMPLETADO."
