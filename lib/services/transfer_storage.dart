import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/transfer_item.dart';

/// Simple file storage for transferred files. No encryption, no auth.
class TransferStorage extends ChangeNotifier {
  Directory? _root;
  final List<TransferItem> _items = [];
  File? _indexFile;
  static const String _indexFileName = 'index.json';

  List<TransferItem> get items => List.unmodifiable(_items);

  Future<void> init() async {
    if (_root != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _root = Directory(path.join(dir.path, 'wifi_transfer_files'));
    if (!await _root!.exists()) await _root!.create(recursive: true);
    _indexFile = File(path.join(_root!.path, _indexFileName));
    await _loadIndex();
  }

  Future<void> _loadIndex() async {
    if (_indexFile == null || !await _indexFile!.exists()) {
      _items.clear();
      return;
    }
    try {
      final content = await _indexFile!.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final list = json['items'] as List<dynamic>? ?? [];
      _items.clear();
      for (final e in list) {
        _items.add(TransferItem.fromJson(e as Map<String, dynamic>));
      }
    } catch (e) {
      debugPrint('[TransferStorage] Load error: $e');
      _items.clear();
    }
  }

  Future<void> _saveIndex() async {
    if (_indexFile == null) return;
    try {
      final json = {
        'version': 1,
        'items': _items.map((e) => e.toJson()).toList(),
      };
      await _indexFile!.writeAsString(jsonEncode(json));
    } catch (e) {
      debugPrint('[TransferStorage] Save error: $e');
    }
  }

  static String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final r = DateTime.now().microsecondsSinceEpoch % 100000;
    return '${now}_$r';
  }

  static TransferItemType _typeFromFilename(String filename) {
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
    const photoExt = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp'];
    const videoExt = ['mp4', 'mov', 'm4v', 'avi', 'mkv', 'webm'];
    if (photoExt.contains(ext)) return TransferItemType.photo;
    if (videoExt.contains(ext)) return TransferItemType.video;
    return TransferItemType.other;
  }

  Future<TransferItem> storeFile({
    required Uint8List data,
    required String filename,
  }) async {
    await init();
    final id = _generateId();
    final ext = filename.contains('.') ? path.extension(filename) : '';
    final safeName = ext.isEmpty ? id : '$id$ext';
    final relativePath = safeName;
    final filePath = path.join(_root!.path, relativePath);
    await File(filePath).writeAsBytes(data);
    final type = _typeFromFilename(filename);
    final item = TransferItem(
      id: id,
      name: filename,
      sizeBytes: data.length,
      type: type,
      relativePath: relativePath,
    );
    _items.add(item);
    await _saveIndex();
    notifyListeners();
    return item;
  }

  String? getFilePath(String itemId) {
    if (_root == null) return null;
    try {
      final item = _items.firstWhere((i) => i.id == itemId);
      final p = path.join(_root!.path, item.relativePath);
      return p;
    } catch (_) {
      return null;
    }
  }

  String? getThumbnailPath(String itemId) {
    // No thumbnails in this minimal app; could add later.
    return null;
  }
}
