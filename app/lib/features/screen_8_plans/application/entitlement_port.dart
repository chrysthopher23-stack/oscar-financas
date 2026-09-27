import '../domain/access_policy.dart';

abstract interface class EntitlementPort {
  Future<PlanTier> currentTier();
}
