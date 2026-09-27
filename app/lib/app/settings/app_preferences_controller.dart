import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/app_locale.dart';
import '../../core/money/money.dart';

enum RegionPreference {
  automatic,
  brazil,
  unitedStates,
  germany,
  france,
  india,
}

enum WeekStartPreference { automatic, sunday, monday }

enum AgendaReminderPreference {
  atTime,
  oneDayAndAtTime,
  threeDaysOneDayAndAtTime,
}

final class AppPreferencesController extends ChangeNotifier {
  AppPreferencesController(this._preferences, Locale deviceLocale)
    : _locale = _loadLocale(_preferences, deviceLocale),
      _themeMode = _loadThemeMode(_preferences),
      _currency = _loadCurrency(_preferences, deviceLocale),
      _region = _enumValue(
        _preferences,
        'regional.region',
        RegionPreference.values,
        RegionPreference.automatic,
      ),
      _weekStart = _enumValue(
        _preferences,
        'agenda.week_start',
        WeekStartPreference.values,
        WeekStartPreference.automatic,
      ),
      _agendaReminder = _enumValue(
        _preferences,
        'agenda.default_reminder',
        AgendaReminderPreference.values,
        AgendaReminderPreference.threeDaysOneDayAndAtTime,
      ),
      _hideValuesOnOpen = _preferences.getBool(_hideValuesOnOpenKey) ?? false,
      _hideValuesOnBackground =
          _preferences.getBool(_hideValuesOnBackgroundKey) ?? false,
      _protectRecentApps =
          _preferences.getBool('privacy.protect_recents') ?? true,
      _blockScreenshots =
          _preferences.getBool('privacy.block_screenshots') ?? false,
      _hapticsEnabled = _preferences.getBool('feedback.haptics') ?? true,
      _agendaRemindersEnabled =
          _preferences.getBool('notifications.agenda') ?? true,
      _monthlyClosingNotifications =
          _preferences.getBool('notifications.monthly_closing') ?? false,
      _recurringEntryNotifications =
          _preferences.getBool('notifications.recurring_entries') ?? false,
      _monthlyReportNotifications =
          _preferences.getBool('notifications.monthly_report') ?? false,
      _subscriptionNotifications =
          _preferences.getBool('notifications.subscription') ?? true;

  static const _localeKey = 'regional.locale';
  static const _localeManualKey = 'regional.locale_manual';
  static const _currencyKey = 'regional.currency';
  static const _themeKey = 'appearance.theme';
  static const _hideValuesOnOpenKey = 'privacy.hide_on_open.v2';
  static const _hideValuesOnBackgroundKey = 'privacy.hide_on_background.v2';

  final SharedPreferences _preferences;
  SupportedAppLocale _locale;
  ThemeMode _themeMode;
  CurrencyCode _currency;
  RegionPreference _region;
  WeekStartPreference _weekStart;
  AgendaReminderPreference _agendaReminder;
  bool _hideValuesOnOpen;
  bool _hideValuesOnBackground;
  bool _protectRecentApps;
  bool _blockScreenshots;
  bool _hapticsEnabled;
  bool _agendaRemindersEnabled;
  bool _monthlyClosingNotifications;
  bool _recurringEntryNotifications;
  bool _monthlyReportNotifications;
  bool _subscriptionNotifications;

  SupportedAppLocale get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  CurrencyCode get currency => _currency;
  RegionPreference get region => _region;
  WeekStartPreference get weekStart => _weekStart;
  AgendaReminderPreference get agendaReminder => _agendaReminder;
  bool get hideValuesOnOpen => _hideValuesOnOpen;
  bool get hideValuesOnBackground => _hideValuesOnBackground;
  bool get protectRecentApps => _protectRecentApps;
  bool get blockScreenshots => _blockScreenshots;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get agendaRemindersEnabled => _agendaRemindersEnabled;
  bool get monthlyClosingNotifications => _monthlyClosingNotifications;
  bool get recurringEntryNotifications => _recurringEntryNotifications;
  bool get monthlyReportNotifications => _monthlyReportNotifications;
  bool get subscriptionNotifications => _subscriptionNotifications;

