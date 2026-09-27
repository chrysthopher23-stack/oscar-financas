import 'package:flutter/material.dart';

enum AppDestination {
  home('Início', Icons.home_outlined, '/'),
  financial(
    'screen.financial',
    Icons.account_balance_wallet_outlined,
    '/screen-1',
  ),
  extraIncome('screen.extraIncome', Icons.add_chart_outlined, '/screen-2'),
  investments('screen.investments', Icons.trending_up_outlined, '/screen-3'),
  objectives('screen.objectives', Icons.flag_outlined, '/screen-4'),
  reports('screen.reports', Icons.description_outlined, '/screen-5'),
  agenda('screen.agenda', Icons.calendar_month_outlined, '/screen-6'),
  calculator('screen.calculator', Icons.calculate_outlined, '/screen-7'),
  plans('screen.plans', Icons.workspace_premium_outlined, '/screen-8'),
  club('screen.club', Icons.handshake_outlined, '/screen-9'),
  account('screen.account', Icons.person_outline_rounded, '/account'),
  settings('screen.settings', Icons.tune_outlined, '/screen-11');

  const AppDestination(this.labelKey, this.icon, this.route);

  final String labelKey;
  final IconData icon;
  final String route;
}
