import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../controllers/financial_visibility_controller.dart';

final class FinancialVisibilityButton extends StatelessWidget {
  const FinancialVisibilityButton({super.key, required this.controller});

  final FinancialVisibilityController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hidden = controller.valuesHidden;
        return IconButton(
          tooltip: AppStrings.of(context)
              .text(hidden ? 'privacy.show' : 'privacy.hide'),
          onPressed: controller.toggle,
          icon: Icon(
            hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        );
      },
    );
  }
}