  Future<void> updateRegional({
    required SupportedAppLocale locale,
    required RegionPreference region,
    required CurrencyCode currency,
    required WeekStartPreference weekStart,
  }) async {
    _locale = locale;
    _region = region;
    _currency = currency;
    _weekStart = weekStart;
    notifyListeners();
    await Future.wait([
      _preferences.setString(_localeKey, locale.tag),
      _preferences.setBool(_localeManualKey, true),
      _preferences.setString('regional.region', region.name),
      _preferences.setString(_currencyKey, currency.isoCode),
      _preferences.setString('agenda.week_start', weekStart.name),
    ]);
  }

  Future<void> updateLocale(SupportedAppLocale value) => updateRegional(
    locale: value,
    region: _region,
    currency: _currency,
    weekStart: _weekStart,
  );
  Future<void> updateCurrency(CurrencyCode value) => updateRegional(
    locale: _locale,
    region: _region,
    currency: value,
    weekStart: _weekStart,
  );

  Future<void> updateThemeMode(ThemeMode value) async {
    _themeMode = value;
    notifyListeners();
    await _preferences.setString(_themeKey, value.name);
  }

  Future<void> updateHideValuesOnOpen(bool value) =>
      _setBool(_hideValuesOnOpenKey, value, () => _hideValuesOnOpen = value);
  Future<void> updateHideValuesOnBackground(bool value) => _setBool(
    _hideValuesOnBackgroundKey,
    value,
    () => _hideValuesOnBackground = value,
  );
  Future<void> updateProtectRecentApps(bool value) => _setBool(
    'privacy.protect_recents',
    value,
    () => _protectRecentApps = value,
  );
  Future<void> updateBlockScreenshots(bool value) => _setBool(
    'privacy.block_screenshots',
    value,
    () => _blockScreenshots = value,
  );
  Future<void> updateHaptics(bool value) =>
      _setBool('feedback.haptics', value, () => _hapticsEnabled = value);
  Future<void> updateAgendaReminders(bool value) => _setBool(
    'notifications.agenda',
    value,
    () => _agendaRemindersEnabled = value,
  );
  Future<void> updateMonthlyClosingNotifications(bool value) => _setBool(
    'notifications.monthly_closing',
    value,
    () => _monthlyClosingNotifications = value,
  );
  Future<void> updateRecurringEntryNotifications(bool value) => _setBool(
    'notifications.recurring_entries',
    value,
    () => _recurringEntryNotifications = value,
  );
  Future<void> updateMonthlyReportNotifications(bool value) => _setBool(
    'notifications.monthly_report',
    value,
    () => _monthlyReportNotifications = value,
  );
  Future<void> updateSubscriptionNotifications(bool value) => _setBool(
    'notifications.subscription',
    value,
    () => _subscriptionNotifications = value,
  );

  Future<void> updateAgendaReminder(AgendaReminderPreference value) async {
    _agendaReminder = value;
    notifyListeners();
    await _preferences.setString('agenda.default_reminder', value.name);
  }

  Future<void> _setBool(String key, bool value, VoidCallback assign) async {
    assign();
    notifyListeners();
    await _preferences.setBool(key, value);
  }

  static T _enumValue<T extends Enum>(
    SharedPreferences preferences,
    String key,
    List<T> values,
    T fallback,
  ) {
    final stored = preferences.getString(key);
    return values.firstWhere(
      (value) => value.name == stored,
      orElse: () => fallback,
    );
  }

  static SupportedAppLocale _loadLocale(
    SharedPreferences preferences,
    Locale deviceLocale,
  ) {
    final manuallyChosen = preferences.getBool(_localeManualKey) ?? false;
    if (manuallyChosen) {
      return SupportedAppLocale.fromTag(preferences.getString(_localeKey));
    }
    return SupportedAppLocale.resolve(deviceLocale);
  }

  static ThemeMode _loadThemeMode(SharedPreferences preferences) =>
      ThemeMode.values.firstWhere(
        (value) => value.name == preferences.getString(_themeKey),
        orElse: () => ThemeMode.system,
      );

  static CurrencyCode _loadCurrency(
    SharedPreferences preferences,
    Locale deviceLocale,
  ) {
    final stored = preferences.getString(_currencyKey);
    if (stored != null) {
      return CurrencyCode.values.firstWhere(
        (value) => value.isoCode == stored,
        orElse: () => CurrencyCode.brl,
      );
    }
    return switch (deviceLocale.countryCode) {
      'US' => CurrencyCode.usd,
      'DE' || 'FR' => CurrencyCode.eur,
      'IN' => CurrencyCode.inr,
      _ => CurrencyCode.brl,
    };
  }
}
