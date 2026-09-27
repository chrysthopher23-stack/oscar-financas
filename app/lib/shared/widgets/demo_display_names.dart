import 'package:flutter/material.dart';

import '../../core/localization/app_locale.dart';

/// Presentation names for bundled examples. Stored records retain their titles.
String demoFinancialTitle(BuildContext context, String id, String title) {
  final locale = SupportedAppLocale.resolve(Localizations.localeOf(context));
  final key = id.startsWith('demo:financial:')
      ? id.split(':').elementAtOrNull(2)
      : null;
  if (key != null) {
    final labels = _financialNames[key];
    if (labels != null) return labels[locale] ?? title;
  }
  if (id.contains('objective:') &&
      (title.startsWith('Aporte · ') || title.startsWith('Contribution · '))) {
    final name = title.split(' · ').skip(1).join(' · ');
    final localized = demoGoalName(context, name);
    final prefix = _contributionPrefix[locale] ?? 'Aporte · ';
    return '$prefix$localized';
  }
  return title;
}

String demoGoalName(BuildContext context, String name) {
  if (name == 'Reserva de emergência' || name == 'Emergency fund') {
    final locale = SupportedAppLocale.resolve(Localizations.localeOf(context));
    return _emergencyFund[locale] ?? name;
  }
  if (name != 'Meus primeiros 100K' && name != 'My First 100K') return name;
  final locale = SupportedAppLocale.resolve(Localizations.localeOf(context));
  return _first100k[locale] ?? name;
}

const _contributionPrefix = <SupportedAppLocale, String>{
  SupportedAppLocale.ptBr: 'Aporte · ',
  SupportedAppLocale.enUs: 'Contribution · ',
  SupportedAppLocale.deDe: 'Beitrag · ',
  SupportedAppLocale.frFr: 'Versement · ',
  SupportedAppLocale.hiIn: 'योगदान · ',
};

const _first100k = <SupportedAppLocale, String>{
  SupportedAppLocale.ptBr: 'Meus primeiros 100K',
  SupportedAppLocale.enUs: 'My First 100K',
  SupportedAppLocale.deDe: 'Meine ersten 100.000',
  SupportedAppLocale.frFr: 'Mes premiers 100 000',
  SupportedAppLocale.hiIn: 'मेरे पहले 100 हज़ार',
};

const _emergencyFund = <SupportedAppLocale, String>{
  SupportedAppLocale.ptBr: 'Reserva de emergência',
  SupportedAppLocale.enUs: 'Emergency fund',
  SupportedAppLocale.deDe: 'Notgroschen',
  SupportedAppLocale.frFr: "Fonds d'urgence",
  SupportedAppLocale.hiIn: 'आपातकालीन निधि',
};

const _financialNames = <String, Map<SupportedAppLocale, String>>{
  'salary': {
    SupportedAppLocale.ptBr: 'Salário',
    SupportedAppLocale.enUs: 'Salary',
    SupportedAppLocale.deDe: 'Gehalt',
    SupportedAppLocale.frFr: 'Salaire',
    SupportedAppLocale.hiIn: 'वेतन',
  },
  'rent': {
    SupportedAppLocale.ptBr: 'Aluguel',
    SupportedAppLocale.enUs: 'Rent',
    SupportedAppLocale.deDe: 'Miete',
    SupportedAppLocale.frFr: 'Loyer',
    SupportedAppLocale.hiIn: 'किराया',
  },
  'utilities': {
    SupportedAppLocale.ptBr: 'Contas da casa',
    SupportedAppLocale.enUs: 'Household bills',
    SupportedAppLocale.deDe: 'Haushaltsrechnungen',
    SupportedAppLocale.frFr: 'Factures du foyer',
    SupportedAppLocale.hiIn: 'घरेलू बिल',
  },
  'groceries': {
    SupportedAppLocale.ptBr: 'Mercado',
    SupportedAppLocale.enUs: 'Groceries',
    SupportedAppLocale.deDe: 'Lebensmittel',
    SupportedAppLocale.frFr: 'Courses',
    SupportedAppLocale.hiIn: 'किराने का सामान',
  },
  'transport': {
    SupportedAppLocale.ptBr: 'Transporte',
    SupportedAppLocale.enUs: 'Transportation',
    SupportedAppLocale.deDe: 'Transport',
    SupportedAppLocale.frFr: 'Transport',
    SupportedAppLocale.hiIn: 'परिवहन',
  },
  'health': {
    SupportedAppLocale.ptBr: 'Saúde',
    SupportedAppLocale.enUs: 'Healthcare',
    SupportedAppLocale.deDe: 'Gesundheit',
    SupportedAppLocale.frFr: 'Santé',
    SupportedAppLocale.hiIn: 'स्वास्थ्य',
  },
  'leisure': {
    SupportedAppLocale.ptBr: 'Lazer e refeições',
    SupportedAppLocale.enUs: 'Leisure and dining',
    SupportedAppLocale.deDe: 'Freizeit und Essen',
    SupportedAppLocale.frFr: 'Loisirs et repas',
    SupportedAppLocale.hiIn: 'मनोरंजन और भोजन',
  },
  'installment': {
    SupportedAppLocale.ptBr: 'Eletrodomésticos',
    SupportedAppLocale.enUs: 'Appliances',
    SupportedAppLocale.deDe: 'Haushaltsgeräte',
    SupportedAppLocale.frFr: 'Électroménager',
    SupportedAppLocale.hiIn: 'घरेलू उपकरण',
  },
};
