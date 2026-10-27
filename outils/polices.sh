#!/usr/bin/env bash
# Télécharge les polices de l'application pour les outils de rendu (captures
# de la fiche Play, image de présentation).
#
# L'application les charge par `google_fonts`, qui les va chercher sur le
# réseau ; le harnais de test coupe le réseau : sans ces fichiers, chaque
# lettre des captures sortirait en rectangle plein. Non versionnées.
#
# Usage : outils/polices.sh
set -euo pipefail

cd "$(dirname "$0")"
mkdir -p polices

# Sans en-tête de navigateur, Google sert des .ttf statiques, une graisse par
# fichier — ce que Flutter et Pillow savent charger.
telecharger() {
  local fichier="$1" requete="$2"
  [ -s "polices/$fichier" ] && return 0
  local url
  url=$(curl -sf --max-time 30 "https://fonts.googleapis.com/css2?family=$requete" \
        | grep -oE 'https://[^)]+\.ttf' | head -1)
  [ -n "$url" ] || { echo "✗ adresse introuvable pour $fichier"; exit 1; }
  curl -sf --max-time 60 -o "polices/$fichier" "$url"
  echo "  ✓ $fichier"
}

echo "▶ Poppins — les titres"
for g in 400:Regular 500:Medium 600:SemiBold 700:Bold 800:ExtraBold; do
  telecharger "Poppins-${g#*:}.ttf" "Poppins:wght@${g%%:*}"
done

echo "▶ Nunito Sans — le texte"
for g in 400:Regular 600:SemiBold 700:Bold 800:ExtraBold; do
  telecharger "NunitoSans-${g#*:}.ttf" "Nunito+Sans:wght@${g%%:*}"
done

echo "✓ polices prêtes dans outils/polices/"
