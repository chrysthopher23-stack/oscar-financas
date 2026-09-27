abstract interface class AgendaExtraIncomePort {
  Future<void> registerConfirmedReceipt({
    required String eventId,
    required String yearMonth,
    required String description,
    required int amountMinor,
  });
}
