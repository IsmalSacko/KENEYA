#!/usr/bin/env bash
# Lance Ngoni Santé en local : l'API dans Docker, l'émulateur, puis l'app
# branchée sur cette API (et non sur la production).
#
#   ./lancer_local.sh            → tablette (Pixel_Tablet_API_34)
#   ./lancer_local.sh telephone  → téléphone (Pixel_7_Pro_API_34)
#
# Compte de démo : 70000001, PIN 1234.
set -e

ICI="$(cd "$(dirname "$0")" && pwd)"
API="$ICI/../KENEYA-BACK"
EMULATEUR=Pixel_Tablet_API_34
[ "$1" = "telephone" ] && EMULATEUR=Pixel_7_Pro_API_34

echo "1/3 · API (Docker, port 8000)"
cd "$API"
APP_PORT=8000 DB_FORWARD_PORT=33306 REDIS_FORWARD_PORT=36379 \
  MAILPIT_SMTP_PORT=31025 MAILPIT_UI_PORT=38025 docker compose up -d
until docker exec keneya_mysql mysqladmin ping -h127.0.0.1 -uroot -proot --silent 2>/dev/null; do sleep 2; done
docker exec keneya_keneya php artisan migrate --force

echo "2/3 · Émulateur"
if ! adb devices | grep -q "emulator-"; then
  flutter emulators --launch "$EMULATEUR"
  adb wait-for-device
  until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done
fi
APPAREIL="$(adb devices | grep -m1 'emulator-' | cut -f1)"

echo "3/3 · App sur $APPAREIL → API locale (r = recharger, R = redémarrer, q = quitter)"
cd "$ICI"
flutter run -d "$APPAREIL" --dart-define=API_URL=http://10.0.2.2:8000/api
