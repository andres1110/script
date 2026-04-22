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

# Configuración de red (Esto podrías moverlo a my.conf en el futuro)
RUTA_RED="//u488147.your-storagebox.de/backup"
USUARIO_RED="u488147"
PASS_RED='ZZpower!24'
PUNTO_MONTAJE="/tmp/mnt_backup_red"

# ==============================================================================
# 2. COMPROBACIÓN DE RED Y MONTAJE
# ==============================================================================
echo "🌐 Comprobando conectividad con el servidor de destino..."
# Se corrige la coma por un punto en el dominio
if ! ping -c 2 u488147.your-storagebox.de > /dev/null 2>&1; then
    echo "❌ Error: No hay respuesta del servidor u488147.your-storagebox.de. Revisa tu conexión."
    exit 1
fi

echo "🌐 Iniciando conexión a la carpeta en red..."
mkdir -p "$PUNTO_MONTAJE"

# Desmontar por si quedó enganchado de una ejecución fallida anterior
if mountpoint -q "$PUNTO_MONTAJE"; then
    echo "⚠️  El directorio ya estaba montado. Desmontando previamente..."
    sudo umount -f "$PUNTO_MONTAJE" 2>/dev/null
fi

# Montar unidad de red
 sudo mount -t cifs "$RUTA_RED" "$PUNTO_MONTAJE" -o username="$USUARIO_RED",password="$PASS_RED",vers=3.1.1,rsize=1048576,wsize=1048576,cache=loose
 username="$USUARIO_RED",password="$PASS_RED"
if [ $? -ne 0 ]; then
    echo "❌ Error: No se pudo conectar a la carpeta de red."
    exit 1
fi
echo "✅ Conectado a $RUTA_RED"

# ==============================================================================
# 3. BÚSQUEDA Y COPIA DEL BACKUP
# ==============================================================================
echo "🔍 Buscando el último backup disponible..."
# Se asegura de buscar archivos .zip o .tar y se maneja correctamente el array
ULTIMO_BACKUP=$(ls -t "$PUNTO_MONTAJE"/Gitlab/*.zip "$PUNTO_MONTAJE"/Gitlab/*.tar 2>/dev/null | head -n 1)

if [ -z "$ULTIMO_BACKUP" ]; then
    echo "❌ Error: No se encontraron archivos de backup (.zip o .tar) en la red."
    sudo umount "$PUNTO_MONTAJE"
    exit 1
fi

NOMBRE_ARCHIVO=$(basename "$ULTIMO_BACKUP")
echo "📦 Backup encontrado: $NOMBRE_ARCHIVO"

# Crear la carpeta de destino local si no existe (basado en my.conf)
mkdir -p "$BACKUP_DIR"

echo "📥 Copiando a $BACKUP_DIR (Esto puede tardar unos minutos)..."
# Usamos comillas para evitar fallos si el archivo tiene espacios
cp "$ULTIMO_BACKUP" "$BACKUP_DIR/"
RESULTADO_COPIA=$?

# ==============================================================================
# 4. LIMPIEZA Y DESCONEXIÓN
# ==============================================================================
echo "🔌 Desconectando la unidad de red..."
sudo umount "$PUNTO_MONTAJE"
rmdir "$PUNTO_MONTAJE" 2>/dev/null

if [ $RESULTADO_COPIA -eq 0 ]; then
    echo "✅ ÉXITO: El backup se ha copiado correctamente y está listo."
else
    echo "❌ FALLO: Hubo un problema al copiar el archivo."
    exit 1
fi
