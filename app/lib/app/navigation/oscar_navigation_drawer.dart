import 'package:flutter/material.dart';

import '../../core/brand/product_identity.dart';
import '../../core/localization/app_strings.dart';
import '../theme/app_colors.dart';
import 'app_destination.dart';

final class OscarNavigationDrawer extends StatelessWidget {
  const OscarNavigationDrawer({
    super.key,
    required this.current,
    required this.onSelected,
  });

  final AppDestination current;
  final ValueChanged<AppDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Drawer(
      width: MediaQuery.sizeOf(context).width.clamp(280, 360).toDouble(),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 16),
              child: Row(
                children: [
                  IconButton(
                    tooltip: strings.text('drawer.close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ProductIdentity.appName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: AppDestination.values.length,
                itemBuilder: (context, index) {
                  final destination = AppDestination.values[index];
                  final selected = destination == current;
                  return Semantics(
                    selected: selected,
                    child: ListTile(
                      selected: selected,
                      selectedTileColor: AppColors.gold.withValues(alpha: 0.14),
                      leading: Icon(destination.icon),
                      title: Text(strings.text(destination.labelKey)),
                      trailing: selected
                          ? const Icon(
                              Icons.chevron_right,
                              color: AppColors.gold,
                            )
                          : null,
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelected(destination);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
