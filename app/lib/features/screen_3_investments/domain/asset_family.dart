enum AssetFamily {
  governmentBond,
  bankFixedIncome,
  corporateBond,
  realEstateVehicle,
  equity,
  etf,
  crypto,
  otherManual;

  String get storageValue => switch (this) {
    governmentBond => 'government_bond',
    bankFixedIncome => 'bank_fixed_income',
    corporateBond => 'corporate_bond',
    realEstateVehicle => 'real_estate_vehicle',
    equity => 'equity',
    etf => 'etf',
    crypto => 'crypto',
    otherManual => 'other_manual',
  };

  String get label => switch (this) {
    governmentBond => 'Títulos públicos',
    bankFixedIncome => 'Renda fixa bancária',
    corporateBond => 'Títulos empresariais',
    realEstateVehicle => 'Imobiliários',
    equity => 'Ações',
    etf => 'ETFs',
    crypto => 'Criptoativos',
    otherManual => 'Cadastro manual',
  };

  static AssetFamily fromStorage(String value) => values.firstWhere(
    (item) => item.storageValue == value,
    orElse: () => otherManual,
  );
}
