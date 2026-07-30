final class BreakEvenPoint {
  const BreakEvenPoint({
    required this.startedAt,
    required this.endedAt,
    required this.mixtureId,
    required this.groupName,
    required this.goodEggs,
    required this.brokenEggs,
    required this.totalFoodCost,
    required this.breakEvenPrice,
  });

  final DateTime startedAt;
  final DateTime? endedAt;
  final String mixtureId;
  final String groupName;
  final int goodEggs;
  final int brokenEggs;
  final double totalFoodCost;
  final double? breakEvenPrice;
}
