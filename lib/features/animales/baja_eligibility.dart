import '../model/animal/animal.dart';

bool isAnimalEligibleForBaja(
  Animal animal, {
  required String tipoAnimalId,
  required DateTime fechaBaja,
}) {
  if (!animal.activo ||
      animal.bajaId != null ||
      animal.tipoAnimalId != tipoAnimalId) {
    return false;
  }

  final acquisitionDate = DateTime(
    animal.fechaAdquisicion.year,
    animal.fechaAdquisicion.month,
    animal.fechaAdquisicion.day,
  );
  final bajaDate = DateTime(fechaBaja.year, fechaBaja.month, fechaBaja.day);
  return !acquisitionDate.isAfter(bajaDate);
}

({Set<String> eligibleIds, int removedCount}) reconcileBajaSelection({
  required Iterable<String> selectedAnimalIds,
  required Iterable<Animal> animals,
  required String tipoAnimalId,
  required DateTime fechaBaja,
}) {
  final selectedIds = selectedAnimalIds.toSet();
  final eligibleIds = animals
      .where(
        (animal) =>
            selectedIds.contains(animal.id) &&
            isAnimalEligibleForBaja(
              animal,
              tipoAnimalId: tipoAnimalId,
              fechaBaja: fechaBaja,
            ),
      )
      .map((animal) => animal.id)
      .toSet();

  return (
    eligibleIds: eligibleIds,
    removedCount: selectedIds.length - eligibleIds.length,
  );
}

({Set<String> eligibleIds, int removedCount})?
reconcileBajaSelectionIfAvailable({
  required Iterable<String> selectedAnimalIds,
  required Iterable<Animal>? animals,
  required String tipoAnimalId,
  required DateTime fechaBaja,
}) => animals == null
    ? null
    : reconcileBajaSelection(
        selectedAnimalIds: selectedAnimalIds,
        animals: animals,
        tipoAnimalId: tipoAnimalId,
        fechaBaja: fechaBaja,
      );
