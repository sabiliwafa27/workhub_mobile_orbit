import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/erp_colors.dart';
import '../../../core/theme/orbit_backdrop.dart';
import '../../../core/theme/orbit_motion.dart';
import '../../../core/theme/orbit_theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).login(
          email: _emailController.text,
          password: _passwordController.text,
          rememberMe: _rememberMe,
        );

    if (!success && mounted) {
      final error = ref.read(authProvider).errorMessage;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: ErpColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: OrbitColors.scaffoldBackground,
      body: OrbitBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: OrbitEntrance(child: _buildLoginCard(authState)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(AuthState authState) {
    return Container(
      decoration: BoxDecoration(
        color: OrbitColors.cardSurface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1406244D),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Brand Header
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [OrbitColors.bubbleBlue, Colors.white],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: OrbitColors.bubbleBlueBorder),
                  ),
                  child: const Icon(
                    Icons.business_center_rounded,
                    size: 40,
                    color: OrbitColors.primaryNavy,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'WorkHub Mobile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: ErpColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sign in to access Orbit Field & Tasks',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: ErpColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),

              // Email input
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password input
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Remember me
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    activeColor: ErpColors.primaryNavy,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) {
                      setState(() => _rememberMe = val ?? true);
                    },
                  ),
                  const Text(
                    'Remember Me',
                    style:
                        TextStyle(fontSize: 13, color: ErpColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Submit button
              FilledButton(
                onPressed: authState.isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: ErpColors.primaryNavy,
                  foregroundColor: Colors.white,
                ),
                child: authState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Sign In',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
