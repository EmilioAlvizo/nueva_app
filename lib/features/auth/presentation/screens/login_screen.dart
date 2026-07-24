// lib/features/auth/presentation/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/green_button.dart';
import '../../../../shared/widgets/status_banner.dart';
import '../providers/login_provider.dart';
import 'dart:math';
import 'dart:ui';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  late final String _bgImage;

  @override
  void initState() {
    const List<String> kAuthBackgroundImages = [
      'assets/icon/inicio.jpg',
      'assets/icon/inicio2.jpg',
      'assets/icon/inicio3.jpg',
    ];
    super.initState();
    _bgImage =
        kAuthBackgroundImages[Random().nextInt(kAuthBackgroundImages.length)];

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(loginProvider.notifier)
        .signIn(email: _emailCtrl.text.trim(), password: _passCtrl.text);
    // Navigation handled by GoRouter redirect reacting to authSessionProvider
  }

  @override
  Widget build(BuildContext context) {
    // Listen for errors — we don't navigate here, the router handles that.
    final loginState = ref.watch(loginProvider);
    final isLoading = loginState is LoginLoading;
    final error = loginState is LoginError ? loginState.message : null;
    final isWide = MediaQuery.sizeOf(context).width > 600;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),
          // Overlay oscuro para que el texto/formulario se lea bien
          Positioned.fill(
            child: Container(color: AppColors.bg.withValues(alpha: 0.2)),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isWide ? 400 : double.infinity,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const AppLogo(size: 88),
                        const SizedBox(height: 20),
                        const Text(
                          'GallinasApp',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 12,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Gestión inteligente de tu granja',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            shadows: [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 8,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ---- Tarjeta con blur que contiene el Form ----
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                24,
                                20,
                                24,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    if (error != null) ...[
                                      StatusBanner(message: error),
                                      const SizedBox(height: 16),
                                    ],
                                    AppTextField(
                                      controller: _emailCtrl,
                                      label: 'Correo electrónico',
                                      hint: 'tu@correo.com',
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (v) =>
                                          v == null || !v.contains('@')
                                          ? 'Ingresa un correo válido'
                                          : null,
                                    ),
                                    const SizedBox(height: 16),
                                    AppTextField(
                                      controller: _passCtrl,
                                      label: 'Contraseña',
                                      hint: '••••••••',
                                      isPassword: true,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: _submit,
                                      validator: (v) =>
                                          v == null || v.length < 6
                                          ? 'Mínimo 6 caracteres'
                                          : null,
                                    ),
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () {},
                                        child: const Text(
                                          '¿Olvidaste tu contraseña?',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    GreenButton(
                                      label: 'Iniciar sesión',
                                      onPressed: _submit,
                                      isLoading: isLoading,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '¿No tienes cuenta? ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                shadows: [
                                  Shadow(color: Colors.black87, blurRadius: 6),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                ref.read(loginProvider.notifier).reset();
                                context.push(AppRoutes.register);
                              },
                              child: const Text(
                                'Regístrate',
                                style: TextStyle(
                                  color: AppColors.green,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black87,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
