class AltaAnimales {
  final String id;
  final String granjaId;
  final String tipoAnimalId;
  final String? grupoId;
  final String? propositoId;
  final String? tipoAdquisicionId;
  final String? proveedor;
  final DateTime fechaAlta;
  final int cantidadAnimales;
  final double? costoTotal;
  final String? notas;
  final String createdBy;
  final DateTime createdAt;

  //vista
  final List<int>? brazaletes;

  const AltaAnimales({
    required this.id,
    required this.granjaId,
    required this.tipoAnimalId,
    this.grupoId,
    this.propositoId,
    this.tipoAdquisicionId,
    this.proveedor,
    required this.fechaAlta,
    required this.cantidadAnimales,
    this.costoTotal,
    this.notas,
    required this.createdBy,
    required this.createdAt,
    this.brazaletes,
  });

  factory AltaAnimales.fromJson(Map<String, dynamic> j) => AltaAnimales(
    id: j['id'] as String,
    granjaId: j['granja_id'] as String,
    tipoAnimalId: j['tipo_animal_id'] as String,
    grupoId: j['grupo_id'] as String?,
    propositoId: j['proposito_id'] as String?,
    tipoAdquisicionId: j['tipo_adquisicion_id'] as String?,
    proveedor: j['proveedor'] as String?,
    fechaAlta: DateTime.parse(j['fecha_alta'] as String),
    cantidadAnimales: j['cantidad_animales'] as int,
    costoTotal: (j['costo_total'] as num?)?.toDouble(),
    notas: j['notas'] as String?,
    createdBy: j['created_by'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
    brazaletes:
        (j['brazaletes'] as List<dynamic>?)
            ?.map((e) => ((e ?? 0) as num).toInt())
            .toList() ??
        [],
  );
}
