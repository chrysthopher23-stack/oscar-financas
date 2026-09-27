import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/features/screen_8_plans/application/entitlement_controller.dart';
import 'package:oscar_financas/features/screen_8_plans/domain/access_policy.dart';

void main() {
  const policy = AccessPolicy();

  test('Plus grants extra income but not investments', () {
    expect(
      policy.evaluate(PlanTier.plus, CapabilityId.extraIncome).allowed,
      isTrue,
    );
    expect(
      policy.evaluate(PlanTier.plus, CapabilityId.investments).allowed,
      isFalse,
    );
  });

  test('annual and six-month reports require Pro', () {
    expect(
      policy.evaluate(PlanTier.plus, CapabilityId.report6Months).requiredTier,
      PlanTier.pro,
    );
    expect(
      policy.evaluate(PlanTier.plus, CapabilityId.annualReport).requiredTier,
      PlanTier.pro,
    );
  });

  test('Pro preview is available only on the local web address', () {
    final local = Uri.parse('http://127.0.0.1:8766/?previewPlan=pro');
    final hosted = Uri.parse('https://example.com/?previewPlan=pro');

    expect(
      EntitlementController.initialTierFor(local, isWeb: true),
      PlanTier.pro,
    );
    expect(
      EntitlementController.initialTierFor(local, isWeb: false),
      PlanTier.basic,
    );
    expect(
      EntitlementController.initialTierFor(hosted, isWeb: true),
      PlanTier.basic,
    );
    expect(
      EntitlementController.canSelectPlanFor(
        local,
        isWeb: true,
        isReleaseMode: true,
      ),
      isTrue,
    );
    expect(
      EntitlementController.canSelectPlanFor(
        hosted,
        isWeb: true,
        isReleaseMode: true,
      ),
      isFalse,
    );
  });

  test('choosing a plan immediately updates access', () {
    final entitlements = EntitlementController();
    addTearDown(entitlements.dispose);

    entitlements.selectPlan(PlanTier.pro);
    expect(entitlements.tier, PlanTier.pro);
    expect(entitlements.evaluate(CapabilityId.objectives).allowed, isTrue);

    entitlements.selectPlan(PlanTier.basic);
    expect(entitlements.tier, PlanTier.basic);
    expect(entitlements.evaluate(CapabilityId.objectives).allowed, isFalse);
  });
}
