#!/bin/bash
# ==============================================================================
# Script di Configurazione Automatica Server Hetzner Staging per Pambianconews
# ==============================================================================
set -e

echo "🚀 Inizio configurazione automatica del server Hetzner Staging..."

# 1. Aggiornamento sistema e pacchetti base
apt-get update && apt-get upgrade -y
apt-get install -y curl git ufw apache2-utils rsync ca-certificates gnupg lsb-release

# 2. Installazione Docker & Docker Compose
if ! command -v docker &> /dev/null; then
    echo "🐳 Installazione Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
fi

# 3. Configurazione Firewall (UFW)
echo "🛡️ Configurazione Firewall (SSH, HTTP, HTTPS)..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# 4. Creazione cartella Staging
echo "📁 Creazione directory di Staging..."
mkdir -p /var/www/staging.pambianconews.com
cd /var/www/staging.pambianconews.com

# 5. Generazione Basic Auth htpasswd per Staging
echo "🔐 Creazione credenziali di accesso Staging (Basic Auth)..."
if [ ! -f /etc/nginx/.htpasswd ]; then
    mkdir -p /etc/nginx
    htpasswd -cb /etc/nginx/.htpasswd pambianco Staging2026!
    echo "✅ Credenziali Basic Auth create:"
    echo "   Utente:   pambianco"
    echo "   Password: Staging2026!"
fi

echo "🎉 Server Hetzner configurato con successo!"
