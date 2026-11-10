import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/providers.dart';
import 'common.dart';

/// カテゴリ / エリアの追加・名前変更・削除・並べ替え(長押しでドラッグ)。
class MasterListScreen extends ConsumerWidget {
  const MasterListScreen({super.key, required this.kind});

  final MasterKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final itemsAsync = ref.watch(mastersProvider(kind));

    Future<void> add() async {
      final name = await showNameDialog(context, title: '${kind.label}を追加');
      if (name != null) await db.addMaster(kind, name);
    }

    Future<void> rename(MasterItem it) async {
      final name = await showNameDialog(context,
          title: '名前を変更', initial: it.name);
      if (name != null && name != it.name) {
        await db.renameMaster(kind, it.id, name);
      }
    }

    Future<void> remove(MasterItem it) async {
      final ok = await showConfirmDialog(
        context,
        message: '「${it.name}」を削除しますか?\n登録済みのメモからは外れます(メモは消えません)。',
      );
      if (ok) await db.deleteMaster(kind, it.id);
    }

    return Scaffold(
      appBar: AppBar(title: Text('${kind.label}の管理')),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('読み込みエラー: $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text('${kind.label}がありません'));
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: items.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex -= 1;
              final ids = [for (final it in items) it.id];
              final moved = ids.removeAt(oldIndex);
              ids.insert(newIndex, moved);
              db.reorderMasters(kind, ids);
            },
            itemBuilder: (_, i) {
              final it = items[i];
              return ListTile(
                key: ValueKey(it.id),
                title: Text(it.name),
                onTap: () => rename(it),
                trailing: IconButton(
                  tooltip: '削除',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => remove(it),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '追加',
        onPressed: add,
        child: const Icon(Icons.add),
      ),
    );
  }
}
