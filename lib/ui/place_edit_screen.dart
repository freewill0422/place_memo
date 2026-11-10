import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/database.dart';
import '../data/providers.dart';
import 'common.dart';

/// 場所の新規登録・編集。[initial] が null なら新規。
class PlaceEditScreen extends ConsumerStatefulWidget {
  const PlaceEditScreen({super.key, this.initial});

  final Place? initial;

  @override
  ConsumerState<PlaceEditScreen> createState() => _PlaceEditScreenState();
}

class _PlaceEditScreenState extends ConsumerState<PlaceEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _url;
  late final TextEditingController _wantWith;
  late final TextEditingController _memo;

  int? _categoryId;
  int? _areaId;

  /// 保存済みの画像名(編集時)
  String? _savedImage;

  /// 今回選び直した画像(保存ボタンを押すまでコピーしない)
  XFile? _newImage;
  bool _saving = false;

  bool get _isNew => widget.initial == null;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _name = TextEditingController(text: p?.name ?? '');
    _address = TextEditingController(text: p?.address ?? '');
    _url = TextEditingController(text: p?.url ?? '');
    _wantWith = TextEditingController(text: p?.wantWith ?? '');
    _memo = TextEditingController(text: p?.memo ?? '');
    _categoryId = p?.categoryId;
    _areaId = p?.areaId;
    _savedImage = p?.imagePath;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _url.dispose();
    _wantWith.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
    );
    if (picked != null) {
      setState(() => _newImage = picked);
    }
  }

  void _removeImage() {
    setState(() {
      _newImage = null;
      _savedImage = null;
    });
  }

  Future<void> _addMaster(MasterKind kind) async {
    final name =
        await showNameDialog(context, title: '${kind.label}を追加');
    if (name == null) return;
    final id = await ref.read(databaseProvider).addMaster(kind, name);
    if (!mounted) return;
    setState(() {
      if (kind == MasterKind.category) {
        _categoryId = id;
      } else {
        _areaId = id;
      }
    });
  }

  int? _validId(MasterKind kind, int? id) {
    final items = ref.read(mastersProvider(kind)).value;
    if (id == null || items == null) return id;
    return items.any((e) => e.id == id) ? id : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final db = ref.read(databaseProvider);
    final store = ref.read(imageStoreProvider);
    try {
      var imageName = _savedImage;
      if (_newImage != null) {
        imageName = await store.save(_newImage!);
      }
      final input = PlaceInput(
        name: _name.text.trim(),
        categoryId: _validId(MasterKind.category, _categoryId),
        areaId: _validId(MasterKind.area, _areaId),
        address: _address.text.trim(),
        url: _url.text.trim(),
        wantWith: _wantWith.text.trim(),
        memo: _memo.text.trim(),
        imagePath: imageName,
      );
      if (_isNew) {
        await db.insertPlace(input);
      } else {
        await db.updatePlace(widget.initial!.id, input);
        final old = widget.initial!.imagePath;
        if (old != null && old != imageName) {
          await store.delete(old);
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存できませんでした: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(mastersProvider(MasterKind.category)).value ?? const [];
    final areas = ref.watch(mastersProvider(MasterKind.area)).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'メモを追加' : 'メモを編集'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImageField(
              newImage: _newImage,
              savedImage: _savedImage,
              onPick: _pickImage,
              onRemove: _removeImage,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '名前 *',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '名前を入力してください' : null,
            ),
            const SizedBox(height: 12),
            _MasterRow(
              child: MasterDropdown(
                label: 'カテゴリ',
                items: categories,
                value: _categoryId,
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              onAdd: () => _addMaster(MasterKind.category),
            ),
            const SizedBox(height: 12),
            _MasterRow(
              child: MasterDropdown(
                label: 'エリア',
                items: areas,
                value: _areaId,
                onChanged: (v) => setState(() => _areaId = v),
              ),
              onAdd: () => _addMaster(MasterKind.area),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: '住所・場所',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL(Instagram の投稿など)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _wantWith,
              decoration: const InputDecoration(
                labelText: '一緒に行きたい人',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _memo,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'メモ',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MasterRow extends StatelessWidget {
  const _MasterRow({required this.child, required this.onAdd});

  final Widget child;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: child),
        IconButton(
          tooltip: '新しく追加',
          onPressed: onAdd,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

class _ImageField extends ConsumerWidget {
  const _ImageField({
    required this.newImage,
    required this.savedImage,
    required this.onPick,
    required this.onRemove,
  });

  final XFile? newImage;
  final String? savedImage;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final File? file = newImage != null
        ? File(newImage!.path)
        : (savedImage != null
            ? ref.watch(imageStoreProvider).fileOf(savedImage!)
            : null);

    if (file == null) {
      return OutlinedButton.icon(
        onPressed: onPick,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(120)),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('スクショを選ぶ'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: scheme.surfaceContainerHighest,
            height: 240,
            child: Image.file(
              file,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('変更'),
            ),
            TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
              label: const Text('外す'),
            ),
          ],
        ),
      ],
    );
  }
}
