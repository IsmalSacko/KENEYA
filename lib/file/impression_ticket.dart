import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../core/offline/local_store.dart';
import 'file_models.dart';

/// Ticket de file imprimé sur une imprimante thermique Bluetooth (58 mm) :
/// le code en grand, le service, l'heure, et le QR qui ouvre le suivi en
/// direct (même sans l'app).
///
/// Comme dans Ngoni Caisse : jamais vérifié ici contre une vraie imprimante
/// (pas de matériel Bluetooth dans cet environnement) ; les octets ESC/POS
/// suivent la norme, l'appairage reste à valider sur site.
class ImpressionTicket {
  static const _cleImprimante = 'imprimante_tickets';

  static const aucuneImprimante =
      'Aucune imprimante trouvée : dans Paramètres › Bluetooth, touchez le nom de l’imprimante (code 0000), puis réessayez.';

  /// Message si l'on ne peut pas encore imprimer ; null si tout est prêt.
  static Future<String?> obstacle() async {
    if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) {
      return 'Autorisez Ngoni Santé à utiliser le Bluetooth (Paramètres › Applications › Ngoni Santé › Autorisations › Appareils à proximité).';
    }
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      return 'Le Bluetooth du téléphone est éteint : activez-le, puis réessayez.';
    }
    return null;
  }

  static Future<List<BluetoothInfo>> imprimantes() =>
      PrintBluetoothThermal.pairedBluetooths;

  /// Adresse de l'imprimante choisie sur cet appareil.
  static String? get imprimanteChoisie =>
      LocalStore.read<String>(_cleImprimante);

  static Future<void> choisir(String adresseMac) =>
      LocalStore.write(_cleImprimante, adresseMac);

  static Future<bool> imprimer(
    TicketFile ticket, {
    String? etablissement,
  }) async {
    return envoyer(await octetsTicket(ticket, etablissement: etablissement));
  }

  /// Envoie des octets ESC/POS à l'imprimante choisie (ticket, étiquette…).
  static Future<bool> envoyer(List<int> octets) async {
    final adresse = imprimanteChoisie;
    if (adresse == null) return false;
    if (!await PrintBluetoothThermal.connect(macPrinterAddress: adresse)) {
      return false;
    }
    final envoye = await PrintBluetoothThermal.writeBytes(octets);
    await PrintBluetoothThermal.disconnect;
    return envoye;
  }

  static Future<List<int>> octetsTicket(
    TicketFile ticket, {
    String? etablissement,
  }) async {
    final g = Generator(PaperSize.mm58, await CapabilityProfile.load());
    final heure = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(ticket.emisAt ?? DateTime.now());
    const centre = PosStyles(align: PosAlign.center);

    return [
      ...g.reset(),
      ...g.text(
        sansAccents(etablissement ?? ticket.etablissementNom),
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
      ...g.text(sansAccents(ticket.serviceNom), styles: centre),
      ...g.hr(ch: '-'),
      ...g.text(
        ticket.code,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size4,
          width: PosTextSize.size4,
        ),
        linesAfter: 1,
      ),
      if (ticket.prioritaire)
        ...g.text(
          sansAccents(ticket.prioriteLabel.toUpperCase()),
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            reverse: true,
          ),
        ),
      if (ticket.position != null)
        ...g.text(
          ticket.position == 0
              ? 'Vous etes le prochain'
              : '${ticket.position} personne(s) avant vous',
          styles: centre,
        ),
      ...g.text(heure, styles: centre),
      ...g.hr(ch: '-'),
      if (ticket.suiviUrl.isNotEmpty) ...[
        ...g.qrcode(ticket.suiviUrl, size: QRSize.size5),
        ...g.text('Scannez pour suivre votre tour', styles: centre),
      ],
      ...g.text('Ngoni Sante', styles: centre),
      ...g.feed(2),
      ...g.cut(),
    ];
  }

  static String sansAccents(String texte) {
    const avec = 'àâäáãçéèêëíìîïñóòôöõúùûüýÿÀÂÄÁÃÇÉÈÊËÍÌÎÏÑÓÒÔÖÕÚÙÛÜÝ’';
    const sans = "aaaaaceeeeiiiinooooouuuuyyAAAAACEEEEIIIINOOOOOUUUUY'";
    final sb = StringBuffer();
    for (final c in texte.split('')) {
      final i = avec.indexOf(c);
      sb.write(i < 0 ? c : sans[i]);
    }
    return sb.toString();
  }
}
