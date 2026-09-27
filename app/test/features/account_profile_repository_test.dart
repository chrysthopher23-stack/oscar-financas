import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/features/screen_10_account/data/local_account_profile_repository.dart';
import 'package:oscar_financas/features/screen_10_account/domain/account_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'profile details and communication preference persist locally',
    () async {
      SharedPreferences.setMockInitialValues({});
      const repository = LocalAccountProfileRepository();
      final expectedBirthDate = DateTime(1983, 11, 23);

      await repository.save(
        AccountProfile(
          name: 'Steve Oscar',
          birthDate: expectedBirthDate,
          receiveCommunications: true,
        ),
      );

      final actual = await repository.load();
      expect(actual.name, 'Steve Oscar');
      expect(actual.birthDate, expectedBirthDate);
      expect(actual.receiveCommunications, isTrue);
    },
  );
}
