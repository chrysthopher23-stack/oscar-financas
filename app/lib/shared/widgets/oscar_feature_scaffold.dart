import 'package:flutter/material.dart';

import '../../app/navigation/app_destination.dart';
import '../../app/navigation/oscar_navigation_drawer.dart';
import '../../core/localization/app_strings.dart';
import '../controllers/financial_visibility_controller.dart';
import '../controllers/month_controller.dart';
import 'financial_visibility_button.dart';
import 'local_clock.dart';
import 'month_selector.dart';

enum FeatureHeaderKind { menuOnly, financialMonth, agendaMonth }

final class OscarFeatureScaffold extends StatelessWidget {
  const OscarFeatureScaffold({
    super.key,
    required this.destination,
    required this.onDestinationSelected,
    required this.headerKind,
    required this.body,
    this.monthController,
    this.visibilityController,
    this.bottomNavigationBar,
    this.actions = const [],
  });

  final AppDestination destination;
  final ValueChanged<AppDestination> onDestinationSelected;
  final FeatureHeaderKind headerKind;
  final Widget body;
  final MonthController? monthController;
  final FinancialVisibilityController? visibilityController;
  final Widget? bottomNavigationBar;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    assert(
      headerKind == FeatureHeaderKind.menuOnly || monthController != null,
      'A month controller is required by this header.',
    );
    assert(
      headerKind != FeatureHeaderKind.financialMonth ||
          visibilityController != null,
      'Financial headers require the shared visibility controller.',
    );

    return Scaffold(
      drawer: OscarNavigationDrawer(
        current: destination,
        onSelected: onDestinationSelected,
      ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: headerKind == FeatureHeaderKind.menuOnly ? 64 : 76,
        titleSpacing: 0,
        leadingWidth: 52,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Menu',
            onPressed: Scaffold.of(context).openDrawer,
            icon: const Icon(Icons.menu),
          ),
        ),
        title: headerKind == FeatureHeaderKind.menuOnly
            ? Text(AppStrings.of(context).text(destination.labelKey))
            : MonthSelector(controller: monthController!),
        actions: [
          ...switch (headerKind) {
            FeatureHeaderKind.financialMonth => [
              FinancialVisibilityButton(controller: visibilityController!),
              const SizedBox(width: 4),
            ],
            FeatureHeaderKind.agendaMonth => const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Center(child: LocalClock()),
              ),
            ],
            FeatureHeaderKind.menuOnly => const [],
          },
          ...actions,
        ],
      ),
      body: body,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
