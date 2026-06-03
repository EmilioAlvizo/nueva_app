import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../home/home_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey     = GlobalKey<FormState>();
  final _nombreCtrl  = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.07), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final navigateHome = await ref.read(registerProvider.notifier).signUp(
          email:    _emailCtrl.text.trim(),
          password: _passCtrl.text,
          nombre:   _nombreCtrl.text.trim(),
        );

    if (navigateHome && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    }
    // If !navigateHome, the notifier already holds the success / error message
  }

  @override
  Widget build(BuildContext context) {
    final auth   = ref.watch(registerProvider);
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: isWide ? 400 : double.infinity),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.bgCard,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppColors.textSecondary,
                            size: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Center(child: const AppLogo(size: 72)),
                      const SizedBox(height: 16),

                      const Center(
                        child: Text('Crear cuenta',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            )),
                      ),
                      const SizedBox(height: 4),
                      const Center(
                        child: Text('Únete a GallinasApp',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ),
                      const SizedBox(height: 28),

                      // Banners
                      if (auth.hasError) ...[
                        StatusBanner(message: auth.errorMessage!),
                        const SizedBox(height: 16),
                      ],
                      if (auth.successMessage != null) ...[
                        StatusBanner(
                            message: auth.successMessage!, isError: false),
                        const SizedBox(height: 16),
                      ],

                      AppTextField(
                        controller: _nombreCtrl,
                        label: 'Nombre completo',
                        hint: 'Juan Pérez',
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
                        validator: (v) =>
                            v == null || v.length < 6
                                ? 'Mínimo 6 caracteres'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _confirmCtrl,
                        label: 'Confirmar contraseña',
                        hint: '••••••••',
                        isPassword: true,
                        validator: (v) =>
                            v != _passCtrl.text
                                ? 'Las contraseñas no coinciden'
                                : null,
                      ),
                      const SizedBox(height: 28),

                      GreenButton(
                        label: 'Registrarse',
                        onPressed: auth.successMessage != null ? null : _submit,
                        isLoading: auth.isLoading,
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('¿Ya tienes cuenta? ',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: const Text('Inicia sesión',
                                style: TextStyle(
                                  color: AppColors.green,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                )),
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
      ),
    );
  }
}