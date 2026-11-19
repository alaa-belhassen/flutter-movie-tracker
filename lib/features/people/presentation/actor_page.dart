import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/contracts/actor_repository.dart';
import '../../../shared/contracts/auth_service.dart';
import '../../../shared/contracts/fake_data_source.dart';
import '../../../shared/contracts/movie_repository.dart';
import '../../../core/widgets/poster_placeholder.dart';

class ActorPage extends ConsumerStatefulWidget {
  const ActorPage({super.key, required this.actorId});

  final String actorId;

  @override
  ConsumerState<ActorPage> createState() => _ActorPageState();
}

class _ActorPageState extends ConsumerState<ActorPage> {
  late Future<(Actor?, List<Movie>)> _pageData;
  bool _isFollowing = false;
  bool _isUpdatingFollow = false;

  @override
  void initState() {
    super.initState();
    _pageData = _loadPageData();
  }

  Future<(Actor?, List<Movie>)> _loadPageData() async {
    final repository = ref.read(actorRepositoryProvider);
    final actor = await repository.getActorById(widget.actorId);
    if (actor == null) return (null, <Movie>[]);
    final user = ref.read(currentUserProvider);
    if (user != null) {
      final followedIds = await repository.getFollowedActorIds(user.id);
      _isFollowing = followedIds.contains(widget.actorId);
    }
    final filmography = await repository.getActorFilmography(widget.actorId);
    return (actor, filmography);
  }

  Future<void> _toggleFollow() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go('/login');
      return;
    }
    setState(() => _isUpdatingFollow = true);
    try {
      await ref
          .read(actorRepositoryProvider)
          .toggleFollowActor(user.id, widget.actorId);
      if (mounted) setState(() => _isFollowing = !_isFollowing);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _isUpdatingFollow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Actor profile')),
      body: FutureBuilder<(Actor?, List<Movie>)>(
        future: _pageData,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load this actor: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final actor = snapshot.data!.$1;
          if (actor == null) {
            return const Center(child: Text('Actor not found.'));
          }
          final filmography = snapshot.data!.$2;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundImage: actor.photoUrl.isEmpty
                                ? null
                                : NetworkImage(actor.photoUrl),
                            child: actor.photoUrl.isEmpty
                                ? Text(
                                    actor.name.isEmpty
                                        ? '?'
                                        : actor.name[0].toUpperCase(),
                                    style: theme.textTheme.headlineMedium,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  actor.name,
                                  style: theme.textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(actor.role),
                                if (actor.birthplace.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    actor.birthplace,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                                if (user != null) ...[
                                  const SizedBox(height: 12),
                                  FilledButton.tonalIcon(
                                    onPressed: _isUpdatingFollow
                                        ? null
                                        : _toggleFollow,
                                    icon: Icon(
                                      _isFollowing
                                          ? Icons.person_remove_alt_1
                                          : Icons.person_add_alt_1,
                                    ),
                                    label: Text(
                                      _isFollowing ? 'Following' : 'Follow',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (actor.bio.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(actor.bio, style: theme.textTheme.bodyLarge),
                      ],
                      const SizedBox(height: 28),
                      Text('Filmography', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        '${filmography.length} movies',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              if (filmography.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No filmography available.')),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.crossAxisExtent > 650 ? 3 : 2;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.62,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final movie = filmography[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => context.push('/movie/${movie.id}'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: PosterPlaceholder(
                                      title: movie.title,
                                      imagePath: movie.posterPath,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  movie.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall,
                                ),
                                Text(
                                  movie.year > 0
                                      ? '${movie.year} · ${movie.genre}'
                                      : movie.genre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          );
                        }, childCount: filmography.length),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
