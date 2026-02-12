String paymentMethodLabel(String method) {
  switch (method) {
    case 'orange_money':
      return 'Orange Money (Mali)';
    case 'moov_money':
      return 'Moov Money (Mali)';
    case 'wave':
      return 'Wave';
    case 'card':
      return 'Carte Bancaire';
    case 'cash':
      return 'Espèces';
    default:
      return method;
  }
}

String paymentStatusLabel(String status) {
  switch (status) {
    case 'success':
      return 'Paiement réussi';
    case 'pending':
      return 'En attente';
    case 'failed':
      return 'Échec';
    default:
      return status;
  }
}