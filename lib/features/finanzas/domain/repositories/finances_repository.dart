import '../entities/break_even_point.dart';

abstract interface class FinancesRepository {
  Future<List<BreakEvenPoint>> getBreakEvenPoints(String farmId);
}
