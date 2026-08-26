#!/bin/bash
# ==============================================================================
# Script di Sincronizzazione MultiSite DB da Produzione a Staging per Pambianconews
# ==============================================================================
set -e

STAGING_PATH="/var/www/staging.pambianconews.com"
DUMP_FILE="/tmp/pambianconews_multisite_dump.sql"

echo "🚀 Avvio della sincronizzazione Database MultiSite su Staging..."

# 1. Import nel DB di staging
if [ -f "$DUMP_FILE" ]; then
    echo "📥 Importazione Database MultiSite..."
    wp db import $DUMP_FILE --path=$STAGING_PATH --allow-root
fi

# 2. Search & Replace MultiSite Portals (Moda, Design, Beauty, Wine, Hotellerie, Magazine)
echo "🔄 Sostituzione URL dei portali MultiSite per lo Staging..."

wp search-replace "https://www.pambianconews.com" "https://staging.pambianconews.com" --url=www.pambianconews.com --network --all-tables --path=$STAGING_PATH --allow-root || true
wp search-replace "https://design.pambianconews.com" "https://staging.design.pambianconews.com" --network --all-tables --path=$STAGING_PATH --allow-root || true
wp search-replace "https://beauty.pambianconews.com" "https://staging.beauty.pambianconews.com" --network --all-tables --path=$STAGING_PATH --allow-root || true
wp search-replace "https://wine.pambianconews.com" "https://staging.wine.pambianconews.com" --network --all-tables --path=$STAGING_PATH --allow-root || true
wp search-replace "https://hotellerie.pambianconews.com" "https://staging.hotellerie.pambianconews.com" --network --all-tables --path=$STAGING_PATH --allow-root || true
wp search-replace "https://magazine.pambianconews.com" "https://staging.magazine.pambianconews.com" --network --all-tables --path=$STAGING_PATH --allow-root || true

# 3. Aggiornamento tabelle di rete MultiSite (wp_blogs e wp_site)
echo "🌐 Aggiornamento domini nelle tabelle di rete MultiSite..."
wp db query "UPDATE wp_blogs SET domain = REPLACE(domain, 'pambianconews.com', 'staging.pambianconews.com');" --path=$STAGING_PATH --allow-root || true
wp db query "UPDATE wp_site SET domain = REPLACE(domain, 'pambianconews.com', 'staging.pambianconews.com');" --path=$STAGING_PATH --allow-root || true

# 4. Anonimizzazione Email e Sicurezza
echo "🔒 Anonimizzazione email utenti in Staging..."
wp db query "UPDATE wp_users SET user_email = CONCAT('staging_user_', ID, '@example.com') WHERE ID > 1;" --path=$STAGING_PATH --allow-root || true

# 5. Flush della cache
echo "🧹 Pulizia Cache..."
wp cache flush --path=$STAGING_PATH --allow-root || true

echo "✅ Sincronizzazione MultiSite completata con successo per Pambianconews Staging!"
