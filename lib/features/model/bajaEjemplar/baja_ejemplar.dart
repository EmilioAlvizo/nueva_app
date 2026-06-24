// lib/features/animales/model/bajaEjemplar/baja_ejemplar.dart

/// Registro histórico de baja de un ejemplar (muerte, sacrificio, venta, etc).
class BajaEjemplar {
  final String id;
  final String ejemplarId;
  final String razonBajaId;
  final DateTime fechaBaja;
  final double? importeVenta;
  final String? notas;

  /// Si esta baja se hizo en conjunto con otras (lote de baja), aquí va el
  /// id de `lotes_baja`. Si es null, fue una baja de un solo ejemplar.
  final String? lotesBajaId;

  final int brazalete;
  final String tipoAnimalId;
  final String tipoNombre;
  final String grupoNombre;
  final String razonNombre;

  const BajaEjemplar({
    required this.id,
    required this.ejemplarId,
    required this.razonBajaId,
    required this.fechaBaja,
    this.importeVenta,
    this.notas,
    this.lotesBajaId,
    required this.brazalete,
    required this.tipoAnimalId,
    required this.tipoNombre,
    required this.grupoNombre,
    required this.razonNombre,
  });

  /// true si la razón de baja corresponde a una muerte (vs. sacrificio,
  /// venta u otra razón). Se basa en el nombre del catálogo.
  bool get esMuerte => razonNombre.toLowerCase().contains('muerte');

  factory BajaEjemplar.fromJson(Map<String, dynamic> json) {
    return BajaEjemplar(
      id: json['id'] as String,
      ejemplarId: json['ejemplar_id'] as String,
      razonBajaId: json['razon_baja_id'] as String,
      fechaBaja: DateTime.parse(json['fecha_baja'] as String),
      importeVenta: json['importe_venta'] == null
          ? null
          : (json['importe_venta'] as num).toDouble(),
      notas: json['notas'] as String?,
      lotesBajaId: json['lotes_baja_id'] as String?,
      brazalete: json['brazalete'] as int,
      tipoAnimalId: (json['tipo_animal_id'] as String?) ?? '',
      tipoNombre: (json['tipo_nombre'] as String?) ?? '',
      grupoNombre: (json['grupo_nombre'] as String?) ?? '',
      razonNombre: (json['razon_nombre'] as String?) ?? '',
    );
  }
}

/// Agrupación cliente-side de [BajaEjemplar] que comparten el mismo
/// `lotes_baja_id` (bajas hechas "por lote"). Se construye en la UI a partir
/// de la lista plana que regresa el repositorio; no representa una tabla.
class BajaLote {
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
  static List<BajaLote> agruparDesde(List<BajaEjemplar> bajas) {
    final Map<String, List<BajaEjemplar>> grupos = {};
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
}