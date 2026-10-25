import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/master_entity.dart';
import '../../core/data/providers.dart';

/// Records of a master entity (respecting its fixed values).
final masterRecordsProvider = StreamProvider.autoDispose
    .family<List<MasterRecord>, MasterEntityConfig>(
      (ref, config) => ref.watch(masterRepositoryProvider).watch(config),
    );

/// All records of a collection; used for reference dropdowns and dashboards.
final collectionRecordsProvider = StreamProvider.autoDispose
    .family<List<MasterRecord>, String>(
      (ref, collection) => ref
          .watch(masterRepositoryProvider)
          .watch(
            MasterEntityConfig(
              collection: collection,
              module: '',
              title: '',
              singular: '',
              fields: const [],
            ),
          ),
    );
