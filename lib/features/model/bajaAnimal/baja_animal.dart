// lib/features/model/bajaAnimal/baja_animal.dart

/// Registro histórico de una baja (muerte, sacrificio, venta, etc).
/// Cada fila de `bajas_animales` representa UN evento de baja, que puede
/// afectar a uno o varios animales (`cantidad_animales`). Los brazaletes
/// de los animales afectados (si los tienen) vienen pre-agregados desde
/// `vista_bajas_animales` en el campo `brazaletes`.
class BajaAnimal {
  final String id;
  final String granjaId;
  final String tipoAnimalId;
  final String razonBajaId;
  final DateTime fechaBaja;
  final int cantidadAnimales;
  final double? importeTotal;
  final String? notas;
 
  final String tipoNombre;
  final String? grupoNombre;
  final String razonNombre;
  final List<int> brazaletes;
 
  const BajaAnimal({
    required this.id,
    required this.granjaId,
    required this.tipoAnimalId,
    required this.razonBajaId,
    required this.fechaBaja,
    required this.cantidadAnimales,
    this.importeTotal,
    this.notas,
    required this.tipoNombre,
    this.grupoNombre,
    required this.razonNombre,
    required this.brazaletes,
  });
 
  /// true si la razón de baja corresponde a una muerte (vs. sacrificio,
  /// venta u otra razón). Se basa en el nombre del catálogo.
  bool get esMuerte => razonNombre.toLowerCase().contains('muerte');
 
  /// true si el evento de baja afectó a más de un animal.
  bool get esLote => cantidadAnimales > 1;
 
  factory BajaAnimal.fromJson(Map<String, dynamic> json) {
    return BajaAnimal(
      id: json['id'] as String,
      granjaId: json['granja_id'] as String,
      tipoAnimalId: json['tipo_animal_id'] as String,
      razonBajaId: json['razon_baja_id'] as String,
      fechaBaja: DateTime.parse(json['fecha_baja'] as String),
      cantidadAnimales: json['total_bajas'] as int? ??
          json['cantidad_animales'] as int,
      importeTotal: (json['importe_total'] as num?)?.toDouble(),
      notas: json['notas'] as String?,
      tipoNombre: (json['tipo_nombre'] as String?) ?? '',
      grupoNombre: json['grupo_nombre'] as String?, // null si el evento mezcla varios grupos
      razonNombre: (json['razon_nombre'] as String?) ?? '',
      brazaletes: (json['brazaletes'] as List<dynamic>?)
              ?.map((b) => b as int)
              .toList() ??
          const [],
    );
  }
}

/// Agrupación cliente-side de [BajaEjemplar] que comparten el mismo
/// `lotes_baja_id` (bajas hechas "por lote"). Se construye en la UI a partir
/// de la lista plana que regresa el repositorio; no representa una tabla.
/* class BajaLote {
  final String lotesBajaId;
  final DateTime fechaBaja;
  final String razonNombre;
  final bool esMuerte;
  final String tipoNombre;
  final String grupoNombre;
  final String? notas;
  final List<int> brazaletes;

  const BajaLote({
    required this.lotesBajaId,
    required this.fechaBaja,
    required this.razonNombre,
    required this.esMuerte,
    required this.tipoNombre,
    required this.grupoNombre,
    this.notas,
    required this.brazaletes,
  });

  int get cantidad => brazaletes.length;

  /// Agrupa una lista de bajas individuales por `lotesBajaId`, ignorando
  /// las que no pertenecen a ningún lote (lotesBajaId == null).
  static List<BajaLote> agruparDesde(List<BajaAnimal> bajas) {
    final Map<String, List<BajaAnimal>> grupos = {};
    for (final b in bajas) {
      final loteId = b.lotesBajaId;
      if (loteId == null) continue;
      grupos.putIfAbsent(loteId, () => []).add(b);
    }

    final resultado = grupos.entries.map((entry) {
      final items = entry.value;
      items.sort((a, b) => a.brazalete.compareTo(b.brazalete));
      final primero = items.first;
      return BajaLote(
        lotesBajaId: entry.key,
        fechaBaja: primero.fechaBaja,
        razonNombre: primero.razonNombre,
        esMuerte: primero.esMuerte,
        tipoNombre: primero.tipoNombre,
        grupoNombre: primero.grupoNombre,
        notas: primero.notas,
        brazaletes: items.map((i) => i.brazalete).toList(),
      );
    }).toList();

    resultado.sort((a, b) => b.fechaBaja.compareTo(a.fechaBaja));
    return resultado;
  }
} */