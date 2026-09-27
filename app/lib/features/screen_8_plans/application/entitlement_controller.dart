import 'package:flutter/foundation.dart';

import '../domain/access_policy.dart';

final class EntitlementController extends ChangeNotifier {
  EntitlementController() : _tier = initialTierFor(Uri.base, isWeb: kIsWeb);

  PlanTier _tier;
  PlanTier get tier => _tier;

  static bool isLocalPreview(Uri location, {required bool isWeb}) =>
      isWeb && (location.host == '127.0.0.1' || location.host == 'localhost');

  static PlanTier initialTierFor(Uri location, {required bool isWeb}) {
    return isLocalPreview(location, isWeb: isWeb) &&
            location.queryParameters['previewPlan'] == 'pro'
        ? PlanTier.pro
        : PlanTier.basic;
  }

  static bool canSelectPlanFor(
    Uri location, {
    required bool isWeb,
    required bool isReleaseMode,
  }) => !isReleaseMode || isLocalPreview(location, isWeb: isWeb);

  bool get canSelectPlan =>
      canSelectPlanFor(Uri.base, isWeb: kIsWeb, isReleaseMode: kReleaseMode);

  void selectPlan(PlanTier value) {
    if (!canSelectPlan) return;
    if (_tier == value) return;
    _tier = value;
    notifyListeners();
  }

  AccessDecision evaluate(CapabilityId capability) =>
      const AccessPolicy().evaluate(_tier, capability);
}
