"""Envoie l'App Bundle sur Google Play depuis cette machine, sans GitHub.

    flutter build appbundle --release
    python3 outils/fiche_play.py            # notes de version du build
    python3 outils/envoyer_play.py [piste]  # alpha (test fermé) par défaut

Il faut la clé du compte de service Play (JSON) : son chemin dans
PLAY_SERVICE_ACCOUNT_JSON_PATH, ou le fichier
android/fastlane/play-service-account.json (ignoré par git, jamais committé).
Et la bibliothèque Google : pip install google-api-python-client google-auth

La version part en brouillon, avec ses notes de version : on la valide
dans la Play Console, comme avec le workflow.
"""

import os
import re
import sys
from pathlib import Path

import httplib2
from google.oauth2 import service_account
from google_auth_httplib2 import AuthorizedHttp
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

PROJET = Path(__file__).resolve().parent.parent
PAQUET = 'com.ismaeldev.keneya'
AAB = PROJET / 'build/app/outputs/bundle/release/app-release.aab'
NOTES = PROJET / 'android/fastlane/metadata/android/fr-FR/changelogs'


def main():
    piste = sys.argv[1] if len(sys.argv) > 1 else 'alpha'
    cle = Path(os.environ.get('PLAY_SERVICE_ACCOUNT_JSON_PATH') or PROJET / 'android/fastlane/play-service-account.json')
    if not cle.exists():
        sys.exit(f'Clé du compte de service introuvable : {cle}')
    if not AAB.exists():
        sys.exit('App Bundle introuvable : lancez d\'abord « flutter build appbundle --release ».')

    # Un bundle plus ancien que la version du pubspec : la construction a échoué.
    if AAB.stat().st_mtime < (PROJET / 'pubspec.yaml').stat().st_mtime:
        sys.exit('L\'App Bundle est plus ancien que pubspec.yaml : relancez « flutter build appbundle --release ».')
    version = re.search(r'^version:\s*([\d.]+)\+(\d+)', (PROJET / 'pubspec.yaml').read_text(), re.M)
    nom, build_ = version.group(1), version.group(2)
    notes_fichier = NOTES / f'{build_}.txt'
    notes = notes_fichier.read_text().strip() if notes_fichier.exists() else ''

    identite = service_account.Credentials.from_service_account_file(
        str(cle), scopes=['https://www.googleapis.com/auth/androidpublisher'])
    # Un App Bundle pèse ~80 Mo : délai long, envoi par morceaux de 8 Mo.
    brut = httplib2.Http(timeout=600)
    # 308 = « morceau reçu, continue » pour un envoi par morceaux, pas une redirection.
    brut.redirect_codes = set(brut.redirect_codes) - {308}
    http = AuthorizedHttp(identite, http=brut)
    play = build('androidpublisher', 'v3', http=http, cache_discovery=False)
    edits = play.edits()

    edit = edits.insert(packageName=PAQUET, body={}).execute()['id']
    print(f'Envoi de {AAB.name} ({AAB.stat().st_size // 1_000_000} Mo)…')
    envoi = edits.bundles().upload(
        packageName=PAQUET, editId=edit,
        media_body=MediaFileUpload(str(AAB), mimetype='application/octet-stream', resumable=True, chunksize=8 * 1024 * 1024),
    )
    bundle = None
    while bundle is None:
        etat, bundle = envoi.next_chunk(num_retries=5)
        if etat:
            print(f'  {int(etat.progress() * 100)} %')
    code = bundle['versionCode']
    edits.tracks().update(packageName=PAQUET, editId=edit, track=piste, body={
        'track': piste,
        'releases': [{
            'name': f'{nom} ({code})',
            'versionCodes': [str(code)],
            'status': 'draft',
            **({'releaseNotes': [{'language': 'fr-FR', 'text': notes}]} if notes else {}),
        }],
    }).execute()
    edits.commit(packageName=PAQUET, editId=edit).execute()
    print(f'✓ {nom} (build {code}) envoyée sur la piste « {piste} », en brouillon : à valider dans la Play Console.')


if __name__ == '__main__':
    main()
