import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/contracts/auth_service.dart';
import 'user_stats_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  static const _genres = [
    'Action',
    'Adventure',
    'Animation',
    'Comedy',
    'Crime',
    'Documentary',
    'Drama',
    'Family',
    'Fantasy',
    'History',
    'Horror',
    'Music',
    'Mystery',
    'Romance',
    'Sci-Fi',
    'Science Fiction',
    'Thriller',
    'War',
    'Western',
  ];
  static const _countries = {
    'US': 'United States',
    'FR': 'France',
    'CA': 'Canada',
    'UK': 'United Kingdom',
  };

  final _nicknameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final Set<String> _selectedGenres = {};
  String _country = 'US';
  String? _loadedUserId;
  bool _isSaving = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  void _syncForm(UserProfile user) {
    if (_loadedUserId == user.id) return;
    _loadedUserId = user.id;
    _nicknameController.text = user.nickname;
    _country = _countries.containsKey(user.country) ? user.country : 'US';
    _selectedGenres
      ..clear()
      ..addAll(user.favoriteGenres.where(_genres.contains));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(currentUserProvider)?.id;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            nickname: _nicknameController.text.trim(),
            country: _country,
            favoriteGenres: _selectedGenres.toList(growable: false),
          );
      if (userId != null) ref.invalidate(userStatsProvider(userId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My profile')),
        body: const Center(child: Text('Sign in to view your profile.')),
      );
    }
    _syncForm(user);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withValues(alpha: 0.72),
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: colorScheme.onPrimary.withValues(
                      alpha: 0.18,
                    ),
                    child: Text(
                      user.nickname.isEmpty
                          ? '?'
                          : user.nickname[0].toUpperCase(),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.nickname,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onPrimary.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                        if (user.isModerator) ...[
                          const SizedBox(height: 8),
                          const Chip(
                            avatar: Icon(Icons.shield_outlined, size: 16),
                            label: Text('Moderator'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text('Account details', style: theme.textTheme.titleLarge),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nicknameController,
              maxLength: 32,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nickname',
                helperText: 'This is how other movie fans see you.',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final nickname = value?.trim() ?? '';
                if (nickname.length < 2 || nickname.length > 32) {
                  return 'Use between 2 and 32 characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Country',
                prefixIcon: Icon(Icons.public),
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _country,
                  isExpanded: true,
                  items: _countries.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text('${entry.value} (${entry.key})'),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setState(() => _country = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text('Your movie taste', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Choose genres to personalize discovery and recommendations.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _genres
                  .map((genre) {
                    final selected = _selectedGenres.contains(genre);
                    return FilterChip(
                      label: Text(genre),
                      selected: selected,
                      onSelected: (value) => setState(() {
                        if (value) {
                          _selectedGenres.add(genre);
                        } else {
                          _selectedGenres.remove(genre);
                        }
                      }),
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_isSaving ? 'Saving...' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
