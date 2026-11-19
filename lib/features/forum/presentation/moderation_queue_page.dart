import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/contracts/auth_service.dart';
import '../../../shared/contracts/fake_data_source.dart';
import 'forum_providers.dart';

class ModerationQueuePage extends ConsumerStatefulWidget {
  const ModerationQueuePage({super.key});

  @override
  ConsumerState<ModerationQueuePage> createState() =>
      _ModerationQueuePageState();
}

class _ModerationQueuePageState extends ConsumerState<ModerationQueuePage> {
  String? _workingId;

  Future<void> _moderate(String reportId, String action) async {
    final service = ref.read(forumServiceProvider);
    setState(() => _workingId = reportId);
    try {
      await service.updateReportStatus(reportId, action);
      ref.invalidate(moderationDataProvider);
      if (!mounted) return;
      final message = switch (action) {
        'removed' => 'Content removed from the community.',
        'restricted' => 'Member interactions restricted.',
        _ => 'Report dismissed.',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _workingId = null);
    }
  }

  Future<void> _liftRestriction(String restrictionId) async {
    setState(() => _workingId = restrictionId);
    try {
      await ref.read(forumServiceProvider).liftRestriction(restrictionId);
      ref.invalidate(moderationDataProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _workingId = null);
    }
  }

  Future<bool> _confirm(String title, String detail) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(detail),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _confirmAction(String id, String action, String author) async {
    final title = switch (action) {
      'removed' => 'Remove this content?',
      'restricted' => 'Restrict this member?',
      _ => 'Dismiss this report?',
    };
    final detail = switch (action) {
      'removed' => 'The reported content will be hidden from the community.',
      'restricted' =>
        '$author will not be able to create topics or post messages until a moderator lifts the restriction.',
      _ => 'The report will be closed without changing the content.',
    };
    if (await _confirm(title, detail) && mounted) {
      await _moderate(id, action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user?.isModerator != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Moderation')),
        body: const Center(child: Text('Moderator access required.')),
      );
    }
    final data = ref.watch(moderationDataProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community moderation'),
        actions: [
          IconButton(
            tooltip: 'Refresh queue',
            onPressed: () => ref.invalidate(moderationDataProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(moderationDataProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (snapshot) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(moderationDataProvider);
            await ref.read(moderationDataProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _SectionHeading(
                title: 'Pending reports',
                count: snapshot.reports
                    .where((report) => report.status == 'pending')
                    .length,
                icon: Icons.flag_outlined,
              ),
              if (!snapshot.reports.any((report) => report.status == 'pending'))
                const _EmptySection(
                  message: 'No pending reports. The community is up to date.',
                )
              else
                ...snapshot.reports
                    .where((report) => report.status == 'pending')
                    .map(
                      (report) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Chip(
                                    avatar: const Icon(Icons.flag, size: 16),
                                    label: Text(
                                      report.targetType == 'topic'
                                          ? 'Discussion'
                                          : 'Message',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('${report.reportCount} report(s)'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                report.targetExcerpt,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Reported member: ${report.targetAuthorNickname}',
                              ),
                              const SizedBox(height: 6),
                              Text('Reported by: ${report.reporterNicknames}'),
                              const SizedBox(height: 6),
                              Text('Reason: ${report.reason}'),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: colorScheme.error,
                                    ),
                                    onPressed: _workingId == report.id
                                        ? null
                                        : () => _confirmAction(
                                            report.id,
                                            'removed',
                                            report.targetAuthorNickname,
                                          ),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Remove content'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _workingId == report.id
                                        ? null
                                        : () => _confirmAction(
                                            report.id,
                                            'restricted',
                                            report.targetAuthorNickname,
                                          ),
                                    icon: const Icon(Icons.person_off_outlined),
                                    label: const Text('Restrict member'),
                                  ),
                                  TextButton(
                                    onPressed: _workingId == report.id
                                        ? null
                                        : () => _confirmAction(
                                            report.id,
                                            'dismissed',
                                            report.targetAuthorNickname,
                                          ),
                                    child: const Text('Dismiss'),
                                  ),
                                ],
                              ),
                              if (_workingId == report.id)
                                const LinearProgressIndicator(),
                            ],
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 20),
              _SectionHeading(
                title: 'Report history',
                count: snapshot.reports
                    .where((report) => report.status != 'pending')
                    .length,
                icon: Icons.history,
              ),
              if (!snapshot.reports.any((report) => report.status != 'pending'))
                const _EmptySection(
                  message: 'No reports have been reviewed yet.',
                )
              else
                ...snapshot.reports
                    .where((report) => report.status != 'pending')
                    .map(
                      (report) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            report.status == 'removed'
                                ? Icons.delete_outline
                                : report.status == 'restricted'
                                ? Icons.person_off_outlined
                                : Icons.check_circle_outline,
                          ),
                          title: Text(report.targetExcerpt),
                          subtitle: Text(
                            '${report.targetAuthorNickname} · ${report.reason}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Chip(
                            label: Text(switch (report.status) {
                              'removed' => 'Removed',
                              'restricted' => 'Restricted',
                              _ => 'Dismissed',
                            }),
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 20),
              _SectionHeading(
                title: 'Active restrictions',
                count: snapshot.restrictions.length,
                icon: Icons.gavel_outlined,
              ),
              if (snapshot.restrictions.isEmpty)
                const _EmptySection(
                  message: 'No members are currently restricted.',
                )
              else
                ...snapshot.restrictions.map(
                  (restriction) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_off_outlined),
                      ),
                      title: Text(restriction.userNickname),
                      subtitle: Text(
                        restriction.reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: TextButton(
                        onPressed: _workingId == restriction.id
                            ? null
                            : () => _liftRestriction(restriction.id),
                        child: const Text('Lift'),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.count,
    required this.icon,
  });

  final String title;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        Badge(label: Text('$count')),
      ],
    ),
  );
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(18), child: Text(message)),
  );
}
