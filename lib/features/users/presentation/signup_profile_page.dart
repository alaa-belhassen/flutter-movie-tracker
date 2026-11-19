import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/contracts/auth_service.dart';

class SignupCredentials {
  const SignupCredentials({required this.email, required this.password});

  final String email;
  final String password;
}

class SignupProfilePage extends ConsumerStatefulWidget {
  final SignupCredentials? credentials;
  const SignupProfilePage({super.key, this.credentials});

  @override
  ConsumerState<SignupProfilePage> createState() => _SignupProfilePageState();
}

class _SignupProfilePageState extends ConsumerState<SignupProfilePage> {
  final _nicknameController = TextEditingController();
  String _selectedCountry = 'US';
  final Set<String> _selectedGenres = {};
  bool _isSubmitting = false;
  String? _errorMessage;

  final List<String> _genres = [
    'Action',
    'Sci-Fi',
    'Drama',
    'Thriller',
    'Comedy',
    'Romance',
    'Animation',
    'Horror',
  ];

  Future<void> _finishSignup() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.length < 2) {
      setState(() => _errorMessage = 'Nickname must be at least 2 characters.');
      return;
    }

    final credentials = widget.credentials;
    if (credentials == null) {
      setState(
        () =>
            _errorMessage = 'Sign-up details are missing. Please start again.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signUp(
            credentials.email,
            credentials.password,
            nickname,
            country: _selectedCountry,
            favoriteGenres: _selectedGenres.toList(),
          );
      if (!mounted) return;
      context.go('/discover');
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile Setup (Step 2/3)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: 0.66, color: colorScheme.secondary),
            const SizedBox(height: 24),
            Center(
              child: Stack(
                children: [
                  CustomPaint(
                    painter: _DashedCirclePainter(color: colorScheme.secondary),
                    child: const SizedBox(
                      width: 96,
                      height: 96,
                      child: Center(child: Icon(Icons.camera_alt, size: 36)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nicknameController,
              onChanged: (_) => setState(() => _errorMessage = null),
              decoration: InputDecoration(
                labelText: 'Unique Nickname',
                helperText: '2–32 characters; must be unique.',
                prefixIcon: Icon(
                  Icons.person_outline,
                  color: colorScheme.secondary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCountry,
              dropdownColor: colorScheme.surface,
              decoration: const InputDecoration(labelText: 'Country'),
              items: const [
                DropdownMenuItem(value: 'US', child: Text('United States')),
                DropdownMenuItem(value: 'FR', child: Text('France')),
                DropdownMenuItem(value: 'CA', child: Text('Canada')),
                DropdownMenuItem(value: 'UK', child: Text('United Kingdom')),
              ],
              onChanged: (val) =>
                  setState(() => _selectedCountry = val ?? 'US'),
            ),
            const SizedBox(height: 16),
            Text('Favorite Genres', style: textTheme.headlineMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _genres.map((genre) {
                final selected = _selectedGenres.contains(genre);
                return FilterChip(
                  label: Text(genre),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedGenres.add(genre);
                      } else {
                        _selectedGenres.remove(genre);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: TextStyle(color: colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: _isSubmitting ? null : _finishSignup,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final radius = size.width / 2;
    final center = Offset(radius, radius);
    canvas.drawCircle(center, radius - 2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
