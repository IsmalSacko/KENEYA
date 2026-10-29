import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../common/utils/kcolors.dart';
import '../../compte/compte_controller.dart';
import '../../compte/compte_models.dart';
import '../../controllers/auth_controller.dart';
import 'cadre_acces.dart';

/// Une personne crée son établissement : elle choisit son métier (le profil
/// règle les modules, comme l'activité dans Ngoni Caisse), puis son nom.
class CreerEtablissementScreen extends StatefulWidget {
  const CreerEtablissementScreen({super.key});

  @override
  State<CreerEtablissementScreen> createState() =>
      _CreerEtablissementScreenState();
}

class _CreerEtablissementScreenState extends State<CreerEtablissementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _autorisation = TextEditingController();
  final _responsable = TextEditingController();
  String? _profil;

  static const _icones = <String, IconData>{
    'cabinet_medical': Icons.medical_services_outlined,
    'centre_sante': Icons.local_hospital_outlined,
    'clinique': Icons.apartment_outlined,
    'pharmacie': Icons.local_pharmacy_outlined,
    'depot_medicaments': Icons.inventory_2_outlined,
    'laboratoire': Icons.science_outlined,
    'maternite': Icons.pregnant_woman_outlined,
    'cabinet_dentaire': Icons.mood_outlined,
  };

  @override
  void dispose() {
    _nom.dispose();
    _autorisation.dispose();
    _responsable.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    final limite = context.read<CompteController>().limite;
    if (limite != null && limite.atteinte) {
      afficherMessage(
        context,
        'Votre formule permet ${limite.max} établissements. Passez à la formule au-dessus pour en ouvrir plus.',
      );
      return;
    }
    if (_profil == null) {
      afficherMessage(context, 'Choisissez le type d’établissement.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final compte = context.read<CompteController>();
    final ok = await compte.creerEtablissement(
      nom: _nom.text.trim(),
      profil: _profil!,
      autorisation: _autorisation.text.trim(),
      responsable: _responsable.text.trim(),
      auth: context.read<AuthController>(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      afficherMessage(
        context,
        'Demande envoyée : configurez votre établissement dès maintenant. Les patients le verront après vérification par Ngoni Santé.',
      );
    } else {
      afficherMessage(context, compte.erreur ?? 'Création impossible.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final compte = context.watch<CompteController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Créer mon établissement')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Quel est votre établissement ?',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Kolors.kTextHigh,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ngoni Santé s’adapte à votre métier : ses modules se règlent ensuite dans Réglages.',
              style: TextStyle(color: Kolors.kTextMuted),
            ),
            if (compte.limite
                case LimiteEtablissements(max: final int max) && final l) ...[
              const SizedBox(height: 6),
              Text(
                l.atteinte
                    ? 'Votre formule permet $max établissements : vous les avez. Passez à la formule au-dessus pour en ouvrir plus.'
                    : 'Établissements : ${l.crees} sur $max, il vous en reste ${l.restants} (s${l.explication.substring(1)}). Chacun paie son abonnement.',
                style: TextStyle(
                  color: l.atteinte ? Kolors.kRed : Kolors.kTextMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            for (final profil in compte.profils) ...[
              _CarteProfil(
                icone: _icones[profil.code] ?? Icons.local_hospital_outlined,
                titre: profil.label,
                texte: profil.description,
                choisi: _profil == profil.code,
                onTap: () => setState(() => _profil = profil.code),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            TextFormField(
              controller: _nom,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nom de l’établissement',
                hintText: 'ex. CSCom de Hamdallaye',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (v) =>
                  (v ?? '').trim().length < 2 ? 'Indiquez le nom' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _autorisation,
              decoration: const InputDecoration(
                labelText: 'N° d’autorisation ou d’agrément (facultatif)',
                hintText: 'ex. arrêté d’ouverture, licence de pharmacie',
                helperText: 'Vous pourrez l’ajouter plus tard dans Réglages.',
                prefixIcon: Icon(Icons.verified_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _responsable,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Responsable (nom et titre)',
                hintText: 'ex. Dr Fatoumata Diarra, médecin-chef',
                prefixIcon: Icon(Icons.person_pin_outlined),
              ),
              validator: (v) => (v ?? '').trim().length < 3
                  ? 'Indiquez le responsable'
                  : null,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ngoni Santé vérifie chaque établissement avant de le montrer aux patients. En attendant, vous pouvez déjà tout configurer.',
              style: TextStyle(color: Kolors.kTextMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 18),
            BoutonAcces(
              label: 'Envoyer la demande et ouvrir mon espace',
              chargement: compte.chargement,
              onPressed: _valider,
            ),
          ],
        ),
      ),
    );
  }
}

class _CarteProfil extends StatelessWidget {
  const _CarteProfil({
    required this.icone,
    required this.titre,
    required this.texte,
    required this.choisi,
    required this.onTap,
  });

  final IconData icone;
  final String titre;
  final String texte;
  final bool choisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Kolors.kSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: choisi ? Kolors.kJaune : Kolors.kBorder,
              width: choisi ? 2 : 1,
            ),
            boxShadow: Kolors.softShadow(strength: 0.6),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: choisi ? Kolors.kPrimary : Kolors.kSecondaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icone,
                  color: choisi ? Kolors.kJaune : Kolors.kPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Kolors.kTextHigh,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      texte,
                      style: const TextStyle(
                        color: Kolors.kTextMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (choisi)
                const Icon(Icons.check_circle_rounded, color: Kolors.kPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
