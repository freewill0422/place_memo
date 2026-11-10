import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/providers.dart';
import 'common.dart';

Future<void> showVisitEditor(
  BuildContext context, {
  required int placeId,
  Visit? initial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => VisitEditSheet(placeId: placeId, initial: initial),
  );
}

/// 訪問記録(いつ・誰と・評価・感想)の入力。
class VisitEditSheet extends ConsumerStatefulWidget {
  const VisitEditSheet({super.key, required this.placeId, this.initial});

  final int placeId;
  final Visit? initial;

  @override
  ConsumerState<VisitEditSheet> createState() => _VisitEditSheetState();
}

class _VisitEditSheetState extends ConsumerState<VisitEditSheet> {
  late DateTime _date;
  int? _rating;
  late final TextEditingController _companions;
  late final TextEditingController _comment;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.initial;
    final now = DateTime.now();
    _date = v?.visitedOn ?? DateTime(now.year, now.month, now.day);
    _rating = v?.rating;
    _companions = TextEditingController(text: v?.companions ?? '');
    _comment = TextEditingController(text: v?.comment ?? '');
  }

  @override
  void dispose() {
    _companions.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final input = VisitInput(
      placeId: widget.placeId,
      visitedOn: _date,
      companions: _companions.text.trim(),
      rating: _rating,
      comment: _comment.text.trim(),
    );
    if (widget.initial == null) {
      await db.insertVisit(input);
    } else {
      await db.updateVisit(widget.initial!.id, input);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(context, message: 'この訪問記録を削除しますか?');
    if (!ok || !mounted) return;
    await ref.read(databaseProvider).deleteVisit(widget.initial!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initial == null ? '訪問を記録' : '訪問記録を編集',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(formatDate(_date)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDate,
            ),
            Row(
              children: [
                const Text('評価'),
                const SizedBox(width: 12),
                RatingStars(
                  value: _rating?.toDouble(),
                  size: 32,
                  onChanged: (v) => setState(() => _rating = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _companions,
              decoration: const InputDecoration(
                labelText: '一緒に行った人',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comment,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '感想',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.initial != null)
                  TextButton.icon(
                    onPressed: _saving ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('削除'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
