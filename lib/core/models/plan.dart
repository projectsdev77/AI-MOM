/// The two subscription tiers. Full-only features stay visible and are
/// gated in the UI via [LockedFeatureOverlay] rather than hidden.
enum AppPlan { basic, full }

extension AppPlanX on AppPlan {
  bool get isFull => this == AppPlan.full;
  String get displayName => isFull ? 'Full Mom Experience' : 'Basic Mom';
  int get maxActiveTasks => isFull ? 1 << 30 : 5;
  int get weeklyChatMessageLimit => isFull ? 1 << 30 : 15;
  int get dailyNudgeCap => isFull ? 1 << 30 : 3;
}
