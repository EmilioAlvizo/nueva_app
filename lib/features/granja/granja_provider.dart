// lib/features/granja/granja_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'granja.dart';

/// Al inicio no hay ninguna granja seleccionada (null).
/// Cuando el usuario toque una tarjeta, guardaremos la instancia de la [Farm] aquí.
//final selectedFarmProvider = Provider<Granja?>((ref) => null);

// Hereda directamente de Notifier para la nueva API
class SelectedFarmNotifier extends Notifier<Granja?> {
  @override
  Granja? build() => null; // Estado inicial indispensable en Riverpod 3

  // Método explícito para modificar el estado
  void updateFarm(Granja? farm) {
    state = farm;
  }
  void select(Granja farm)  => state = farm;
  void clear()              => state = null;
}

// Declaración global usando la nueva firma del NotifierProvider
final selectedFarmProvider = NotifierProvider<SelectedFarmNotifier, Granja?>(SelectedFarmNotifier.new);