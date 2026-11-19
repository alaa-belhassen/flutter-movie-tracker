import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/contracts/fake_data_source.dart';

class TonightPickerPage extends ConsumerStatefulWidget {
  const TonightPickerPage({super.key});

  @override
  ConsumerState<TonightPickerPage> createState() => _TonightPickerPageState();
}

class _TonightPickerPageState extends ConsumerState<TonightPickerPage> {
  double _maxDuration = 150;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _pickMovie() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final movieRepository = ref.read(movieRepositoryProvider);
      final candidates = await movieRepository.getMovies(
        maxRuntimeMinutes: _maxDuration.toInt(),
      );
      if (candidates.isEmpty) {
        setState(() {
          _errorMessage = 'TMDB found no movies within this duration.';
          _isLoading = false;
        });
        return;
      }

      final selected = candidates[Random().nextInt(candidates.length)];
      final movie = await movieRepository.getMovieById(selected.id);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (movie == null) {
        setState(() => _errorMessage = 'Could not load the selected movie.');
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Tonight's pick"),
          content: Text(
            movie.duration == 'Runtime unavailable'
                ? movie.title
                : '${movie.title}\n${movie.duration}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/movie/${movie.id}');
              },
              child: const Text('View movie'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tonight Picker')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Max Duration: ${_maxDuration.toInt()} minutes',
              style: textTheme.headlineMedium,
            ),
            Slider(
              value: _maxDuration,
              min: 60,
              max: 240,
              divisions: 18,
              label: '${_maxDuration.toInt()} mins',
              onChanged: (val) => setState(() => _maxDuration = val),
            ),
            const Spacer(),
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: _isLoading ? null : _pickMovie,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Pick for me tonight'),
            ),
          ],
        ),
      ),
    );
  }
}
