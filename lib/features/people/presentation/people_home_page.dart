import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/contracts/auth_service.dart';
import '../../../shared/contracts/actor_repository.dart';
import '../../../shared/contracts/fake_data_source.dart';

class PeopleHomePage extends ConsumerStatefulWidget {
  const PeopleHomePage({super.key});

  @override
  ConsumerState<PeopleHomePage> createState() => _PeopleHomePageState();
}

class _PeopleHomePageState extends ConsumerState<PeopleHomePage> {
  final _searchController = TextEditingController();
  late Future<List<Actor>> _popularActors;
  Future<List<Actor>>? _searchResults;
  Future<List<Actor>>? _followedActors;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    final repository = ref.read(actorRepositoryProvider);
    _popularActors = _withFollowingState(repository.getActors());
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _followedActors = ref
          .read(actorRepositoryProvider)
          .getFollowedActors(user.id);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      setState(() {
        _isSearching = false;
        _searchResults = null;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _searchResults = _withFollowingState(
        ref.read(actorRepositoryProvider).searchActors(query),
      );
    });
  }

  Future<List<Actor>> _withFollowingState(
    Future<List<Actor>> actorsFuture,
  ) async {
    final actors = await actorsFuture;
    final user = ref.read(currentUserProvider);
    if (user == null) return actors;
    final followedIds = await ref
        .read(actorRepositoryProvider)
        .getFollowedActorIds(user.id);
    return actors
        .map(
          (actor) => Actor(
            id: actor.id,
            name: actor.name,
            role: actor.role,
            birthplace: actor.birthplace,
            bio: actor.bio,
            photoUrl: actor.photoUrl,
            movieIds: actor.movieIds,
            isFollowing: followedIds.contains(actor.id),
          ),
        )
        .toList(growable: false);
  }

  void _reloadActorData() {
    final user = ref.read(currentUserProvider);
    final repository = ref.read(actorRepositoryProvider);
    setState(() {
      _popularActors = _withFollowingState(repository.getActors());
      if (_isSearching && _searchController.text.trim().length >= 2) {
        _searchResults = _withFollowingState(
          repository.searchActors(_searchController.text.trim()),
        );
      }
      if (user != null) {
        _followedActors = repository.getFollowedActors(user.id);
      }
    });
  }

  Future<void> _followActor(Actor actor) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }
    try {
      final repository = ref.read(actorRepositoryProvider);
      final followedIds = await repository.getFollowedActorIds(user.id);
      if (!followedIds.contains(actor.id)) {
        await repository.toggleFollowActor(user.id, actor.id);
      }
      if (!mounted) return;
      _reloadActorData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            followedIds.contains(actor.id)
                ? 'You already follow ${actor.name}.'
                : 'Following ${actor.name}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Widget _actorCard(Actor actor, {bool? followed}) {
    final textTheme = Theme.of(context).textTheme;
    final isFollowed = followed ?? actor.isFollowing;
    return Card(
      child: ListTile(
        leading: _ActorAvatar(actor: actor, radius: 25),
        title: Text(actor.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          isFollowed ? 'Followed actor' : actor.role,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall,
        ),
        trailing: isFollowed
            ? const Icon(Icons.check_circle, color: Colors.green)
            : IconButton(
                tooltip: 'Follow ${actor.name}',
                onPressed: () => _followActor(actor),
                icon: const Icon(Icons.person_add_alt_1),
              ),
        onTap: () async {
          await context.push('/people/actor/${actor.id}');
          if (mounted) _reloadActorData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user != null && _followedActors == null) {
      _followedActors = ref
          .read(actorRepositoryProvider)
          .getFollowedActors(user.id);
    }
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Actors & Casting')),
      body: RefreshIndicator(
        onRefresh: () async {
          _reloadActorData();
          await _popularActors;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Text(
              'Discover people behind the movies',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Follow actors to shape a movie feed around the performances you love.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search actors and filmmakers',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  onPressed: _search,
                  icon: const Icon(Icons.arrow_forward),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (user != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your followed actors',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/people/for-you'),
                    child: const Text('Recommendations'),
                  ),
                ],
              ),
              if (_followedActors == null)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                FutureBuilder<List<Actor>>(
                  future: _followedActors,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text(
                        'Could not load followed actors: ${snapshot.error}',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.data!.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Follow an actor to get personalized movie recommendations.',
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: snapshot.data!
                          .map((actor) => _actorCard(actor, followed: true))
                          .toList(growable: false),
                    );
                  },
                ),
              const SizedBox(height: 16),
            ],
            Text(
              _isSearching ? 'Search results' : 'Popular people',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Actor>>(
              future: _isSearching ? _searchResults : _popularActors,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Could not load actors: ${snapshot.error}');
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No people found. Try another name.'),
                  );
                }
                return Column(
                  children: snapshot.data!
                      .map((actor) => _actorCard(actor))
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActorAvatar extends StatelessWidget {
  const _ActorAvatar({required this.actor, required this.radius});

  final Actor actor;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundImage: actor.photoUrl.isEmpty
        ? null
        : NetworkImage(actor.photoUrl),
    child: actor.photoUrl.isEmpty
        ? Text(actor.name.isEmpty ? '?' : actor.name[0].toUpperCase())
        : null,
  );
}
