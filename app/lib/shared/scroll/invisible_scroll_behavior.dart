import 'package:flutter/material.dart';

final class InvisibleScrollBehavior extends MaterialScrollBehavior {
  const InvisibleScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
