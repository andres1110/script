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

# Utilizamos BACKUP_DIR cargado desde my.conf en lugar de "Backup" estático
FILE1="$BACKUP_DIR/gitlab-secrets.json.gpg"
FILE2="$BACKUP_DIR/gitlab.rb.gpg"
OUT1="$SCRIPT_PATH/gitlab-secrets.json"
OUT2="$SCRIPT_PATH/gitlab.rb"

# Comprobación estricta del archivo de contraseña
#if [ ! -f "$PASS_FILE" ]; then
#    echo "❌ Error CRÍTICO: No se encontró el archivo de contraseña en: $PASS_FILE"
#    exit 1
#fi

# Leer la contraseña una sola vez y limpiarla de saltos de línea y espacios
#PASS_LIMPIA=$(cat "$PASS_FILE" | tr -d '\n\r' | tr -d ' ')

#if [ -z "$PASS_LIMPIA" ]; then
#    echo "❌ Error CRÍTICO: El archivo $PASS_FILE está vacío."
#    exit 1
#fi

# ==============================================================================
# 2. IMPORTACIÓN DE CLAVE GPG
# ==============================================================================
echo "🔐 Iniciando proceso de desencriptación..."

if [ -f "$SCRIPT_PATH/decrypt.gpg" ]; then
    echo "🔑 Importando clave GPG..."
    # Redirigimos stderr a /dev/null para no ensuciar el log con avisos de "clave ya conocida"
    gpg --import "$SCRIPT_PATH/decrypt.gpg" 2>/dev/null
else
    echo "⚠️  Aviso: No se encontró $SCRIPT_PATH/decrypt.gpg. Se asume que la clave ya está importada."
fi

# ==============================================================================
# 3. FUNCIÓN DE DESCIFRADO
# ==============================================================================
descifrar_archivo() {
    local origen="$1"
    local destino="$2"
    
    if [ ! -f "$origen" ]; then
        echo "⚠️  Advertencia: No se encontró el archivo cifrado $origen"
        return 1
    fi
    
    echo "🔓 Descifrando $(basename "$origen")..."
    
    # Se eliminan los saltos de línea de la salida de GPG para logs más limpios
    gpg --batch --yes \
        -o "$destino" -d "$origen" 2>&1
    
    # Verificación de que el archivo se ha creado y no está vacío
    if [ ! -s "$destino" ]; then
        echo "❌ ERROR: El archivo descifrado ($(basename "$destino")) está vacío o falló."
        echo "   Posibles causas: Contraseña incorrecta o archivo corrupto."
        rm -f "$destino"
        exit 1
    fi

    # Seguridad: Bloquear permisos para que solo el propietario (root/usuario) pueda leer los secretos
    chmod 600 "$destino"
    echo "   ✅ Descifrado exitoso y protegido: $(basename "$destino")"
}

# ==============================================================================
# 4. EJECUCIÓN PRINCIPAL
# ==============================================================================
descifrar_archivo "$FILE1" "$OUT1"
descifrar_archivo "$FILE2" "$OUT2"

# Verificamos que ambos archivos cruciales existen antes de dar el OK final
if [ ! -f "$OUT1" ] || [ ! -f "$OUT2" ]; then
    echo "❌ ERROR: Faltan archivos críticos de configuración. Abortando."
    exit 1
fi

echo "----------------------------------------------------------------"
echo "✅ Archivos preparados correctamente en:"
echo "   -> $OUT1"
echo "   -> $OUT2"
