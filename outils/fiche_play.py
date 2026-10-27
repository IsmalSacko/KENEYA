"""Range la fiche Play (store/) au format de fastlane, qui l'envoie avec l'app.

    python3 outils/fiche_play.py

Lit `store/FICHE.md` (les blocs de code, dans l'ordre : nom, description
courte, description complète, notes de version) et copie les visuels de
`store/` dans `android/fastlane/metadata/android/fr-FR/`. Les notes de
version portent le numéro de build de `pubspec.yaml`.
"""

import re
import shutil
from pathlib import Path

PROJET = Path(__file__).resolve().parent.parent
STORE = PROJET / 'store'
SORTIE = PROJET / 'android/fastlane/metadata/android/fr-FR'


def main():
    fiche = (STORE / 'FICHE.md').read_text()
    nom, courte, complete, notes = re.findall(r'```\n(.*?)\n```', fiche, re.S)[:4]
    build = re.search(r'^version: .*\+(\d+)$', (PROJET / 'pubspec.yaml').read_text(), re.M).group(1)

    if SORTIE.exists():
        shutil.rmtree(SORTIE)
    (SORTIE / 'changelogs').mkdir(parents=True)
    (SORTIE / 'title.txt').write_text(nom.strip() + '\n')
    (SORTIE / 'short_description.txt').write_text(courte.strip() + '\n')
    (SORTIE / 'full_description.txt').write_text(complete.strip() + '\n')
    (SORTIE / f'changelogs/{build}.txt').write_text(notes.strip() + '\n')

    images = SORTIE / 'images'
    images.mkdir()
    shutil.copy(STORE / 'icone-512.png', images / 'icon.png')
    shutil.copy(STORE / 'image-presentation-1024x500.png', images / 'featureGraphic.png')
    for dossier, cible in [
        ('telephone', 'phoneScreenshots'),
        ('tablette-7', 'sevenInchScreenshots'),
        ('tablette-10', 'tenInchScreenshots'),
    ]:
        (images / cible).mkdir()
        for png in sorted((STORE / dossier).glob('*.png')):
            shutil.copy(png, images / cible / png.name)

    print(f'✓ fiche prête pour fastlane (build {build}) : {SORTIE.relative_to(PROJET)}')


if __name__ == '__main__':
    main()
