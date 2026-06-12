// ─── lib/features/animales/animales_screen.dart ──────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../model/tipoAnimal/tipoAnimal.dart';
import '../model/grupo/grupo.dart';
import '../model/loteEntrada/loteEntrada.dart';
import 'animales_provider.dart';
import '../model/tipoAnimal/nuevo_tipoAnimal.dart';

// ─── Colores de acento por índice de tipo ─────────────────────────────────────
Color _colorParaTipo(String tipoId, List<TipoAnimal> tipos) {
  final idx = tipos.indexWhere((t) => t.id == tipoId);
  return AppColors.tipoColor[(idx < 0 ? 0 : idx) % AppColors.tipoColor.length];
}

// ─────────────────────────────────────────────────────────────────────────────
class AnimalesScreen extends ConsumerStatefulWidget {
  final String granjaId;
  const AnimalesScreen({super.key, required this.granjaId});

  @override
  ConsumerState<AnimalesScreen> createState() => _AnimalesScreenState();
}

class _AnimalesScreenState extends ConsumerState<AnimalesScreen> {
  String _tipoFiltro = 'all';
  final Set<String> _expandidos = {};   // grupos con lotes visibles
  final Set<String> _colapsados = {};   // grupos minimizados
  bool _fabOpen = false;

  void _toggleExpand(String id) => setState(() {
        _expandidos.contains(id) ? _expandidos.remove(id) : _expandidos.add(id);
      });

  void _toggleColapso(String id) => setState(() {
        _colapsados.contains(id) ? _colapsados.remove(id) : _colapsados.add(id);
      });

  @override
  Widget build(BuildContext context) {
    final tiposAsync = ref.watch(tiposAnimalProvider(widget.granjaId));
    final gruposAsync = ref.watch(gruposProvider(widget.granjaId));
    final conteosAsync = ref.watch(conteosGruposProvider(widget.granjaId));

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: tiposAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (tipos) => gruposAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (grupos) => conteosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (conteos) => _buildContent(tipos, grupos, conteos),
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _buildContent(
    List<TipoAnimal> tipos,
    List<Grupo> grupos,
    Map<String, GrupoConteo> conteos,
  ) {
    final gruposFiltrados = _tipoFiltro == 'all'
        ? grupos
        : grupos.where((g) => g.tipoAnimalId == _tipoFiltro).toList();

    final totalVivos = grupos.fold<int>(
      0, (s, g) => s + (conteos[g.id]?.vivos ?? 0));
    final totalMuertes = grupos.fold<int>(
      0, (s, g) => s + (conteos[g.id]?.muertes ?? 0));

    return GestureDetector(
      onTap: () { if (_fabOpen) setState(() => _fabOpen = false); },
      child: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────────────────

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Botones Tipos / Bajas ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      _NavButton(
                        icon: Icons.layers_outlined,
                        label: 'Tipos',
                        onTap: () => context.push('/tipos'),
                      ),
                      const SizedBox(width: 8),
                      _NavButton(
                        icon: Icons.one_x_mobiledata_rounded,  
                        label: 'Bajas',
                        onTap: () => context.push('/bajas'),
                      ),
                    ],
                  ),
                ),

                // ── Filtro por tipo ────────────────────────────────────
                _TipoSelector(
                  tipos: tipos,
                  grupos: grupos,
                  value: _tipoFiltro,
                  onChanged: (v) => setState(() => _tipoFiltro = v),
                ),

