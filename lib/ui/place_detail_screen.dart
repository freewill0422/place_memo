import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/providers.dart';
import 'common.dart';
import 'place_edit_screen.dart';
import 'visit_edit_sheet.dart';

class PlaceDetailScreen extends ConsumerWidget {
  const PlaceDetailScreen({super.key, required this.placeId});

  final int placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(placeListProvider).when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('読み込みエラー: $e')),
          ),
          data: (list) {
            PlaceSummary? found;
            for (final s in list) {
              if (s.place.id == placeId) {
                found = s;
                break;
              }
            }
            if (found == null) {
              return Scaffold(
                appBar: AppBar(),
                body: const Center(child: Text('このメモは削除されました')),
              );
            }
            return _DetailBody(summary: found);
          },
        );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.summary});

  final PlaceSummary summary;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      message: '「${summary.place.name}」を削除しますか?\n訪問記録もすべて消えます。',
    );
    if (!ok || !context.mounted) return;
    final db = ref.read(databaseProvider);
    final store = ref.read(imageStoreProvider);
    Navigator.pop(context);
    await db.deletePlace(summary.place.id);
    await store.delete(summary.place.imagePath);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = summary.place;
    final theme = Theme.of(context);
    final store = ref.watch(imageStoreProvider);
    final visitsAsync = ref.watch(visitsProvider(p.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          IconButton(
            tooltip: '編集',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PlaceEditScreen(initial: p)),
            ),
          ),
          IconButton(
            tooltip: '削除',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (p.imagePath != null)
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      _ImageViewer(file: store.fileOf(p.imagePath!).path),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 280,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Image.file(
                    store.fileOf(p.imagePath!),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (summary.category != null)
                Chip(
                  avatar: const Icon(Icons.label_outline, size: 18),
                  label: Text(summary.category!.name),
                ),
              if (summary.area != null)
                Chip(
                  avatar: const Icon(Icons.map_outlined, size: 18),
                  label: Text(summary.area!.name),
                ),
              Chip(
                avatar: Icon(
                  summary.visited ? Icons.check_circle : Icons.bookmark_border,
                  size: 18,
                ),
                label: Text(summary.visited
                    ? '行った(${summary.visitCount}回)'
                    : '行きたい'),
              ),
            ],
          ),
          if (p.address.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_outlined),
              title: Text(p.address),
              trailing: IconButton(
                tooltip: '地図で開く',
                icon: const Icon(Icons.map),
                onPressed: () => openMap(context, p.address),
              ),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.map_outlined),
              title: const Text('名前で地図を検索'),
              onTap: () => openMap(
                  context, [p.name, summary.area?.name ?? ''].join(' ').trim()),
            ),
          if (p.url.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link),
              title: Text(p.url, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => openExternal(context, p.url),
            ),
          if (p.wantWith.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.people_outline),
              title: const Text('一緒に行きたい人'),
              subtitle: Text(p.wantWith),
            ),
          if (p.memo.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notes),
              title: const Text('メモ'),
              subtitle: Text(p.memo),
            ),
          const Divider(height: 32),
          Row(
            children: [
              Text('訪問記録', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (summary.avgRating != null) ...[
                RatingStars(value: summary.avgRating),
                const SizedBox(width: 4),
                Text(summary.avgRating!.toStringAsFixed(1)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          visitsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('読み込みエラー: $e'),
            data: (visits) {
              if (visits.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'まだ行っていません',
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                );
              }
              return Column(
                children: [
                  for (final v in visits)
                    Card(
                      child: ListTile(
                        title: Row(
                          children: [
                            Text(formatDate(v.visitedOn)),
                            const SizedBox(width: 12),
                            if (v.rating != null)
                              RatingStars(
                                  value: v.rating!.toDouble(), size: 16),
                          ],
                        ),
                        subtitle: _visitSubtitle(v),
                        onTap: () => showVisitEditor(
                          context,
                          placeId: p.id,
                          initial: v,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showVisitEditor(context, placeId: p.id),
        icon: const Icon(Icons.check),
        label: const Text('訪問を記録'),
      ),
    );
  }

  Widget? _visitSubtitle(Visit v) {
    final lines = [
      if (v.companions.isNotEmpty) '一緒に: ${v.companions}',
      if (v.comment.isNotEmpty) v.comment,
    ];
    return lines.isEmpty ? null : Text(lines.join('\n'));
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.file});

  final String file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(child: Image.file(File(file), errorBuilder: _err)),
      ),
    );
  }

  static Widget _err(BuildContext context, Object error, StackTrace? stack) =>
      const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white));
}
