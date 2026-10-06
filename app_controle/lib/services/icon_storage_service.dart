// lib/services/icon_storage_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class IconStorageService {
  /// Salva o ícone em disco e retorna o caminho completo.
  /// Se já existir um arquivo para o mesmo packageName, sobrescreve.
  static Future<String> saveIcon(
    String packageName,
    Uint8List bytes,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final iconsDir = Directory('${dir.path}/icons');
    if (!await iconsDir.exists()) {
      await iconsDir.create(recursive: true);
    }
    // Sanitiza o packageName para virar nome de arquivo
    final safeName = packageName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final file = File('${iconsDir.path}/$safeName.png');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static Future<void> deleteIcon(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}