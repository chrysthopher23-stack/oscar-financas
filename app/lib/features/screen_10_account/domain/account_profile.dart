final class AccountProfile {
  const AccountProfile({
    this.name = '',
    this.birthDate,
    this.receiveCommunications = false,
  });

  final String name;
  final DateTime? birthDate;
  final bool receiveCommunications;
}

abstract interface class AccountProfileRepository {
  Future<AccountProfile> load();
  Future<void> save(AccountProfile profile);
}
