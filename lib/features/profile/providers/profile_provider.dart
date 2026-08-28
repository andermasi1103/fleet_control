import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/datasources/profile_data_source.dart';

final profileDataSourceProvider = Provider<ProfileDataSource>((ref) {
  return ProfileDataSource(ref.watch(backendApiClientProvider));
});

/// Ephemeral UI state only. Password values stay in local controllers.
final profileChangingProvider = StateProvider<bool>((ref) => false);
