// lib/features/animales/model/ejemplar/ejemplar.dart

/// Un animal individual identificado por su número de brazalete.
class Ejemplar {
  final String id;
  final String granjaId;
  final String tipoAnimalId;
  final String grupoId;
  final int brazalete;
  final DateTime fechaAdquisicion;
  final bool activo;
  final String? notas;

  /// Nombre del tipo de animal (aplanado desde el join `tipo_animal`).
  final String tipoNombre;

  /// Nombre del grupo (aplanado desde el join `grupos`).
  final String grupoNombre;

  const Ejemplar({
    required this.id,
    required this.granjaId,
    required this.tipoAnimalId,
    required this.grupoId,
    required this.brazalete,
    required this.fechaAdquisicion,
    required this.activo,
    this.notas,
    required this.tipoNombre,
    required this.grupoNombre,
  });

  factory Ejemplar.fromJson(Map<String, dynamic> json) {
    return Ejemplar(
      id: json['id'] as String,
      granjaId: json['granja_id'] as String,
      tipoAnimalId: json['tipo_animal_id'] as String,
      grupoId: json['grupo_id'] as String,
      brazalete: json['brazalete'] as int,
      fechaAdquisicion: DateTime.parse(json['fecha_adquisicion'] as String),
      activo: json['activo'] as bool,
      notas: json['notas'] as String?,
      tipoNombre: (json['tipo_nombre'] as String?) ?? '',
      grupoNombre: (json['grupo_nombre'] as String?) ?? '',
    );
  }
}