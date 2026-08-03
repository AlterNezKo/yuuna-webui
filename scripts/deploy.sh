#!/bin/bash

# ==============================================================================
# Instalador de Yuuna WebUI - Just Nezu
# Framework user-friendly para Open WebUI 
# ==============================================================================

echo "Definiendo el entorno para Yuuna WebUI..."
sleep 1

# 1. Definir variables de rutas
export STORAGE_LOCATION="$HOME/.local/yuuna-webui"
export ENV_FILE="$STORAGE_LOCATION/.env"

# 2. Crear directorios para persistencia de datos
echo "Preparando directorios en $STORAGE_LOCATION..."
mkdir -p "$STORAGE_LOCATION/data"

# 3. Gestión de la llave secreta
# Vital para no cerrar sesiones tras cada actualización de la imagen.
if [ ! -f "$ENV_FILE" ]; then
    echo "Generando WEBUI_SECRET_KEY para proteger tus sesiones..."
    sleep 1
    # Genera un string hexadecimal de 32 bytes y lo guarda en el .env
    SECRET_KEY=$(openssl rand -hex 32)
    echo "WEBUI_SECRET_KEY=\"$SECRET_KEY\"" > "$ENV_FILE"
else
    echo "Archivo .env detectado. Manteniendo la configuración existente..."
    sleep 1
fi

# 4. Levantar el contenedor con Podman
VERSION=${1:-main}

echo "Descargando la versión $VERSION y levantando Yuuna WebUI Core..."

podman run -d \
  --name yuuna-webui \
  --replace \
  --pull=always \
  -p 127.0.0.1:3000:8080 \
  --env-file "$ENV_FILE" \
  -v "$STORAGE_LOCATION/data:/app/backend/data" \
  --restart always \
  ghcr.io/open-webui/open-webui:$VERSION

echo "======================================================"
echo "¡Proceso finalizado con éxito! <3"
echo "Yuuna WebUI está corriendo de forma segura."
echo ""
echo "=> Dirígete a: http://127.0.0.1:3000"
echo "¡No olvides esperar al menos 20 segundos antes de ir a tu nevagador!"
echo "======================================================"
