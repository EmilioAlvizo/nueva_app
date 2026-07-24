// lib/features/auth/presentation/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/green_button.dart';
import '../../../../shared/widgets/status_banner.dart';
import '../providers/register_provider.dart';
import 'dart:math';
import 'dart:ui';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
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
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(registerProvider.notifier)
        .signUp(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          nombre: _nameCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final registerState = ref.watch(registerProvider);
    final isLoading = registerState is RegisterLoading;
    final error = registerState is RegisterError ? registerState.message : null;
    final needsConfirm = registerState is RegisterSuccessNeedsConfirm;
    final isWide = MediaQuery.sizeOf(context).width > 600;

    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          // Fondo aleatorio
          Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),
          // Overlay leve, solo para parejar el fondo general
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.2)),
          ),
          // Contenido
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                        const AppLogo(size: 72),
                        const SizedBox(height: 16),
                        const Text(
                          'Crear cuenta',
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
                          'Únete para gestionar tu granja eficientemente',
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
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),

                        // ---- Tarjeta con blur ----
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
                                      StatusBanner(
                                        message: error,
                                        isError: true,
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    if (needsConfirm) ...[
                                      const StatusBanner(
                                        message:
                                            'Registro exitoso. Por favor revisa tu correo electrónico para confirmar tu cuenta.',
                                        isError: false,
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    AppTextField(
                                      controller: _nameCtrl,
                                      label: 'Nombre completo',
                                      hint: 'Juan Pérez',
                                      keyboardType: TextInputType.name,
                                      validator: (v) =>
                                          v == null || v.trim().isEmpty
                                          ? 'Ingresa tu nombre'
                                          : null,
                                    ),
                                    const SizedBox(height: 16),
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
                                      onFieldSubmitted: needsConfirm
                                          ? null
                                          : () => _submit(),
                                      validator: (v) =>
                                          v == null || v.length < 6
                                          ? 'Mínimo 6 caracteres'
                                          : null,
                                    ),
                                    const SizedBox(height: 24),
                                    GreenButton(
                                      label: 'Registrarse',
                                      onPressed: needsConfirm ? null : _submit,
                                      isLoading: isLoading,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
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
