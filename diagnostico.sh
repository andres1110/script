Necesito ver exactamente qué error da GPG. Ejecuta este script de diagnóstico completo:
bash#!/bin/bash
SCRIPT_PATH="$(dirname "$(readlink -f "$0")")"

echo "=== DIAGNÓSTICO COMPLETO ==="
echo ""

# 1. Verificar archivos
echo "1️⃣ Archivos en el directorio:"
ls -lh "$SCRIPT_PATH"/*.gpg "$SCRIPT_PATH"/*.txt 2>&1
echo ""

# 2. Contenido de pass.txt
echo "2️⃣ Contenido de pass.txt:"
if [ -f "$SCRIPT_PATH/pass.txt" ]; then
    echo "Hex dump:"
    hexdump -C "$SCRIPT_PATH/pass.txt"
    echo ""
    echo "Visible:"
    cat "$SCRIPT_PATH/pass.txt" | od -An -tx1
else
    echo "❌ NO EXISTE pass.txt"
fi
echo ""

# 3. Claves GPG
echo "3️⃣ Claves GPG disponibles:"
gpg --list-secret-keys
echo ""

# 4. Info del archivo cifrado
echo "4️⃣ Información del archivo .gpg:"
if [ -f "$SCRIPT_PATH/gitlab-secrets.json.gpg" ]; then
    gpg --list-packets "$SCRIPT_PATH/gitlab-secrets.json.gpg" 2>&1 | head -30
else
    echo "❌ NO EXISTE gitlab-secrets.json.gpg"
fi
echo ""

# 5. Intento de descifrado con ERROR COMPLETO
echo "5️⃣ Intento de descifrado (MOSTRANDO ERRORES COMPLETOS):"
if [ -f "$SCRIPT_PATH/pass.txt" ] && [ -f "$SCRIPT_PATH/gitlab-secrets.json.gpg" ]; then
    PASS_LIMPIA=$(cat "$SCRIPT_PATH/pass.txt" | tr -d '\n\r')
    echo "Contraseña leída (longitud: ${#PASS_LIMPIA} caracteres)"
    echo ""
    gpg --batch --yes --pinentry-mode loopback \
        --passphrase "$PASS_LIMPIA" \
        --decrypt "$SCRIPT_PATH/gitlab-secrets.json.gpg" 2>&1
fi

echo ""
echo "=== FIN DIAGNÓSTICO ==="
