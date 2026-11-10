import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/database.dart';
import '../data/providers.dart';

String formatDate(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

/// ★5段階。[onChanged] を渡すと入力用になる(同じ星をもう一度押すと未評価に戻る)。
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.value,
    this.size = 18,
    this.onChanged,
  });

  final double? value;
  final double size;
  final ValueChanged<int?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final v = value ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final n = i + 1;
        final icon = v >= n
            ? Icons.star
            : (v >= n - 0.5 ? Icons.star_half : Icons.star_border);
        final star = Icon(icon, size: size, color: Colors.amber);
        if (onChanged == null) return star;
        return InkResponse(
          onTap: () => onChanged!(value?.round() == n ? null : n),
          radius: size * 0.8,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: star,
          ),
        );
      }),
    );
  }
}

/// サムネイル。画像が無いときはアイコン。
class PlaceThumb extends ConsumerWidget {
  const PlaceThumb({super.key, required this.imageName, this.size = 56});

  final String? imageName;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: size,
      height: size,
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.place_outlined, color: scheme.onSurfaceVariant),
    );
    final name = imageName;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: name == null
          ? placeholder
          : Image.file(
              ref.watch(imageStoreProvider).fileOf(name),
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * 3).round(),
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

/// カテゴリ/エリアの選択欄。value が一覧に無い場合は「未選択」として表示する。
class MasterDropdown extends StatelessWidget {
  const MasterDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.nullLabel = '未選択',
  });

  final String label;
  final List<MasterItem> items;
  final int? value;
  final ValueChanged<int?> onChanged;
  final String nullLabel;

  @override
  Widget build(BuildContext context) {
    final effective = items.any((e) => e.id == value) ? value : null;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: effective,
          isExpanded: true,
          isDense: true,
          items: [
            DropdownMenuItem<int?>(value: null, child: Text(nullLabel)),
            for (final it in items)
              DropdownMenuItem<int?>(
                value: it.id,
                child: Text(it.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

Future<String?> showNameDialog(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(title: title, initial: initial),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '名前'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(onPressed: _submit, child: const Text('OK')),
      ],
    );
  }
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String message,
  String okLabel = '削除',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(okLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// URL を外部アプリ(ブラウザ / Instagram / 地図)で開く。
Future<void> openExternal(BuildContext context, String raw) async {
  var text = raw.trim();
  if (!text.startsWith('http://') && !text.startsWith('https://')) {
    text = 'https://$text';
  }
  final uri = Uri.tryParse(text);
  var ok = false;
  if (uri != null) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
  }
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('開けませんでした')));
  }
}

Future<void> openMap(BuildContext context, String query) {
  final q = Uri.encodeComponent(query);
  return openExternal(
      context, 'https://www.google.com/maps/search/?api=1&query=$q');
}
