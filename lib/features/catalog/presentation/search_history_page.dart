import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/contracts/movie_repository.dart';
import '../../../shared/contracts/fake_data_source.dart';

class SearchHistoryPage extends ConsumerWidget {
  const SearchHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movieRepo = ref.watch(movieRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              await movieRepo.clearSearchHistory();
              (context as Element).markNeedsBuild();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<SearchHistoryItem>>(
        future: movieRepo.getSearchHistory(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final history = snapshot.data!;
          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              return ListTile(
                title: Text(item.query),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    await movieRepo.deleteSearchHistory(item.id);
                    (context as Element).markNeedsBuild();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
