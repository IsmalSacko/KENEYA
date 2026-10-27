# Ngoni Santé pour Windows

La version Windows se construit **sur un PC Windows** (Flutter ne fabrique
pas d'exécutable Windows depuis Linux).

## Une fois

1. Installer Flutter, puis Visual Studio 2022 avec « Développement Desktop
   en C++ ».
2. `flutter doctor` : la ligne Windows doit être verte.

## Microsoft Store (recommandé : aucun avertissement)

1. Créer le compte sur l'Espace développeur (Partner Center), réserver le nom
   « Ngoni Santé ».
2. Dans Partner Center › l'app › Identité du produit : recopier
   `Package/Identity/Name` et `Package/Identity/Publisher` dans
   `msix_config` (`identity_name`, `publisher`) du `pubspec.yaml`.
3. Construire le paquet :
   ```
   flutter build windows --release
   dart run msix:create
   ```
   Le fichier `build\windows\x64\runner\Release\keneya_plus.msix` (ou
   `ngoni_sante.msix`) part dans Partner Center › Packages. Microsoft le signe.

## Installateur .exe (hors Store)

```
flutter build windows --release
```
Puis ouvrir `windows\installeur\ngoni_sante.iss` dans Inno Setup et
« Compile ». Sans certificat de signature, Windows prévient au premier
lancement.

## Sur ordinateur

- Le scan se fait avec une **douchette USB** (elle tape le code) ou en
  collant le code : il n'y a pas de lecture par caméra sous Windows.
- L'impression thermique Bluetooth reste à essayer sur un PC.
