#!/bin/bash

# ==============================================================================
# 1. INICIALIZACIÓN Y CONFIGURACIÓN
# ==============================================================================
SCRIPT_PATH="$(dirname "$(readlink -f "$0")")"

if [ -f "$SCRIPT_PATH/my.conf" ]; then
    source "$SCRIPT_PATH/my.conf"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] ❌ Error: No se encontró my.conf"
    exit 1
fi

MSG_OK="$SCRIPT_PATH/mensaje_ok.txt"
MSG_ERROR="$SCRIPT_PATH/mensaje_error.txt"
LOG_FILE="/tmp/gitlab_restauracion_$$.log"

# Limpiar log anterior si existiera (inicia el log en blanco)
> "$LOG_FILE"

# ==============================================================================
# 2. FUNCIONES PRINCIPALES
# ==============================================================================

send_mail() {
    local status=$1
    local script_name=$2
    local body_file
    local subject_prefix
    local body

    if [ "$status" -eq 0 ]; then
        body_file="$MSG_OK"
        subject_prefix="✅ OK"
    else
        body_file="$MSG_ERROR"
        subject_prefix="❌ Error"
    fi

    # Leer el contenido del archivo de texto y añadir cabecera de servidor con ZONA HORARIA
    if [ -f "$body_file" ]; then
        body="📅 Fecha: $(date '+%Y-%m-%d %H:%M:%S %Z')\n🖥️ Servidor: $(hostname)\n\n$(cat "$body_file")"
    else
        body="Mensaje automático: Finalizado con estado $status en $script_name."
    fi

    # Si hay error, adjuntamos el final del log para entender qué pasó
    if [ "$status" -ne 0 ] && [ -f "$LOG_FILE" ]; then
        body="$body\n\n--- DETALLE DEL ERROR ---\nScript: $script_name\nÚltimas líneas del log:\n$(tail -n 40 "$LOG_FILE")"
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] 📧 Enviando notificación por correo electrónico..." | tee -a "$LOG_FILE"

    curl --url "smtp://${SMTP_SERVER}:${SMTP_PORT}" --ssl-reqd \
        --mail-from "$SMTP_FROM" \
        --mail-rcpt "$SMTP_TO" \
        --user "${SMTP_USER}:${SMTP_PASS}" \
        -T <(printf "From: %s\r\nTo: %s\r\nSubject: %s Restauración Gitlab\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n%b" \
            "$SMTP_FROM" "$SMTP_TO" "$subject_prefix" "$body")
            
    if [ $? -ne 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] ⚠️  Advertencia: Hubo un problema al enviar el correo a $SMTP_TO" | tee -a "$LOG_FILE"
    fi
}

ejecutar_paso() {
    local script_name=$1
    local script_path="$SCRIPT_PATH/$script_name"
    
    echo "" | tee -a "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] ======================================================================" | tee -a "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] ▶️  INICIANDO: $script_name" | tee -a "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] ======================================================================" | tee -a "$LOG_FILE"
    
    if [ ! -f "$script_path" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] ❌ Error: No se encuentra el script $script_name en $SCRIPT_PATH" | tee -a "$LOG_FILE"
        send_mail 1 "$script_name (Archivo no encontrado)"
        exit 1
    fi

    # Ejecutamos el script y le añadimos fecha/hora/zona a CADA línea de su salida
    sudo "$script_path" 2>&1 | while IFS= read -r line; do
        echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] $line"
    done | tee -a "$LOG_FILE"
    
    local status=${PIPESTATUS[0]}

    if [ $status -ne 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] ❌ FALLO CRÍTICO en $script_name. Abortando proceso completo." | tee -a "$LOG_FILE"
        send_mail 1 "$script_name"
        exit 1
    fi
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] ✅ $script_name completado correctamente." | tee -a "$LOG_FILE"
}

# ==============================================================================
# 3. SECUENCIA MAESTRA DE EJECUCIÓN
# ==============================================================================

echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] 🚀 INICIANDO RESTAURACIÓN DE GITLAB..." | tee -a "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] 📄 Generando log temporal en: $LOG_FILE" | tee -a "$LOG_FILE"

# 1. Conexión de red
ejecutar_paso "conexion.sh"

# 2. Descompresión y preparación de Docker
ejecutar_paso "scriptdocker.sh"

# 3. Desencriptado de claves
ejecutar_paso "decrypt.sh"

# 4. Restauración del Backup
ejecutar_paso "restauracion.sh"

# ==============================================================================
# 4. ÉXITO Y LIMPIEZA FINAL
# ==============================================================================

echo "" | tee -a "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] 🎉 RESTAURACIÓN COMPLETADA CON ÉXITO." | tee -a "$LOG_FILE"
send_mail 0 "Restauracion_Completa"

echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] 🧹 Iniciando limpieza post-restauración..." | tee -a "$LOG_FILE"

# Ejecutamos la limpieza también con timestamps completos
sudo "$SCRIPT_PATH/limpieza.sh" 2>&1 | while IFS= read -r line; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] $line"
done | tee -a "$LOG_FILE"

# Borramos el log temporal solo si todo ha ido bien
rm -f "$LOG_FILE"

echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] ✅ PROCESO MAESTRO FINALIZADO TOTALMENTE."
