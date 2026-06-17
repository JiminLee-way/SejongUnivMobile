enum RecommendedUpdateDialogAction { update, snoozeDay, close }

class AppUpdateRecommendationDismissState {
  const AppUpdateRecommendationDismissState({
    required this.latestBuildNumber,
    required this.dismissedUntil,
  });

  final int latestBuildNumber;
  final DateTime dismissedUntil;

  bool hides({required int latestBuildNumber, required DateTime now}) {
    return this.latestBuildNumber == latestBuildNumber &&
        now.isBefore(dismissedUntil);
  }

  Map<String, dynamic> toJson() => {
    'latestBuildNumber': latestBuildNumber,
    'dismissedUntil': dismissedUntil.toIso8601String(),
  };

  static AppUpdateRecommendationDismissState? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    try {
      final latestBuildNumber = raw['latestBuildNumber'];
      return AppUpdateRecommendationDismissState(
        latestBuildNumber: latestBuildNumber is int
            ? latestBuildNumber
            : int.parse('$latestBuildNumber'),
        dismissedUntil: DateTime.parse(raw['dismissedUntil'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

bool shouldShowRecommendedUpdate({
  required int latestBuildNumber,
  required AppUpdateRecommendationDismissState? dismissState,
  required DateTime now,
}) {
  if (latestBuildNumber <= 0) return false;
  return !(dismissState?.hides(
        latestBuildNumber: latestBuildNumber,
        now: now,
      ) ??
      false);
}
