final class BreakEvenPoint {
  const BreakEvenPoint({
    required this.farmId,
    required this.groupId,
    required this.startedAt,
    required this.endedAt,
    required this.calculatedEndAt,
    required this.mixtureId,
    required this.groupName,
    required this.mixtureDays,
    required this.goodEggs,
    required this.brokenEggs,
    required this.totalFoodCost,
    required this.totalFeedConsumption,
    required this.weightedAverageBirds,
    required this.eggsPerDay,
    required this.eggsPerDayPerBird,
    required this.feedPerDay,
    required this.feedPerDayPerBird,
    required this.breakEvenPrice,
    required this.averageSalePrice,
    required this.marginPercentage,
  });

  final String farmId;
  final String groupId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime calculatedEndAt;
  final String mixtureId;
  final String groupName;
  final int mixtureDays;
  final int goodEggs;
  final int brokenEggs;
  final double totalFoodCost;
  final double totalFeedConsumption;
  final double weightedAverageBirds;
  final double eggsPerDay;
  final double? eggsPerDayPerBird;
  final double feedPerDay;
  final double? feedPerDayPerBird;
  final double? breakEvenPrice;
  final double? averageSalePrice;
  final double? marginPercentage;
}
