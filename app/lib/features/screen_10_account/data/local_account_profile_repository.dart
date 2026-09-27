import 'package:shared_preferences/shared_preferences.dart';

import '../domain/account_profile.dart';

final class LocalAccountProfileRepository implements AccountProfileRepository {
  const LocalAccountProfileRepository();

  static const _nameKey = 'account.profile.name';
  static const _birthDateKey = 'account.profile.birth_date';
  static const _communicationsKey = 'account.profile.communications';

  @override
  Future<AccountProfile> load() async {
    final preferences = await SharedPreferences.getInstance();
    final storedDate = preferences.getString(_birthDateKey);
    final parsedDate = storedDate == null
        ? null
        : DateTime.tryParse(storedDate);
    return AccountProfile(
      name: preferences.getString(_nameKey) ?? '',
      birthDate: parsedDate == null
          ? null
          : DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      receiveCommunications: preferences.getBool(_communicationsKey) ?? false,
    );
  }

  @override
  Future<void> save(AccountProfile profile) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_nameKey, profile.name.trim());
    final birthDate = profile.birthDate;
    if (birthDate == null) {
      await preferences.remove(_birthDateKey);
    } else {
      final month = birthDate.month.toString().padLeft(2, '0');
      final day = birthDate.day.toString().padLeft(2, '0');
      await preferences.setString(
        _birthDateKey,
        '${birthDate.year}-$month-$day',
      );
    }
    await preferences.setBool(
      _communicationsKey,
      profile.receiveCommunications,
    );
  }
}
