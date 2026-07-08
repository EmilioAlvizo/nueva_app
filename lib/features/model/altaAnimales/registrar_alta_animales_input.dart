class RegistrarAltaAnimalesInput {
  const RegistrarAltaAnimalesInput({
    required this.granjaId,
    required this.tipoAnimalId,
    this.grupoId,
    this.propositoId,
    this.tipoAdquisicionId,
    required this.fechaAlta,
    required this.cantidad,
    this.bracelets,
    this.proveedor,
    this.costoTotal,
    this.notas,
  });

  final String granjaId;
  final String tipoAnimalId;
  final String? grupoId;
  final String? propositoId;
  final String? tipoAdquisicionId;
  final DateTime fechaAlta;
  final int cantidad;
  final List<int>? bracelets;
  final String? proveedor;
  final double? costoTotal;
  final String? notas;

  Map<String, dynamic> toRpcParams() => {
    'granja_id': granjaId,
    'tipo_animal_id': tipoAnimalId,
    'grupo_id': grupoId,
    'proposito_id': propositoId,
    'tipo_adquisicion_id': tipoAdquisicionId,
    'fecha_alta': _formatDate(fechaAlta),
    'cantidad': cantidad,
    'bracelets': bracelets == null ? null : List<int>.from(bracelets!),
    'proveedor': _normalizeText(proveedor),
    'costo_total': costoTotal,
    'notas': _normalizeText(notas),
  };
}

String _formatDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String? _normalizeText(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
