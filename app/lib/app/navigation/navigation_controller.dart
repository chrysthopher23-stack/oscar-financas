import 'package:flutter/foundation.dart';

import 'app_destination.dart';

final class NavigationController extends ChangeNotifier {
  AppDestination _current = AppDestination.home;

  AppDestination get current => _current;

  void select(AppDestination destination) {
    if (_current == destination) return;
    _current = destination;
    notifyListeners();
  }
}
