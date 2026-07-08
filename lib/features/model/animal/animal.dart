// lib/features/animales/model/ejemplar/ejemplar.dart

/// Un animal individual identificado por su número de brazalete.
class Animal {
  final String id;
  final String granjaId;
  final String tipoAnimalId;
  final String? grupoId;
  final String? altaId;
  final String? bajaId;
  final int? brazalete;
  final String? propositoId;
  final String? tipoAdquisicionId;
  final DateTime fechaAdquisicion;
  final double? costoAdquisicion;
  final bool activo;
  final String? notas;

  /// Nombre del tipo de animal (aplanado desde el join `tipo_animal`).
  final String tipoNombre;

  /// Nombre del grupo (aplanado desde el join `grupos`).
  final String grupoNombre;

  const Animal({
    required this.id,
    required this.granjaId,
    required this.tipoAnimalId,
    this.grupoId,
    this.altaId,
    this.bajaId,
    this.brazalete,
    this.propositoId,
    this.tipoAdquisicionId,
    required this.fechaAdquisicion,
    this.costoAdquisicion,
    required this.activo,
    this.notas,
    required this.tipoNombre,
    required this.grupoNombre,
  });

  factory Animal.fromJson(Map<String, dynamic> json) {
    return Animal(
      id: json['id'] as String,
      granjaId: json['granja_id'] as String,
      tipoAnimalId: json['tipo_animal_id'] as String,
      grupoId: json['grupo_id'] as String?,
      altaId: json['alta_id'] as String?,
      bajaId: json['baja_id'] as String?,
      brazalete: json['brazalete'] as int?,
      propositoId: json['proposito_id'] as String?,
      tipoAdquisicionId: json['tipo_adquisicion_id'] as String?,
      fechaAdquisicion: DateTime.parse(json['fecha_adquisicion'] as String),
      costoAdquisicion: json['costo_adquisicion'] == null
          ? null
          : (json['costo_adquisicion'] as num).toDouble(),
      activo: json['activo'] as bool,
      notas: json['notas'] as String?,
      tipoNombre: (json['tipo_nombre'] as String?) ?? '',
      grupoNombre: (json['grupo_nombre'] as String?) ?? 'Sin grupo',
    );
  }
}
