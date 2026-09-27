enum PlanTier { basic, plus, pro }

enum CapabilityId {
  extraIncome,
  investments,
  objectives,
  agendaExtraIncome,
  report3Months,
  report6Months,
  annualReport,
}

final class AccessDecision {
  const AccessDecision({required this.allowed, this.requiredTier});
  final bool allowed;
  final PlanTier? requiredTier;
}

final class AccessPolicy {
  const AccessPolicy();

  AccessDecision evaluate(PlanTier current, CapabilityId capability) {
    final required = switch (capability) {
      CapabilityId.extraIncome ||
      CapabilityId.agendaExtraIncome ||
      CapabilityId.report3Months => PlanTier.plus,
      CapabilityId.investments ||
      CapabilityId.objectives ||
      CapabilityId.report6Months ||
      CapabilityId.annualReport => PlanTier.pro,
    };
    return AccessDecision(
      allowed: current.index >= required.index,
      requiredTier: current.index >= required.index ? null : required,
    );
  }
}
