import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/contracts/fake_data_source.dart';

final userStatsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>(
      (ref, userId) => ref.watch(reviewServiceProvider).getUserStats(userId),
    );
