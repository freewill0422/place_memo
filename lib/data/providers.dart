import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'image_store.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// main() で保存先フォルダを決めてから上書きする。
final imageStoreProvider = Provider<ImageStore>(
  (ref) => throw UnimplementedError('main() で overrideWithValue すること'),
);

final placeListProvider = StreamProvider<List<PlaceSummary>>(
  (ref) => ref.watch(databaseProvider).watchPlaceSummaries(),
);

final visitsProvider = StreamProvider.autoDispose.family<List<Visit>, int>(
  (ref, placeId) => ref.watch(databaseProvider).watchVisits(placeId),
);

final mastersProvider = StreamProvider.family<List<MasterItem>, MasterKind>(
  (ref, kind) => ref.watch(databaseProvider).watchMasters(kind),
);
