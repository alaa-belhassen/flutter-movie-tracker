import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/movie_list_tile.dart';
import '../../../shared/contracts/auth_service.dart';
import '../../../shared/contracts/fake_data_source.dart';
import '../../../shared/contracts/movie_repository.dart';
import '../../../shared/contracts/watchlist_service.dart';

class SharedListPage extends ConsumerStatefulWidget {
  const SharedListPage({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<SharedListPage> createState() => _SharedListPageState();
}

class _SharedListPageState extends ConsumerState<SharedListPage> {
  late Future<CustomList> _listFuture;

  @override
  void initState() {
    super.initState();
    _listFuture = ref
        .read(watchlistServiceProvider)
        .getCustomList(widget.listId);
  }

  void _reload() {
    setState(() {
      _listFuture = ref
          .read(watchlistServiceProvider)
          .getCustomList(widget.listId);
    });
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));
  }

  Future<void> _invite(CustomList list) async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite a collaborator'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Invites are added immediately and only work for registered accounts.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Account email',
                hintText: 'friend@example.com',
              ),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Invite'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.trim().isEmpty) return;
    try {
      await ref.read(watchlistServiceProvider).inviteToList(list.id, email);
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Collaborator added to the list.')),
        );
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _changeSharing(CustomList list, bool isShared) async {
    try {
      await ref
          .read(watchlistServiceProvider)
          .saveCustomList(
            CustomList(
              id: list.id,
              title: list.title,
              userId: list.userId,
              movieIds: list.movieIds,
              isShared: isShared,
              memberIds: list.memberIds,
              members: list.members,
            ),
          );
      _reload();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _removeMember(CustomList list, CustomListMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove collaborator?'),
        content: Text('${member.nickname} will lose access to this list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(watchlistServiceProvider)
          .removeListMember(list.id, member.id);
      _reload();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _addMovie(CustomList list) async {
    final movie = await showDialog<Movie>(
      context: context,
      builder: (context) => const _MovieSearchDialog(),
    );
    if (movie == null) return;
    try {
      final service = ref.read(watchlistServiceProvider);
      if (list.isShared) {
        await service.addMovieToList(list.id, movie.id);
      } else {
        if (list.movieIds.contains(movie.id)) return;
        await service.saveCustomList(
          CustomList(
            id: list.id,
            title: list.title,
            userId: list.userId,
            movieIds: [...list.movieIds, movie.id],
            isShared: false,
          ),
        );
      }
      _reload();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _removeMovie(CustomList list, String movieId) async {
    try {
      final service = ref.read(watchlistServiceProvider);
      if (list.isShared) {
        await service.removeMovieFromList(list.id, movieId);
      } else {
        await service.saveCustomList(
          CustomList(
            id: list.id,
            title: list.title,
            userId: list.userId,
            movieIds: list.movieIds.where((id) => id != movieId).toList(),
            isShared: false,
          ),
        );
      }
      _reload();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteOrLeave(CustomList list, bool isOwner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isOwner ? 'Delete this list?' : 'Leave this list?'),
        content: Text(
          isOwner
              ? 'The list and its members will be removed.'
              : 'You will no longer have access to this shared list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isOwner ? 'Delete' : 'Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final service = ref.read(watchlistServiceProvider);
      if (isOwner) {
        await service.deleteCustomList(list.id);
      } else {
        await service.leaveSharedList(list.id);
      }
      if (mounted) context.pop();
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movie list'),
        actions: [
          FutureBuilder<CustomList>(
            future: _listFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData || user == null) {
                return const SizedBox.shrink();
              }
              final list = snapshot.data!;
              final isOwner = list.userId == user.id;
              return IconButton(
                tooltip: isOwner ? 'Delete list' : 'Leave list',
                icon: Icon(isOwner ? Icons.delete_outline : Icons.logout),
                onPressed: () => _deleteOrLeave(list, isOwner),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<CustomList>(
        future: _listFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not open this list.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _reload,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data!;
          final isOwner = user?.id == list.userId;
          return _buildList(context, list, isOwner);
        },
      ),
    );
  }

  Widget _buildList(BuildContext context, CustomList list, bool isOwner) {
    final canEdit = isOwner || list.isShared;
    final movieRepository = ref.watch(movieRepositoryProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      list.isShared
                          ? Icons.group_outlined
                          : Icons.movie_outlined,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        list.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${list.movieIds.length} movies · '
                  '${isOwner ? 'Your list' : 'Shared with you'}',
                ),
                if (isOwner)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Shared list'),
                    subtitle: Text(
                      list.isShared
                          ? 'Members can add and remove movies.'
                          : 'Turn on sharing to invite collaborators.',
                    ),
                    value: list.isShared,
                    onChanged: (value) => _changeSharing(list, value),
                  ),
                if (isOwner && list.isShared)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _invite(list),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Invite by email'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (list.isShared && list.members.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Collaborators', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...list.members.map(
            (member) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    member.nickname.isEmpty
                        ? '?'
                        : member.nickname.substring(0, 1).toUpperCase(),
                  ),
                ),
                title: Text(member.nickname),
                subtitle: Text(member.email),
                trailing: isOwner
                    ? IconButton(
                        tooltip: 'Remove collaborator',
                        icon: const Icon(Icons.person_remove_outlined),
                        onPressed: () => _removeMember(list, member),
                      )
                    : null,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Movies',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (canEdit)
              FilledButton.tonalIcon(
                onPressed: () => _addMovie(list),
                icon: const Icon(Icons.add),
                label: const Text('Add movie'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (list.movieIds.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('No movies in this list yet.')),
          )
        else
          FutureBuilder<List<Movie?>>(
            future: Future.wait(
              list.movieIds.map(movieRepository.getMovieById),
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Could not load list movies.')),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final movies = snapshot.data!.whereType<Movie>();
              if (movies.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No valid movie details found.')),
                );
              }
              return Column(
                children: [
                  for (final movie in movies)
                    MovieListTile(
                      title: movie.title,
                      subtitle:
                          '${movie.year} · ${movie.genre} · ${movie.duration}',
                      rating: movie.rating,
                      posterPath: movie.posterPath,
                      onTap: () => context.push('/movie/${movie.id}'),
                      isBookmarked: true,
                      onBookmarkToggle: canEdit
                          ? () => _removeMovie(list, movie.id)
                          : null,
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _MovieSearchDialog extends ConsumerStatefulWidget {
  const _MovieSearchDialog();

  @override
  ConsumerState<_MovieSearchDialog> createState() => _MovieSearchDialogState();
}

class _MovieSearchDialogState extends ConsumerState<_MovieSearchDialog> {
  final _queryController = TextEditingController();
  Future<List<Movie>>? _search;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _searchMovies() {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _search = ref.read(movieRepositoryProvider).searchMovies(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a movie'),
      content: SizedBox(
        width: 420,
        height: 360,
        child: Column(
          children: [
            TextField(
              controller: _queryController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search movies',
                suffixIcon: IconButton(
                  onPressed: _searchMovies,
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (_) => _searchMovies(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _search == null
                  ? const Center(child: Text('Search TMDB to add a movie.'))
                  : FutureBuilder<List<Movie>>(
                      future: _search,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                            child: Text('Movie search failed. Try again.'),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final movies = snapshot.data!;
                        if (movies.isEmpty) {
                          return const Center(
                            child: Text('No matching movies found.'),
                          );
                        }
                        return ListView.builder(
                          itemCount: movies.length,
                          itemBuilder: (context, index) {
                            final movie = movies[index];
                            return ListTile(
                              leading: const Icon(Icons.movie_outlined),
                              title: Text(
                                movie.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text('${movie.year} · ${movie.genre}'),
                              onTap: () => Navigator.pop(context, movie),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
