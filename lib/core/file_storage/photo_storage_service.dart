import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class StoredPhoto {
  const StoredPhoto(
    this.id,
    this.relativePath,
    this.thumbnailRelativePath,
    this.originalName,
    this.size,
  );
  final String id;
  final String relativePath;
  final String? thumbnailRelativePath;
  final String originalName;
  final int size;
}

class PhotoStorageService {
  PhotoStorageService({this._rootOverride});
  final Directory? _rootOverride;
  static const _uuid = Uuid();
  Future<Directory> get appDirectory async {
    if (_rootOverride != null) return _rootOverride;
    return getApplicationDocumentsDirectory();
  }

  Future<StoredPhoto> copyIntoApp(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('선택한 사진을 찾을 수 없습니다.');
    }
    final root = await appDirectory;
    final directory = Directory(p.join(root.path, 'photos', 'original'));
    await directory.create(recursive: true);
    final id = _uuid.v4();
    var extension = p.extension(sourcePath).toLowerCase();
    if (extension.isEmpty || extension.length > 8) extension = '.jpg';
    final relative = p.join('photos', 'original', '$id$extension');
    final destination = await source.copy(p.join(root.path, relative));
    String? thumbnailRelativePath;
    try {
      final decoded = img.decodeImage(await destination.readAsBytes());
      if (decoded != null) {
        final thumbnails = Directory(p.join(root.path, 'photos', 'thumbnails'));
        await thumbnails.create(recursive: true);
        thumbnailRelativePath = p.join('photos', 'thumbnails', '$id.jpg');
        final resized = img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 720 : null,
          height: decoded.height > decoded.width ? 720 : null,
          interpolation: img.Interpolation.average,
        );
        await File(
          p.join(root.path, thumbnailRelativePath),
        ).writeAsBytes(img.encodeJpg(resized, quality: 82), flush: true);
      }
    } catch (_) {
      thumbnailRelativePath = null;
    }
    return StoredPhoto(
      id,
      relative,
      thumbnailRelativePath,
      p.basename(sourcePath),
      await destination.length(),
    );
  }

  Future<File> resolve(String relativePath) async =>
      File(p.join((await appDirectory).path, relativePath));
  Future<void> delete(String relativePath) async {
    final file = await resolve(relativePath);
    if (await file.exists()) await file.delete();
  }

  Future<void> deletePhotoAndThumbnail(
    String relativePath,
    String? thumbnailRelativePath,
  ) async {
    await delete(relativePath);
    if (thumbnailRelativePath != null) await delete(thumbnailRelativePath);
  }
}