                // ── Editar / Eliminar tipo activo ──────────────────────
                if (_tipoFiltro != 'all')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _SmallButton(
                          icon: Icons.edit_outlined,
                          label: 'Editar tipo',
                          onTap: () => context.push('/tipos/$_tipoFiltro/editar'),
                        ),
                        const SizedBox(width: 8),
                        _SmallButton(
                          icon: Icons.delete_outline,
                          label: 'Eliminar tipo',
                          danger: true,
                          onTap: () => _confirmarEliminarTipo(context),
                        ),
                      ],
                    ),
                  ),

                // ── Stat tiles ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      _StatTile(value: '$totalVivos', label: 'Aves vivas', color: AppColors.green),
                      const SizedBox(width: 10),
                      _StatTile(value: '${gruposFiltrados.length}', label: 'Grupos', color: const Color(0xFF4B5563)),
                      const SizedBox(width: 10),
                      _StatTile(value: '$totalMuertes', label: 'Muertes', color: const Color(0xFF7C3F2B)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Lista de grupos ──────────────────────────────────────────
          if (gruposFiltrados.isEmpty)
            SliverToBoxAdapter(child: _EmptyState(tipos: tipos))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final grupo = gruposFiltrados[i];
                    final conteo = conteos[grupo.id] ?? const GrupoConteo(vivos: 0, muertes: 0, total: 0);
                    final color = _colorParaTipo(grupo.tipoAnimalId, tipos);
                    final tipo = tipos.firstWhere(
                      (t) => t.id == grupo.tipoAnimalId,
                      orElse: () => TipoAnimal(id: '', granjaId: '', nombre: '', createdBy: ''),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _GrupoCard(
                        grupo: grupo,
                        tipo: tipo,
                        conteo: conteo,
                        stripColor: color,
                        expandido: _expandidos.contains(grupo.id),
                        colapsado: _colapsados.contains(grupo.id),
                        onToggleExpand: () => _toggleExpand(grupo.id),
                        onToggleColapso: () => _toggleColapso(grupo.id),
                        granjaId: widget.granjaId,
                      ),
                    );
                  },
                  childCount: gruposFiltrados.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    final actions = [
      (Icons.add, 'Nuevo ejemplar', 'Un animal con su brazalete', NuevoAnimal(isDark: true)),
      (Icons.inventory_2_outlined, 'Nuevo lote de entrada', 'Varios ejemplares juntos', NuevoAnimal(isDark: true)),
      (Icons.create_new_folder_outlined, 'Nuevo grupo', 'Corral o agrupación', NuevoAnimal(isDark: true)),
      (Icons.label_outline, 'Nuevo tipo de animal', 'Categoría base (Gallina…)', NuevoAnimal(isDark: true)),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_fabOpen) ...[
          ...actions.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FabMenuItem(
              icon: a.$1,
              label: a.$2,
              desc: a.$3,
              onTap: () {
                setState(() => _fabOpen = false);
                /* context.push(a.$4); */

                showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true, // Permite ajustar el tamaño con el teclado
          builder: (_) => a.$4,
        );
              },
            ),
          )),
          const SizedBox(height: 4),
        ],
        FloatingActionButton(
          backgroundColor: AppColors.green,
          foregroundColor: AppColors.bgDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onPressed: () => setState(() => _fabOpen = !_fabOpen),
          child: AnimatedRotation(
            turns: _fabOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(_fabOpen ? Icons.close : Icons.add, size: 28),
          ),
        ),
      ],
    );
  }

  void _confirmarEliminarTipo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar tipo'),
        content: const Text('¿Eliminar este tipo de animal? Se quitarán sus grupos y ejemplares.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _tipoFiltro = 'all');
              // TODO: llamar repo.deleteTipo(...)
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE GRUPO
// ─────────────────────────────────────────────────────────────────────────────
class _GrupoCard extends ConsumerWidget {
  final Grupo grupo;
  final TipoAnimal tipo;
  final GrupoConteo conteo;
  final Color stripColor;
  final bool expandido;
  final bool colapsado;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleColapso;
  final String granjaId;

  const _GrupoCard({
    required this.grupo,
    required this.tipo,
    required this.conteo,
    required this.stripColor,
    required this.expandido,
    required this.colapsado,
    required this.onToggleExpand,
    required this.onToggleColapso,
    required this.granjaId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // Fondo de la card
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _mostrarDetalle(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              grupo.nombre,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            if (grupo.descripcion != null && !colapsado)
                              Text(
                                grupo.descripcion!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Contador de vivos
                    Row(
                      children: [
                        const Icon(Icons.egg_outlined, size: 22, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          '${conteo.vivos}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        // Botón colapsar
                        IconButton(
                          icon: Icon(
                            colapsado ? Icons.expand_more : Icons.expand_less,
                            color: Colors.white70,
                          ),
                          onPressed: onToggleColapso,
                        ),
                        // Menú
                        _CardMenu(
                          onEdit: () => context.push('/grupos/${grupo.id}/editar'),
                          onDelete: () => _confirmarEliminar(context),
                        ),
                      ],
                    ),
                  ],
                ),

                if (!colapsado) ...[
                  const SizedBox(height: 12),

                  // ── Mini stats ─────────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: _MiniStat(icon: Icons.egg_outlined, value: '${conteo.vivos}', label: 'Vivos')),
                      const SizedBox(width: 8),
                      Expanded(child: _MiniStat(icon: Icons.tag, value: '${conteo.total}', label: 'Brazaletes')),
                      const SizedBox(width: 8),
                      Expanded(child: _MiniStat(icon: Icons.one_x_mobiledata_rounded, value: '${conteo.muertes}', label: 'Muertes', danger: true)),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ── Toggle lotes ───────────────────────────────────
                  _LotesSection(
                    grupoId: grupo.id,
                    expandido: expandido,
                    onToggle: onToggleExpand,
                  ),

                  const SizedBox(height: 10),

                  // ── Acciones rápidas ───────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.add,
                          label: 'Ejemplar',
                          onTap: () => context.push(
                            '/aves/nuevo?tipo=${grupo.tipoAnimalId}&grupo=${grupo.id}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.inventory_2_outlined,
                          label: 'Lote',
                          onTap: () => context.push(
                            '/lotes-entrada/nuevo?tipo=${grupo.tipoAnimalId}&grupo=${grupo.id}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.one_x_mobiledata_rounded,
                          label: 'Baja',
                          danger: true,
                          onTap: () => _mostrarBaja(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Franja lateral de color (tipo) ─────────────────────────
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 32,
              color: stripColor,
              alignment: Alignment.center,
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  tipo.nombre,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalle(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DetalleGrupoSheet(grupo: grupo, tipo: tipo, conteo: conteo),
    );
  }

  void _mostrarBaja(BuildContext context) {
    // TODO: mostrar BajaSheet pasando grupoId
    context.push('/bajas/nueva?grupo=${grupo.id}');
  }

  void _confirmarEliminar(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: const Text('¿Eliminar este grupo? Se quitarán también sus ejemplares.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: repo.deleteGrupo(grupo.id)
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECCIÓN DE LOTES (carga lazy)
// ─────────────────────────────────────────────────────────────────────────────
class _LotesSection extends ConsumerWidget {
  final String grupoId;
  final bool expandido;
  final VoidCallback onToggle;

  const _LotesSection({
    required this.grupoId,
    required this.expandido,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Solo carga si está expandido
    final lotesAsync = expandido ? ref.watch(lotesDeGrupoProvider(grupoId)) : null;

    return Column(
      children: [
        // Botón toggle
        GestureDetector(
          onTap: onToggle,
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.bgCard2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  expandido ? Icons.expand_less : Icons.chevron_right,
                  size: 16,
                  color: Colors.white70,
                ),
                const SizedBox(width: 6),
                Text(
                  expandido ? 'Ocultar lotes' : 'Ver lotes de entrada',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),

        // Lista de lotes
        if (expandido && lotesAsync != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: lotesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
              data: (lotes) => lotes.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Aún no hay lotes de entrada.',
                        style: TextStyle(fontSize: 12, color: Colors.white38),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Column(
                      children: lotes.map((l) => _LoteCard(lote: l)).toList(),
                    ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE LOTE
// ─────────────────────────────────────────────────────────────────────────────
class _LoteCard extends StatelessWidget {
  final LoteEntrada lote;
  const _LoteCard({required this.lote});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("d 'de' MMMM yyyy", 'es_MX');
    final vivos = lote.brazaletes.length; // simplificación: todos los brazaletes son activos en vista

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.white54),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fmt.format(lote.fechaAdquisicion),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      [
                        lote.tipoAdquisicionNombre,
                        if (lote.proveedor != null) lote.proveedor!,
                        if (lote.costoTotal != null)
                          '\$${lote.costoTotal!.toStringAsFixed(0)}',
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.45),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$vivos/${lote.totalEjemplares}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: 4),
              _CardMenu(
                size: 16,
                onEdit: () => context.push('/lotes-entrada/${lote.id}/editar'),
                onDelete: () {}, // TODO
              ),
            ],
          ),
          if (lote.brazaletes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: lote.brazaletes.map((b) => _BrazaleteBadge(numero: b)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _BrazaleteBadge extends StatelessWidget {
  final int numero;
  const _BrazaleteBadge({required this.numero});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        '#$numero',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET DETALLE GRUPO
// ─────────────────────────────────────────────────────────────────────────────
class _DetalleGrupoSheet extends StatelessWidget {
  final Grupo grupo;
  final TipoAnimal tipo;
  final GrupoConteo conteo;

  const _DetalleGrupoSheet({
    required this.grupo,
    required this.tipo,
    required this.conteo,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Tipo', tipo.nombre),
      ('Grupo', grupo.nombre),
      ('Aves vivas', '${conteo.vivos}'),
      ('Muertes', '${conteo.muertes}'),
      ('Descripción', grupo.descripcion ?? '—'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Text(
            grupo.nombre,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            '${tipo.nombre} · ${conteo.vivos} aves vivas',
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(r.$1, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.45))),
                  ),
                  Expanded(
                    child: Text(r.$2, style: const TextStyle(fontSize: 13, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Editar grupo'),
              onPressed: () {
                Navigator.pop(context);
                context.push('/grupos/${grupo.id}/editar');
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────────────────────

class _TipoSelector extends StatelessWidget {
  final List<TipoAnimal> tipos;
  final List<Grupo> grupos;
  final String value;
  final ValueChanged<String> onChanged;

  const _TipoSelector({
    required this.tipos,
    required this.grupos,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      ('all', 'Todos', grupos.length),
      ...tipos.map((t) => (t.id, t.nombre, grupos.where((g) => g.tipoAnimalId == t.id).length)),
    ];

    final selected = options.firstWhere((o) => o.$1 == value, orElse: () => options.first);

    return GestureDetector(
      onTap: () => _showPicker(context, options),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.label_outline, size: 16, color: Colors.white54),
            const SizedBox(width: 8),
            Text('Tipo: ', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5))),
            Text(
              selected.$2,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${selected.$3}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ),
            const Spacer(),
            const Icon(Icons.expand_more, size: 18, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context, List<(String, String, int)> options) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          ...options.map(
            (o) => ListTile(
              title: Text(o.$2, style: const TextStyle(color: Colors.white)),
              trailing: Text('${o.$3}', style: const TextStyle(color: Colors.white54)),
              selected: o.$1 == value,
              selectedTileColor: Colors.white.withOpacity(0.05),
              onTap: () {
                onChanged(o.$1);
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatTile({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool danger;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: danger ? Colors.redAccent : Colors.white60),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.45))),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: danger
                ? Colors.red.withOpacity(0.3)
                : Colors.white.withOpacity(0.15),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14,
                color: danger ? Colors.redAccent : Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11,
                  color: danger ? Colors.redAccent : Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _SmallButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: danger ? Colors.red.withOpacity(0.35) : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: danger ? Colors.redAccent : Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: danger ? Colors.redAccent : Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final double size;

  const _CardMenu({required this.onEdit, required this.onDelete, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: size, color: Colors.white54),
      color: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('Editar', style: TextStyle(color: Colors.white))),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    );
  }
}

class _FabMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final VoidCallback onTap;

  const _FabMenuItem({
    required this.icon,
    required this.label,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: AppColors.green),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                Text(desc,
                    style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.45))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final List<TipoAnimal> tipos;
  const _EmptyState({required this.tipos});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'No hay grupos todavía',
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            tipos.isEmpty
                ? 'Empieza creando un tipo de animal.'
                : 'Crea un grupo para empezar a registrar ejemplares.',
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: Text(tipos.isEmpty ? 'Crear tipo de animal' : 'Crear grupo'),
            onPressed: () => context.push(tipos.isEmpty ? '/tipos/nuevo' : '/grupos/nuevo'),
          ),
        ],
      ),
    );
  }
}