# Reprise : style Ngoni Caisse appliqué à Keneya

Objectif : donner à Keneya le style de la famille Ngoni (comme Ngoni Tontine et
Ngoni Atelier) : bleu nuit `#0F2A5C` et jaune `#FFCC1F`, fond `#EEF2F8`,
titres Poppins et texte Nunito Sans, cartes blanches à ombre bleutée, carte de
tête en dégradé bleu nuit avec accents jaunes.

Références :
- Thème source : `../../ngoni_pay/NGONI-PAY-FLUTTER/lib/core/theme/app_theme.dart`
- Tontine : commits `60b317f` (identité) et `c264f00` (cartes, Mon compte) dans
  `../../tontine/ngoni-tontine` (`lib/theme.dart`, `lib/ui.dart`)
- Atelier : commits `e6b4657` et `078797d` (`CarteMarque`, `AvatarMarque`
  dans `lib/core/ui/kit.dart`) dans `../../atelier/atelier-mobile`

## Fait (non commité ; `flutter analyze` propre, APK debug lancé sur émulateur)
- `kcolors.dart` : palette Ngoni + `kJaune`, `kJauneDoux`, `kBorderStrong`,
  `kPuce`, `kTeal`, `kViolet`, `heroGradient`, `softShadow()`.
- `app_theme.dart` : thème recopié de Ngoni Caisse.
- `app_style.dart` : Poppins si taille ≥ 18 ou graisse ≥ w700, sinon Nunito Sans.
- `lib/common/widgets/carte_marque.dart` : `CarteMarque` (dégradé + halo) et
  `AvatarMarque` (icône dans un anneau jaune). Utilisés par `_WelcomeHeader`,
  la carte profil (puces à icône jaune) et la caisse (total en jaune).
- Couleurs en dur remplacées : `api_module_screen_view.dart`, `panel.dart`,
  `module_card.dart` (→ `softShadow()`), bandeaux de `home_screen.dart`.
- Accueil, connexion, onboarding : `heroGradient`, bouton principal et point
  de page actif en jaune, logo de l'accueil en `AvatarMarque`.
- `role_ui.dart` : médecin bleu clair, pharmacien sarcelle, laborantin violet.
- Splash : `pubspec.yaml` (bleu nuit) puis `dart run flutter_native_splash:create`
  (Android, iOS, web régénérés) ; `web/manifest.json` theme_color.

## Reste à faire
1. Vérifier à l'écran les cartes de tête après connexion (tableau de bord,
   profil, caisse) : pas d'identifiants pour la vérif faite sur émulateur.
2. Icône de l'app et logo de la carte de connexion encore indigo/sarcelle
   (`assets/images/logo_keneya_plus_icon.png`, `app_icon_1024.png`) : à refaire
   pour l’icône Ngoni Santé (nom décidé le 26/10/2026, voir
   `NGONI-SANTE-CAHIER-DES-CHARGES.md`).
3. Faire de même pour `../keneya_patient` (`lib/core/theme.dart`, 14 fichiers).
