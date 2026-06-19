// ─── lib/features/animales/tipo_filtro.dart ──────────────────────────────────
// Filtro de tipo de animal: estado compartido + UI (badge + picker).
//
// Vive en un archivo aparte porque lo usan dos pantallas distintas:
//  - HomeScreen   → muestra el botón/badge en la barra superior, junto a Ajustes.
//  - AnimalesScreen → consume el filtro para Grupos / Ejemplares / Lotes / Bajas.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../model/tipoAnimal/tipoAnimal.dart';
import '../model/grupo/grupo.dart';

// ── Estado del filtro ('all' = sin filtro) ────────────────────────────────────
class TipoFiltroNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void set(String tipoId) => state = tipoId;
  void clear() => state = 'all';
}

final tipoFiltroProvider = NotifierProvider<TipoFiltroNotifier, String>(
  TipoFiltroNotifier.new,
);

// ── Color asociado a un tipo de animal (para badges, círculos, etc.) ─────────
Color colorParaTipoAnimal(String tipoId, List<TipoAnimal> tipos) {
  final idx = tipos.indexWhere((t) => t.id == tipoId);
  return AppColors.tipoColor[(idx < 0 ? 0 : idx) % AppColors.tipoColor.length];
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge / botón de filtro
// ─────────────────────────────────────────────────────────────────────────────
class TipoFiltroBadgeButton extends StatelessWidget {
  final bool isDark;
  final List<TipoAnimal> tipos;
  final List<Grupo> grupos;
  final String tipoFiltro;
  final ValueChanged<String> onChanged;

  const TipoFiltroBadgeButton({
    super.key,
    required this.isDark,
    required this.tipos,
    required this.grupos,
    required this.tipoFiltro,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    TipoAnimal? tipoSel;
    if (tipoFiltro != 'all') {
      final idx = tipos.indexWhere((t) => t.id == tipoFiltro);
      if (idx >= 0) tipoSel = tipos[idx];
    }
    final activo = tipoSel != null;
    final color = activo ? colorParaTipoAnimal(tipoSel!.id, tipos) : null;

    return GestureDetector(
      onTap: () => showTipoFiltroPicker(
        context,
        tipos: tipos,
        grupos: grupos,
        selected: tipoFiltro,
        onChanged: onChanged,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: activo
              ? color!.withOpacity(0.15)
              : (isDark ? AppColors.bgCard : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activo
                ? color!
                : (isDark ? AppColors.border : const Color(0xFFD1D5DB)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_rounded,
              size: 18,
              color: activo
                  ? color
                  : (isDark
                        ? AppColors.textSecondary
                        : const Color(0xFF6B7280)),
            ),
            if (activo) ...[
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 90),
                child: Text(
                  tipoSel!.nombre,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet picker (círculo de color por tipo)
// ─────────────────────────────────────────────────────────────────────────────
void showTipoFiltroPicker(
  BuildContext context, {
  required List<TipoAnimal> tipos,
  required List<Grupo> grupos,
  required String selected,
  required ValueChanged<String> onChanged,
}) {
  final options = [
    ('all', 'Todos los tipos', grupos.length),
    ...tipos.map(
      (t) =>
          (t.id, t.nombre, grupos.where((g) => g.tipoAnimalId == t.id).length),
    ),
  ];

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => TipoFiltroPicker(
      options: options,
      selected: selected,
      tipos: tipos,
      onChanged: (v) {
        onChanged(v);
        Navigator.pop(context);
      },
    ),
  );
}

class TipoFiltroPicker extends StatelessWidget {
  final List<(String, String, int)> options;
  final String selected;
  final List<TipoAnimal> tipos;
  final ValueChanged<String> onChanged;

  const TipoFiltroPicker({
    super.key,
    required this.options,
    required this.selected,
    required this.tipos,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pill
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Row(
            children: [
              const Text(
                'Filtrar por tipo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (selected != 'all')
                GestureDetector(
                  onTap: () => onChanged('all'),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white70,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Se aplica a grupos, ejemplares, lotes y bajas',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 16),
          ...options.map((o) {
            final isSel = o.$1 == selected;
            final color = o.$1 == 'all'
                ? Colors.white38
                : colorParaTipoAnimal(o.$1, tipos);
            final countTxt = '${o.$3} grupos';
            return GestureDetector(
              onTap: () => onChanged(o.$1),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSel
                      ? Colors.white.withOpacity(0.06)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSel
                        ? Colors.white24
                        : Colors.white.withOpacity(0.07),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.$2,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            countTxt,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSel)
                      const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: AppColors.green,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
