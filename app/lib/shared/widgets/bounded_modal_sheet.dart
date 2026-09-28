import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Opens a modal sheet whose content can scroll, but never receives an
/// unbounded viewport. This keeps forms usable on compact Android screens and
/// in the web preview.
Future<T?> showOscarBoundedModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    builder: (sheetContext) => _BoundedModalSheet(child: builder(sheetContext)),
  );
}

final class _BoundedModalSheet extends StatelessWidget {
  const _BoundedModalSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight = math.max(
      0.0,
      media.size.height -
          media.padding.top -
          media.padding.bottom -
          media.viewInsets.bottom,
    );
    return ConstrainedBox(
      key: const ValueKey('oscarBoundedModalSheet'),
      constraints: BoxConstraints(maxHeight: availableHeight * .88),
      child: child,
    );
  }
}
