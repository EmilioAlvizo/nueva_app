import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/supabase_finances_repository.dart';
import '../../domain/entities/break_even_point.dart';
import '../../domain/repositories/finances_repository.dart';

part 'finances_providers.g.dart';

Duration? _noRetry(int _, Object _) => null;

@Riverpod(keepAlive: true)
FinancesRepository financesRepository(Ref ref) {
  return SupabaseFinancesRepository(Supabase.instance.client);
}

@Riverpod(retry: _noRetry)
Future<List<BreakEvenPoint>> breakEvenPoints(Ref ref, String farmId) {
  return ref.read(financesRepositoryProvider).getBreakEvenPoints(farmId);
}
