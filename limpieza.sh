#!/bin/bash

# ==============================================================================
# 1. CARGA DE CONFIGURACIÓN
# ==============================================================================
SCRIPT_PATH="$(dirname "$(readlink -f "$0")")"

if [ -f "$SCRIPT_PATH/my.conf" ]; then
    source "$SCRIPT_PATH/my.conf"
else
    echo "❌ Error: No se encontró my.conf para obtener las rutas."
    exit 1
fi

echo "⚠️  INICIANDO LIMPIEZA TOTAL DEL ENTORNO TEMPORAL..."

# ==============================================================================
# 2. DETENCIÓN Y ELIMINACIÓN DEL CONTENEDOR DOCKER
# ==============================================================================
echo "🐳 Limpiando contenedores y volúmenes de Docker..."

if [ -f "$SCRIPT_PATH/docker-compose.yml" ]; then
    # Usamos el compose para bajar todo ordenadamente (incluyendo volúmenes huérfanos)
    docker compose -f "$SCRIPT_PATH/docker-compose.yml" down -v >/dev/null 2>&1
    
    echo "📄 Eliminando docker-compose.yml..."
    rm -f "$SCRIPT_PATH/docker-compose.yml"
else
    echo "⚠️  No se encontró docker-compose.yml."
    # Fallback: Forzamos el borrado usando el nombre de la variable de my.conf
    if [ -n "$SERVICE_NAME" ]; then
        docker rm -f "$SERVICE_NAME" >/dev/null 2>&1
    fi
fi

# ==============================================================================
# 3. ELIMINACIÓN DE ARCHIVOS SENSIBLES (¡CRÍTICO!)
# ==============================================================================
echo "🔐 Borrando archivos de configuración y secretos en texto plano..."

# Borramos los archivos desencriptados que se usaron en la restauración
rm -f "$SCRIPT_PATH/gitlab-secrets.json"
rm -f "$SCRIPT_PATH/gitlab.rb"

# Nos aseguramos de que no quede ningún rastro en memoria o disco
sync

# ==============================================================================
# 4. VACIADO DE LA CARPETA DE BACKUPS
# ==============================================================================
# Usamos ${BACKUP_DIR:?} como medida de seguridad extrema de bash. 
# Si BACKUP_DIR está vacía por algún error, el script aborta en lugar de hacer 'rm -rf /*'
if [ -d "${BACKUP_DIR}" ] && [ -n "${BACKUP_DIR}" ]; then
    echo "📂 Vaciando la carpeta de backups: $BACKUP_DIR"
    rm -rf "${BACKUP_DIR:?}"/*
else
    echo "⚠️  La ruta de backup no existe o la variable no está definida. Se omite."
fi

# ==============================================================================
# 5. RESUMEN FINAL
# ==============================================================================
echo "----------------------------------------------------------------"
echo "💥 LIMPIEZA COMPLETADA CON ÉXITO."
echo "Se han eliminado:"
echo " - Contenedores y red temporal de Docker."
echo " - Archivo docker-compose.yml."
echo " - Archivos sensibles descifrados (.json y .rb)."
echo " - Archivos residuales en la carpeta Backup."
echo "----------------------------------------------------------------"