import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

/// スクショ画像をアプリ専用フォルダに保存・削除する。
///
/// DB にはファイル名だけを保存する(iOS はアプリ更新でフォルダの絶対パスが変わるため)。
class ImageStore {
  ImageStore(this.dirPath);

  final String dirPath;

  File fileOf(String name) => File(p.join(dirPath, name));

  /// 選んだ画像をコピーして、保存したファイル名を返す。
  Future<String> save(XFile picked) async {
    await Directory(dirPath).create(recursive: true);
    final ext = p.extension(picked.path).isEmpty ? '.jpg' : p.extension(picked.path);
    final name = '${DateTime.now().microsecondsSinceEpoch}$ext';
    await picked.saveTo(p.join(dirPath, name));
    return name;
  }

  Future<void> delete(String? name) async {
    if (name == null) return;
    final file = fileOf(name);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
