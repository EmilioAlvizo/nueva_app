class AltaBrazalete {
  final int numero;
  final bool activo;

  const AltaBrazalete({required this.numero, required this.activo});

  factory AltaBrazalete.fromJson(Map<String, dynamic> json) => AltaBrazalete(
    numero: (json['numero'] as num).toInt(),
    activo: json['activo'] as bool? ?? true,
  );
}

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

  // Vista legacy: solo números agregados desde `vista_altas_animales`.
  final List<int>? brazaletes;

  // Vista enriquecida desde `animales`: conserva si el ejemplar sigue activo.
  final List<AltaBrazalete>? brazaletesDetalle;
  final int? cantidadVivos;
  final int? cantidadInactivos;

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
    this.brazaletesDetalle,
    this.cantidadVivos,
    this.cantidadInactivos,
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
    brazaletesDetalle: (j['brazaletes_detalle'] as List<dynamic>?)
        ?.map(
          (e) => AltaBrazalete.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    cantidadVivos: (j['cantidad_vivos'] as num?)?.toInt(),
    cantidadInactivos: (j['cantidad_muertos'] as num?)?.toInt(),
  );

  int get vivosCount => cantidadVivos ?? cantidadAnimales;

  int get inactivosCount => cantidadInactivos ?? 0;

  List<AltaBrazalete> get brazaletesDetalleSafe {
    final detalle = brazaletesDetalle;
    if (detalle != null) {
      return detalle;
    }

    return [
      for (final numero in brazaletes ?? const <int>[])
        AltaBrazalete(numero: numero, activo: true),
    ];
  }

  AltaAnimales copyWith({
    List<int>? brazaletes,
    List<AltaBrazalete>? brazaletesDetalle,
    int? cantidadVivos,
    int? cantidadInactivos,
  }) => AltaAnimales(
    id: id,
    granjaId: granjaId,
    tipoAnimalId: tipoAnimalId,
    grupoId: grupoId,
    propositoId: propositoId,
    tipoAdquisicionId: tipoAdquisicionId,
    proveedor: proveedor,
    fechaAlta: fechaAlta,
    cantidadAnimales: cantidadAnimales,
    costoTotal: costoTotal,
    notas: notas,
    createdBy: createdBy,
    createdAt: createdAt,
    brazaletes: brazaletes ?? this.brazaletes,
    brazaletesDetalle: brazaletesDetalle ?? this.brazaletesDetalle,
    cantidadVivos: cantidadVivos ?? this.cantidadVivos,
    cantidadInactivos: cantidadInactivos ?? this.cantidadInactivos,
  );
}
