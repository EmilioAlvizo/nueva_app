class RegistrarBajaAnimalesInput {
  const RegistrarBajaAnimalesInput({
    required this.granjaId,
    required this.tipoAnimalId,
    required this.razonBajaId,
    required this.fechaBaja,
    required this.animalIds,
    this.importeTotal,
    this.notas,
  });

  final String granjaId;
  final String tipoAnimalId;
  final String razonBajaId;
  final DateTime fechaBaja;
  final List<String> animalIds;
  final double? importeTotal;
  final String? notas;

  int get cantidadAnimales => animalIds.length;

  Map<String, dynamic> toRpcParams() => {
    'p_granja_id': granjaId,
    'p_tipo_animal_id': tipoAnimalId,
    'p_razon_baja_id': razonBajaId,
    'p_fecha_baja': _formatDate(fechaBaja),
    'p_cantidad_animales': cantidadAnimales,
    'p_animal_ids': List<String>.from(animalIds),
    'p_importe_total': importeTotal,
    'p_notas': _normalizeText(notas),
  };
}

String _formatDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String? _normalizeText(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
