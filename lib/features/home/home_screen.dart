import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/settings_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedTab = 0;

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);

    return Theme(
      data: isDark ? AppTheme.dark : AppTheme.light,
      child: Builder(
        builder: (ctx) => Scaffold(
          backgroundColor:
              isDark ? AppColors.bgDark : const Color(0xFFF0F4F8),
          body: SafeArea(
            child: Column(
              children: [
                _AppBar(isDark: isDark, onSettings: _openSettings),
                Expanded(child: _Body(isDark: isDark)),
              ],
            ),
          ),
          bottomNavigationBar: _BottomBar(
            isDark: isDark,
            selected: _selectedTab,
            onTap: (i) => setState(() => _selectedTab = i),
          ),
        ),
      ),
    );
  }
}

// ─── AppBar ───────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  final bool isDark;
  final VoidCallback onSettings;
  const _AppBar({required this.isDark, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.bgCardLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: Text('🐔', style: TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 10),
          Text('Granjas',
              style: TextStyle(
                color: isDark ? AppColors.textPrimary : const Color(0xFF1A1A2E),
                fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4,
              )),
          const Spacer(),
          GestureDetector(
            onTap: onSettings,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isDark ? AppColors.bgCard : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                    color: isDark ? AppColors.border : const Color(0xFFD1D5DB)),
              ),
              child: Icon(Icons.settings_outlined,
                  color: isDark
                      ? AppColors.textSecondary
                      : const Color(0xFF6B7280),
                  size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  final bool isDark;
  const _Body({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _FarmCard(
            nombre: 'Mi Granja',
            owner: 'emilio_alvizo@yahoo.com.mx',
            aves: 8, huevos: 3666, balance: -1720,
            hasImage: true, isDark: isDark,
          ),
          const SizedBox(height: 12),
          _FarmCard(
            nombre: 'Granja Norte',
            owner: 'emilio_alvizo@yahoo.com.mx',
            aves: 24, huevos: 8120, balance: 5430,
            hasImage: false, isDark: isDark,
          ),
          const SizedBox(height: 12),
          _NewFarmButton(isDark: isDark),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── Bottom bar ───────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final bool isDark;
  final int selected;
  final ValueChanged<int> onTap;

  const _BottomBar({
    required this.isDark, required this.selected, required this.onTap,
  });

  static const _icons = [
    Icons.home_rounded,
    Icons.egg_outlined,
    Icons.circle_outlined,
    Icons.grass_outlined,
    Icons.show_chart_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgCard : Colors.white,
        border: Border(
          top: BorderSide(
              color: isDark ? AppColors.border : const Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_icons.length, (i) {
          final sel = i == selected;
          return GestureDetector(
            onTap: () => onTap(i),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: sel
                  ? const BoxDecoration(
                      color: AppColors.bgCardLight, shape: BoxShape.circle)
                  : null,
              child: Icon(_icons[i], size: 22,
                  color: sel
                      ? AppColors.green
                      : (isDark
                          ? AppColors.textSecondary
                          : const Color(0xFF9CA3AF))),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Farm card ────────────────────────────────────────────────────────────────
class _FarmCard extends StatelessWidget {
  final String nombre, owner;
  final int aves, huevos, balance;
  final bool hasImage, isDark;

  const _FarmCard({
    required this.nombre, required this.owner,
    required this.aves, required this.huevos, required this.balance,
    required this.hasImage, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final balanceColor = balance >= 0 ? AppColors.positive : AppColors.negative;
    final balanceStr   = balance >= 0 ? '+$balance \$' : '$balance \$';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.border : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          if (hasImage)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  Container(
                    height: 110, width: double.infinity,
                    color: const Color(0xFF2D4A1E),
                    child: const Center(
                        child: Text('🌿🌾🌿', style: TextStyle(fontSize: 40))),
                  ),
                  Container(
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10, left: 14, right: 14,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(nombre,
                            style: const TextStyle(
                              color: Colors.white, fontSize: 18,
                              fontWeight: FontWeight.w800,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                            )),
                        _InviteChip(),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 10, left: 14,
                    child: Text(owner,
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, hasImage ? 10 : 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasImage) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(nombre,
                          style: TextStyle(
                            color: isDark ? AppColors.textPrimary : const Color(0xFF1A1A2E),
                            fontSize: 17, fontWeight: FontWeight.w800,
                          )),
                      _InviteChip(),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(owner,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    _Stat(value: '$aves',      label: 'Aves',    isDark: isDark),
                    const SizedBox(width: 16),
                    _Stat(value: '$huevos',    label: 'Huevos',  isDark: isDark),
                    const SizedBox(width: 16),
                    _Stat(value: balanceStr,   label: 'Balance', isDark: isDark,
                        valueColor: balanceColor),
                    const Spacer(),
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.bgCardLight : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.home_outlined,
                          size: 15, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.person_add_outlined, color: Colors.white, size: 12),
          SizedBox(width: 4),
          Text('Invitar',
              style: TextStyle(color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _Stat extends StatelessWidget {
  final String value, label;
  final Color? valueColor;
  final bool isDark;

  const _Stat({
    required this.value, required this.label,
    required this.isDark, this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                color: valueColor ??
                    (isDark ? AppColors.textPrimary : const Color(0xFF1A1A2E)),
                fontSize: 15, fontWeight: FontWeight.w700,
              )),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
        ],
      );
}

class _NewFarmButton extends StatelessWidget {
  final bool isDark;
  const _NewFarmButton({required this.isDark});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {},
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.5),
            color: isDark
                ? AppColors.bgCard.withOpacity(0.5)
                : Colors.white.withOpacity(0.5),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: AppColors.textSecondary, size: 18),
              SizedBox(width: 8),
              Text('Nueva granja',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}