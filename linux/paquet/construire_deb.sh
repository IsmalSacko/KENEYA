#!/bin/bash
# Paquet Ubuntu/Debian de Ngoni Santé (.deb), à partir du build Linux.
#   flutter build linux --release
#   bash linux/paquet/construire_deb.sh
# Le paquet sort dans build/linux/ngoni-sante_<version>_amd64.deb.
# Installation : sudo apt install ./build/linux/ngoni-sante_<version>_amd64.deb
set -euo pipefail
cd "$(dirname "$0")/../.."

VERSION=$(grep -E '^version:' pubspec.yaml | sed -E 's/version: *([0-9.]+).*/\1/')
BUNDLE=build/linux/x64/release/bundle
[ -x "$BUNDLE/ngoni_sante" ] || { echo "Build Linux absent : flutter build linux --release"; exit 1; }

RACINE=build/linux/deb
rm -rf "$RACINE"
mkdir -p "$RACINE/DEBIAN" "$RACINE/opt/ngoni-sante" "$RACINE/usr/bin" \
  "$RACINE/usr/share/applications" "$RACINE/usr/share/icons/hicolor/512x512/apps"

cp -r "$BUNDLE"/. "$RACINE/opt/ngoni-sante/"
ln -s /opt/ngoni-sante/ngoni_sante "$RACINE/usr/bin/ngoni-sante"
convert assets/images/app_icon_1024.png -resize 512x512 \
  "$RACINE/usr/share/icons/hicolor/512x512/apps/ngoni-sante.png"

cat > "$RACINE/usr/share/applications/ngoni-sante.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Ngoni Santé
Comment=Gestion des établissements de santé
Exec=/opt/ngoni-sante/ngoni_sante
Icon=ngoni-sante
Terminal=false
Categories=Office;MedicalSoftware;
StartupWMClass=ngoni_sante
DESKTOP

TAILLE=$(du -sk "$RACINE/opt" | cut -f1)
cat > "$RACINE/DEBIAN/control" <<CONTROL
Package: ngoni-sante
Version: $VERSION
Section: misc
Priority: optional
Architecture: amd64
Installed-Size: $TAILLE
Depends: libgtk-3-0, libsecret-1-0
Maintainer: IsmaelDev
Homepage: https://ismael-dev.com
Description: Ngoni Santé — gestion des établissements de santé
 Accueil, file d'attente, consultation, laboratoire, pharmacie et caisse
 dans une seule application pour toute l'équipe.
CONTROL

dpkg-deb --root-owner-group --build "$RACINE" "build/linux/ngoni-sante_${VERSION}_amd64.deb" >/dev/null
echo "✓ build/linux/ngoni-sante_${VERSION}_amd64.deb"
