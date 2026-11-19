import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/contracts/auth_service.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _stayLoggedIn = true;
  bool _isSubmitting = false;
  String? _emailError;
  String? _passwordError;

  Future<void> _validateAndLogin() async {
    if (_isSubmitting) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _emailError = email.contains('@') && email.contains('.')
          ? null
          : 'Please enter a valid email';
      _passwordError = password.isNotEmpty
          ? null
          : 'Please enter your password';
    });

    if (_emailError == null && _passwordError == null) {
      setState(() => _isSubmitting = true);
      try {
        await ref
            .read(authControllerProvider.notifier)
            .signIn(email, password, rememberMe: _stayLoggedIn);
        if (!mounted) return;
        context.go('/discover');
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: colorScheme.secondary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.local_movies_rounded,
                          color: colorScheme.secondary,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Welcome back',
                      style: textTheme.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your personal cinema, all in one place.',
                      style: textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        errorText: _emailError,
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: colorScheme.secondary,
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        errorText: _passwordError,
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: colorScheme.secondary,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      obscureText: _obscurePassword,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Switch(
                          value: _stayLoggedIn,
                          onChanged: (val) =>
                              setState(() => _stayLoggedIn = val),
                        ),
                        const SizedBox(width: 8),
                        Text('Stay logged in', style: textTheme.bodyLarge),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _validateAndLogin,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => context.go('/discover'),
                      child: const Text('Explore without account'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: const Text('Forgot password?'),
                    ),
                    TextButton(
                      onPressed: () => context.push('/signup'),
                      child: const Text('Create account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
