// lib/features/comida/domain/comida_models.dart

// ─── Lote de alimento (compra) ────────────────────────────────────────────────
class LoteAlimento {
  final String id;
  final String granjaId;
  final String tipoAnimalId;
  final DateTime fechaCompra;
  final double cantidadKg;
  final double precioTotal;
  final double? precioPorKg;
  final String? proveedor;
  final String? notas;
  final DateTime createdAt;

  // Joined / computed
  final String tipoNombre;
  final double kgConsumidosTotal;
  final int numPeriodos;

  const LoteAlimento({
    required this.id,
    required this.granjaId,
    required this.tipoAnimalId,
    required this.fechaCompra,
    required this.cantidadKg,
    required this.precioTotal,
    this.precioPorKg,
    this.proveedor,
    this.notas,
    required this.createdAt,
    required this.tipoNombre,
    required this.kgConsumidosTotal,
    required this.numPeriodos,
  });

  double get kgRestantes => cantidadKg - kgConsumidosTotal;

  factory LoteAlimento.fromJson(Map<String, dynamic> j) => LoteAlimento(
        id: j['id'] as String,
        granjaId: j['granja_id'] as String,
        tipoAnimalId: j['tipo_animal_id'] as String,
        fechaCompra: DateTime.parse(j['fecha_compra'] as String),
        cantidadKg: (j['cantidad_kg'] as num).toDouble(),
        precioTotal: (j['precio_total'] as num).toDouble(),
        precioPorKg: (j['precio_por_kg'] as num?)?.toDouble(),
        proveedor: j['proveedor'] as String?,
        notas: j['notas'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        tipoNombre: j['tipo_nombre'] as String? ?? '',
        kgConsumidosTotal:
            (j['kg_consumidos_total'] as num?)?.toDouble() ?? 0.0,
        numPeriodos: (j['num_periodos'] as num?)?.toInt() ?? 0,
      );
}

// ─── Periodo de alimento (uso del lote) ──────────────────────────────────────
class PeriodoAlimento {
  final String id;
  final String loteAlimentoId;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final bool activo;
  final double kgConsumidos;
  final String? notas;
  final DateTime createdAt;

  // Joined desde lote
  final String tipoAnimalId;
  final String tipoNombre;
  final double precioTotal;      // del lote
  final double cantidadKgLote;  // del lote
  final String? proveedor;
  final String? nombreAlimento; // proveedor usado como nombre en las imágenes

  const PeriodoAlimento({
    required this.id,
    required this.loteAlimentoId,
    required this.fechaInicio,
    this.fechaFin,
    required this.activo,
    required this.kgConsumidos,
    this.notas,
    required this.createdAt,
    required this.tipoAnimalId,
    required this.tipoNombre,
    required this.precioTotal,
    required this.cantidadKgLote,
    this.proveedor,
    this.nombreAlimento,
  });

  /// Días activo desde fecha_inicio
  int get diasActivo {
    final fin = fechaFin ?? DateTime.now();
    return fin.difference(fechaInicio).inDays;
  }

  /// Egreso proporcional: precio_total * (kg_consumidos / cantidad_kg_lote)
  double get egresoCalculado {
    if (cantidadKgLote == 0) return 0;
    return precioTotal * (kgConsumidos / cantidadKgLote);
  }

  factory PeriodoAlimento.fromJson(Map<String, dynamic> j) => PeriodoAlimento(
        id: j['id'] as String,
        loteAlimentoId: j['lote_alimento_id'] as String,
        fechaInicio: DateTime.parse(j['fecha_inicio'] as String),
        fechaFin: j['fecha_fin'] != null
            ? DateTime.parse(j['fecha_fin'] as String)
            : null,
        activo: j['activo'] as bool? ?? false,
        kgConsumidos: (j['kg_consumidos'] as num).toDouble(),
        notas: j['notas'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        tipoAnimalId: j['tipo_animal_id'] as String? ?? '',
        tipoNombre: j['tipo_nombre'] as String? ?? '',
        precioTotal: (j['precio_total'] as num?)?.toDouble() ?? 0.0,
        cantidadKgLote: (j['cantidad_kg'] as num?)?.toDouble() ?? 0.0,
        proveedor: j['proveedor'] as String?,
        nombreAlimento: j['nombre_alimento'] as String?,
      );
}

// ─── Stats de comida ──────────────────────────────────────────────────────────
class ComidaStats {
  final double totalKg;
  final double totalEgreso;

  const ComidaStats({required this.totalKg, required this.totalEgreso});
}