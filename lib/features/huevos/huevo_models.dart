// lib/features/huevos/domain/huevo_models.dart

import 'package:flutter/material.dart';

// ─── Recolección de huevos ────────────────────────────────────────────────────
class RecoleccionHuevo {
  final String id;
  final String granjaId;
  final String tipoAnimalId;
  final String periodoAlimentoId;
  final String? grupoId;
  final DateTime fecha;
  final int huevosBuenos;
  final int huevosRotos;
  final String? notas;
  final DateTime createdAt;

  // Joined
  final String tipoNombre;
  final String? grupoNombre;

  const RecoleccionHuevo({
    required this.id,
    required this.granjaId,
    required this.tipoAnimalId,
    required this.periodoAlimentoId,
    this.grupoId,
    required this.fecha,
    required this.huevosBuenos,
    required this.huevosRotos,
    this.notas,
    required this.createdAt,
    required this.tipoNombre,
    this.grupoNombre,
  });

  int get total => huevosBuenos + huevosRotos;

  factory RecoleccionHuevo.fromJson(Map<String, dynamic> j) => RecoleccionHuevo(
        id: j['id'] as String,
        granjaId: j['granja_id'] as String,
        tipoAnimalId: j['tipo_animal_id'] as String,
        periodoAlimentoId: j['periodo_alimento_id'] as String,
        grupoId: j['grupo_id'] as String?,
        fecha: DateTime.parse(j['fecha'] as String),
        huevosBuenos: (j['huevos_buenos'] as num).toInt(),
        huevosRotos: (j['huevos_rotos'] as num).toInt(),
        notas: j['notas'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        tipoNombre: j['tipo_nombre'] as String? ?? '',
        grupoNombre: j['grupo_nombre'] as String?,
      );
}

// ─── Reducción de huevos ──────────────────────────────────────────────────────
class ReduccionHuevo {
  final String id;
  final String granjaId;
  final String tipoAnimalId;
  final String periodoAlimentoId;
  final String razonReduccionId;
  final int cantidad;
  final double? importe;
  final DateTime fecha;
  final String? notas;
  final DateTime createdAt;

  // Joined
  final String tipoNombre;
  final String razonNombre;

  const ReduccionHuevo({
    required this.id,
    required this.granjaId,
    required this.tipoAnimalId,
    required this.periodoAlimentoId,
    required this.razonReduccionId,
    required this.cantidad,
    this.importe,
    required this.fecha,
    this.notas,
    required this.createdAt,
    required this.tipoNombre,
    required this.razonNombre,
  });

  factory ReduccionHuevo.fromJson(Map<String, dynamic> j) => ReduccionHuevo(
        id: j['id'] as String,
        granjaId: j['granja_id'] as String,
        tipoAnimalId: j['tipo_animal_id'] as String,
        periodoAlimentoId: j['periodo_alimento_id'] as String,
        razonReduccionId: j['razon_reduccion_id'] as String,
        cantidad: (j['cantidad'] as num).toInt(),
        importe: (j['importe'] as num?)?.toDouble(),
        fecha: DateTime.parse(j['fecha'] as String),
        notas: j['notas'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        tipoNombre: j['tipo_nombre'] as String? ?? '',
        razonNombre: j['razon_nombre'] as String? ?? '',
      );
}

// ─── Item unificado (para mostrar en lista combinada) ─────────────────────────
enum TipoMovHuevo { recoleccion, reduccion }

class MovHuevo {
  final TipoMovHuevo tipo;
  final String id;
  final DateTime fecha;
  final String tipoAnimalId;
  final String tipoNombre;
  final String? grupoId;
  final String? grupoNombre;

  // Recolección
  final int? huevosBuenos;
  final int? huevosRotos;

  // Reducción
  final int? cantidad;
  final double? importe;
  final String? razonNombre;
  final String? razonReduccionId;
  final String? notas;

  const MovHuevo._({
    required this.tipo,
    required this.id,
    required this.fecha,
    required this.tipoAnimalId,
    required this.tipoNombre,
    this.grupoId,
    this.grupoNombre,
    this.huevosBuenos,
    this.huevosRotos,
    this.cantidad,
    this.importe,
    this.razonNombre,
    this.razonReduccionId,
    this.notas,
  });

  factory MovHuevo.deRecoleccion(RecoleccionHuevo r) => MovHuevo._(
        tipo: TipoMovHuevo.recoleccion,
        id: r.id,
        fecha: r.fecha,
        tipoAnimalId: r.tipoAnimalId,
        tipoNombre: r.tipoNombre,
        grupoId: r.grupoId,
        grupoNombre: r.grupoNombre,
        huevosBuenos: r.huevosBuenos,
        huevosRotos: r.huevosRotos,
        notas: r.notas,
      );

  factory MovHuevo.deReduccion(ReduccionHuevo r) => MovHuevo._(
        tipo: TipoMovHuevo.reduccion,
        id: r.id,
        fecha: r.fecha,
        tipoAnimalId: r.tipoAnimalId,
        tipoNombre: r.tipoNombre,
        cantidad: r.cantidad,
        importe: r.importe,
        razonNombre: r.razonNombre,
        razonReduccionId: r.razonReduccionId,
        notas: r.notas,
      );
}

// ─── Stats de huevos por tipo ─────────────────────────────────────────────────
class HuevoStats {
  final int totalRecolectados;
  final int totalBuenos;
  final int totalRotos;
  final double totalIngreso;
  final int totalVentas;
  final Map<String, int> porRazon; // razonNombre → cantidad

  const HuevoStats({
    required this.totalRecolectados,
    required this.totalBuenos,
    required this.totalRotos,
    required this.totalIngreso,
    required this.totalVentas,
    required this.porRazon,
  });
}

// ─── Catálogo simple ──────────────────────────────────────────────────────────
class CatItemHuevo {
  final String id;
  final String nombre;
  const CatItemHuevo(this.id, this.nombre);
}