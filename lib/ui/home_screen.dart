import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/providers.dart';
import 'common.dart';
import 'master_list_screen.dart';
import 'place_detail_screen.dart';
import 'place_edit_screen.dart';

enum StatusFilter { all, want, visited }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  StatusFilter _status = StatusFilter.all;
  int? _categoryId;
  int? _areaId;
  String _query = '';

  List<PlaceSummary> _apply(
    List<PlaceSummary> list, {
    required int? categoryId,
    required int? areaId,
  }) {
    final q = _query.toLowerCase();
    return list.where((s) {
      switch (_status) {
        case StatusFilter.want:
          if (s.visited) return false;
        case StatusFilter.visited:
          if (!s.visited) return false;
        case StatusFilter.all:
          break;
      }
      if (categoryId != null && s.place.categoryId != categoryId) {
        return false;
      }
      if (areaId != null && s.place.areaId != areaId) return false;
      if (q.isNotEmpty) {
        final hay = [
          s.place.name,
          s.place.address,
          s.place.memo,
          s.place.wantWith,
          s.category?.name ?? '',
          s.area?.name ?? '',
        ].join('\n').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  void _openMasters(MasterKind kind) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MasterListScreen(kind: kind)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final placesAsync = ref.watch(placeListProvider);
    final categories =
        ref.watch(mastersProvider(MasterKind.category)).value ?? const [];
    final areas = ref.watch(mastersProvider(MasterKind.area)).value ?? const [];

    // 削除済みのカテゴリ/エリアで絞り込んだままにならないように
    final categoryId =
        categories.any((e) => e.id == _categoryId) ? _categoryId : null;
    final areaId = areas.any((e) => e.id == _areaId) ? _areaId : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Place Memo'),
        actions: [
          PopupMenuButton<MasterKind>(
            onSelected: _openMasters,
            itemBuilder: (_) => [
              for (final k in MasterKind.values)
                PopupMenuItem(value: k, child: Text('${k.label}の管理')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '名前・住所・メモで検索',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<StatusFilter>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: StatusFilter.all, label: Text('すべて')),
                  ButtonSegment(
                      value: StatusFilter.want, label: Text('行きたい')),
                  ButtonSegment(
                      value: StatusFilter.visited, label: Text('行った')),
                ],
                selected: {_status},
                onSelectionChanged: (s) => setState(() => _status = s.first),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: MasterDropdown(
                    label: 'カテゴリ',
                    nullLabel: 'すべて',
                    items: categories,
                    value: categoryId,
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MasterDropdown(
                    label: 'エリア',
                    nullLabel: 'すべて',
                    items: areas,
                    value: areaId,
                    onChanged: (v) => setState(() => _areaId = v),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: placesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('読み込みエラー: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return const _EmptyMessage(
                    '気になるお店や観光地を\n右下の「追加」からメモしましょう',
                  );
                }
                final filtered =
                    _apply(list, categoryId: categoryId, areaId: areaId);
                if (filtered.isEmpty) {
                  return const _EmptyMessage('条件に合うメモがありません');
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _PlaceTile(summary: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PlaceEditScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('追加'),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.summary});

  final PlaceSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final scheme = Theme.of(context).colorScheme;
    final sub = [s.category?.name, s.area?.name].whereType<String>().join(' ・ ');

    final Widget trailing;
    if (s.visited) {
      trailing = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (s.avgRating != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, size: 16, color: Colors.amber),
                Text(s.avgRating!.toStringAsFixed(1)),
              ],
            ),
          Text('${s.visitCount}回',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    } else {
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('行きたい',
            style: TextStyle(fontSize: 12, color: scheme.onSecondaryContainer)),
      );
    }

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: PlaceThumb(imageName: s.place.imagePath),
        title: Text(s.place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: sub.isEmpty ? null : Text(sub, maxLines: 1),
        trailing: trailing,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaceDetailScreen(placeId: s.place.id),
          ),
        ),
      ),
    );
  }
}
