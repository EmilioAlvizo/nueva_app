class LoteEntrada {
  final String id;
  final String grupoId;
  final String tipoAnimalId;
  final DateTime fechaAdquisicion;
  final String? proveedor;
  final double? costoTotal;
  final String tipoAdquisicionNombre; // joined
  final int totalEjemplares;
  final List<int> brazaletes;
 
  const LoteEntrada({
    required this.id,
    required this.grupoId,
    required this.tipoAnimalId,
    required this.fechaAdquisicion,
    this.proveedor,
    this.costoTotal,
    required this.tipoAdquisicionNombre,
    required this.totalEjemplares,
    required this.brazaletes,
  });
 
  factory LoteEntrada.fromJson(Map<String, dynamic> j) => LoteEntrada(
        id: j['id'] as String,
        grupoId: j['grupo_id'] as String,
        tipoAnimalId: j['tipo_animal_id'] as String,
        fechaAdquisicion: DateTime.parse(j['fecha_adquisicion'] as String),
        proveedor: j['proveedor'] as String?,
        costoTotal: (j['costo_total'] as num?)?.toDouble(),
        tipoAdquisicionNombre: j['tipo_adquisicion_nombre'] as String? ?? '',
        totalEjemplares: (j['total_ejemplares'] as num?)?.toInt() ?? 0,
        brazaletes: (j['brazaletes'] as List<dynamic>?)
                ?.map((e) => ((e ?? 0) as num).toInt())
                .toList() ??
            [],
      );
}