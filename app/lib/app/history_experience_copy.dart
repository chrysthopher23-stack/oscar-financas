import '../core/localization/app_locale.dart';

final class HistoryExperienceCopy {
  const HistoryExperienceCopy(this.locale);
  final SupportedAppLocale locale;

  String get welcomeTitle => _pick(
    'Bem-vindo ao Oscar Finanças',
    'Welcome to Oscar Finanças',
    'Willkommen bei Oscar Finanças',
    'Bienvenue sur Oscar Finanças',
    'Oscar Finanças में आपका स्वागत है',
  );
  String get welcomeBody => _pick(
    'Deixamos registros para você explorar o aplicativo com calma. Navegue pelas telas e veja como suas informações se conectam. Quando quiser começar com seus próprios dados, vá a Configurações e escolha “Resetar todo o histórico”.',
    'We have left some records for you to explore the app at your own pace. Browse the screens and see how everything connects. When you are ready to use your own data, go to Settings and choose “Reset all history”.',
    'Wir haben einige Einträge hinterlegt, damit Sie die App in Ruhe erkunden können. Sehen Sie sich die Bereiche und ihre Zusammenhänge an. Wenn Sie mit Ihren eigenen Daten beginnen möchten, wählen Sie unter Einstellungen „Gesamten Verlauf zurücksetzen“.',
    'Nous avons laissé quelques données pour vous permettre de découvrir l’application à votre rythme. Parcourez les écrans pour comprendre leurs liens. Quand vous serez prêt à utiliser vos propres données, choisissez « Réinitialiser tout l’historique » dans les paramètres.',
    'ऐप को समझने के लिए हमने कुछ रिकॉर्ड रखे हैं। स्क्रीन देखें और जानें कि जानकारी आपस में कैसे जुड़ती है। अपने डेटा से शुरू करने के लिए सेटिंग्स में “पूरा इतिहास रीसेट करें” चुनें।',
  );
  String get explore => _pick(
    'Explorar o aplicativo',
    'Explore the app',
    'App erkunden',
    'Découvrir l’application',
    'ऐप देखें',
  );
  String get warning => _pick(
    'Atenção: esta ação apaga permanentemente todos os registros financeiros, ganhos extras, investimentos, objetivos e compromissos. Não é possível desfazê-la.',
    'Caution: this permanently deletes all financial records, extra income, investments, goals, and calendar events. It cannot be undone.',
    'Achtung: Dadurch werden alle Finanzdaten, Zusatzeinnahmen, Anlagen, Ziele und Termine dauerhaft gelöscht. Dies kann nicht rückgängig gemacht werden.',
    'Attention : cette action supprime définitivement toutes les données financières, revenus supplémentaires, investissements, objectifs et événements. Elle est irréversible.',
    'सावधान: इससे सभी वित्तीय रिकॉर्ड, अतिरिक्त आय, निवेश, लक्ष्य और कैलेंडर कार्यक्रम हमेशा के लिए मिट जाएंगे। इसे वापस नहीं किया जा सकता।',
  );
  String get reset => _pick(
    'Resetar todo o histórico',
    'Reset all history',
    'Gesamten Verlauf zurücksetzen',
    'Réinitialiser tout l’historique',
    'पूरा इतिहास रीसेट करें',
  );
  String get confirmTitle => _pick(
    'Começar do zero?',
    'Start from scratch?',
    'Neu beginnen?',
    'Repartir de zéro ?',
    'नए सिरे से शुरू करें?',
  );
  String get confirmBody => _pick(
    'Todos os registros serão apagados, inclusive os exemplos. Sua conta, idioma e preferências serão mantidos. Os exemplos não voltarão automaticamente.',
    'All records, including the examples, will be deleted. Your account, language, and preferences will remain. The examples will not return automatically.',
    'Alle Einträge, einschließlich der Beispiele, werden gelöscht. Konto, Sprache und Einstellungen bleiben erhalten. Die Beispiele werden nicht automatisch wiederhergestellt.',
    'Toutes les données, y compris les exemples, seront supprimées. Votre compte, votre langue et vos préférences seront conservés. Les exemples ne reviendront pas automatiquement.',
    'उदाहरणों सहित सभी रिकॉर्ड मिट जाएंगे। आपका खाता, भाषा और प्राथमिकताएं बनी रहेंगी। उदाहरण अपने आप वापस नहीं आएंगे।',
  );
  String get cancel =>
      _pick('Cancelar', 'Cancel', 'Abbrechen', 'Annuler', 'रद्द करें');
  String get done => _pick(
    'Histórico apagado. Você pode começar do zero.',
    'History cleared. You can start fresh.',
    'Verlauf gelöscht. Sie können neu beginnen.',
    'Historique effacé. Vous pouvez repartir de zéro.',
    'इतिहास मिटा दिया गया। अब आप नए सिरे से शुरू कर सकते हैं।',
  );
  String get failed => _pick(
    'Não foi possível apagar o histórico. Tente novamente.',
    'Could not clear history. Please try again.',
    'Der Verlauf konnte nicht gelöscht werden. Bitte erneut versuchen.',
    'Impossible d’effacer l’historique. Veuillez réessayer.',
    'इतिहास नहीं मिट सका। फिर से कोशिश करें।',
  );

  String _pick(String pt, String en, String de, String fr, String hi) =>
      switch (locale) {
        SupportedAppLocale.ptBr => pt,
        SupportedAppLocale.enUs => en,
        SupportedAppLocale.deDe => de,
        SupportedAppLocale.frFr => fr,
        SupportedAppLocale.hiIn => hi,
      };
}
