import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageStorageService {
  Future<String> saveImageCopy(File sourceImage) async {
    final root = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(root.path, 'collection_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final ext = p.extension(sourceImage.path).toLowerCase();
    final safeExt = ext.isEmpty ? '.jpg' : ext;
    final filename = 'img_${DateTime.now().millisecondsSinceEpoch}$safeExt';
    final destinationPath = p.join(imagesDir.path, filename);

    final copied = await sourceImage.copy(destinationPath);
    return copied.path;
  }

  Future<void> deleteImageIfExists(String imagePath) async {
    final file = File(imagePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
