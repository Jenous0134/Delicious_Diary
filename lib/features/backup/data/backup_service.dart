import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/file_storage/photo_storage_service.dart';

class BackupService {
  BackupService({
    AppDatabase? database,
    PhotoStorageService? photos,
    this._temporaryDirectory,
  }) : _database = database ?? AppDatabase.instance,
       _photos = photos ?? PhotoStorageService();

  final AppDatabase _database;
  final PhotoStorageService _photos;
  final Directory? _temporaryDirectory;
  Future<Directory> get _temp async {
    if (_temporaryDirectory != null) return _temporaryDirectory;
    return getTemporaryDirectory();
  }

  static const tables = [
    'meals',
    'meal_photos',
    'meal_items',
    'people',
    'meal_people',
  ];

  Future<File> createBackup() async {
    final db = await _database.database;
    final staging = await Directory(
      p.join(
        (await _temp).path,
        'hankki-backup-${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create(recursive: true);
    final dataDir = await Directory(p.join(staging.path, 'data')).create();
    final photoDir = await Directory(
      p.join(staging.path, 'photos', 'original'),
    ).create(recursive: true);
    final checksums = <String, String>{};
    final counts = <String, int>{};

    try {
      for (final table in tables) {
        final rows = await db.query(table);
        counts[table] = rows.length;
        final relative = 'data/$table.json';
        final file = File(p.join(dataDir.path, '$table.json'));
        await file.writeAsString(jsonEncode(rows), flush: true);
        checksums[relative] = await _checksum(file);
      }

      final photos = await db.query('meal_photos');
      for (final row in photos) {
        final source = await _photos.resolve(row['relative_path']! as String);
        if (!await source.exists()) {
          throw StateError('백업할 사진 파일이 없습니다: ${row['id']}');
        }
        final name = '${row['id']}${p.extension(source.path).toLowerCase()}';
        final target = await source.copy(p.join(photoDir.path, name));
        checksums['photos/original/$name'] = await _checksum(target);
      }

      final manifest = File(p.join(staging.path, 'manifest.json'));
      await manifest.writeAsString(
        jsonEncode({
          'format': 'hankki-diary-backup',
          'schema_version': 1,
          'exported_at': DateTime.now().toUtc().toIso8601String(),
          'app_version': '0.1.0',
          'counts': counts,
          'checksums': checksums,
        }),
        flush: true,
      );

      final output = File(
        p.join(
          (await _temp).path,
          'hankki-diary-backup-${DateFormat('yyyy-MM-dd-HHmmss').format(DateTime.now())}.zip',
        ),
      );
      await ZipFileEncoder().zipDirectory(staging, filename: output.path);
      return output;
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  Future<String> _checksum(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  Future<RestoreSummary> inspectBackup(File zip) async {
    if (!await zip.exists()) {
      throw const FormatException('선택한 백업 파일을 찾을 수 없습니다.');
    }
    final staging = await _extractAndValidate(zip);
    try {
      final data = await _readTables(staging);
      _validateReferences(data);
      await _validatePhotoFiles(data, staging);
      return RestoreSummary(
        meals: data['meals']!.length,
        photos: data['meal_photos']!.length,
      );
    } finally {
      await staging.delete(recursive: true);
    }
  }

  Future<RestoreSummary> restoreBackup(File zip) async {
    final staging = await _extractAndValidate(zip);
    final data = await _readTables(staging);
    _validateReferences(data);
    await _validatePhotoFiles(data, staging);
    final appRoot = await _photos.appDirectory;
    final photosRoot = Directory(p.join(appRoot.path, 'photos'));
    final live = Directory(p.join(photosRoot.path, 'original'));
    final incoming = Directory(p.join(photosRoot.path, 'original_restore'));
    final rollback = Directory(
      p.join(photosRoot.path, 'original_before_restore'),
    );
    await photosRoot.create(recursive: true);
    if (await incoming.exists()) await incoming.delete(recursive: true);
    if (await rollback.exists()) await rollback.delete(recursive: true);
    await _copyDirectory(
      Directory(p.join(staging.path, 'photos', 'original')),
      incoming,
    );

    var movedOld = false;
    try {
      if (await live.exists()) {
        await live.rename(rollback.path);
        movedOld = true;
      }
      await incoming.rename(live.path);
      final db = await _database.database;
      await db.transaction((txn) async {
        for (final table in [
          'meal_people',
          'meal_items',
          'meal_photos',
          'meals',
          'people',
        ]) {
          await txn.delete(table);
        }
        for (final table in [
          'meals',
          'people',
          'meal_photos',
          'meal_items',
          'meal_people',
        ]) {
          for (final row in data[table]!) {
            await txn.insert(
              table,
              row,
              conflictAlgorithm: ConflictAlgorithm.abort,
            );
          }
        }
      });
    } catch (_) {
      if (await live.exists()) await live.delete(recursive: true);
      if (movedOld && await rollback.exists()) await rollback.rename(live.path);
      rethrow;
    } finally {
      if (await incoming.exists()) await incoming.delete(recursive: true);
      if (await staging.exists()) await staging.delete(recursive: true);
    }
    try {
      if (await rollback.exists()) await rollback.delete(recursive: true);
    } catch (_) {
      // The restore is already committed; stale rollback cleanup can be retried later.
    }
    try {
      await _regenerateThumbnails(data);
    } catch (_) {
      // Restore is complete; originals are the fallback when cache rebuilding fails.
    }
    return RestoreSummary(
      meals: data['meals']!.length,
      photos: data['meal_photos']!.length,
    );
  }

  Future<Directory> _extractAndValidate(File zip) async {
    const maxEntries = 50000;
    const maxExpandedBytes = 5 * 1024 * 1024 * 1024;
    final staging = await Directory(
      p.join(
        (await _temp).path,
        'hankki-restore-${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create(recursive: true);
    try {
      var entries = 0;
      var total = 0;
      await extractFileToDisk(
        zip.path,
        staging.path,
        maxSize: maxExpandedBytes,
        callback: (entry) {
          entries++;
          total += entry.size;
          final normalized = p.posix.normalize(
            entry.name.replaceAll('\\', '/'),
          );
          if (entries > maxEntries ||
              total > maxExpandedBytes ||
              normalized == '..' ||
              normalized.startsWith('../') ||
              p.posix.isAbsolute(normalized) ||
              entry.isSymbolicLink) {
            throw const FormatException('안전하지 않은 ZIP 항목이 포함되어 있습니다.');
          }
        },
      );
      final manifestFile = File(p.join(staging.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        throw const FormatException('manifest.json이 없습니다.');
      }
      final manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      if (manifest['format'] != 'hankki-diary-backup' ||
          manifest['schema_version'] != 1) {
        throw const FormatException('지원하지 않는 백업 형식입니다.');
      }
      final checksums = (manifest['checksums'] as Map).cast<String, dynamic>();
      for (final entry in checksums.entries) {
        final relative = p.posix.normalize(entry.key);
        if (relative.startsWith('../') || p.posix.isAbsolute(relative)) {
          throw const FormatException('잘못된 체크섬 경로입니다.');
        }
        final file = File(p.joinAll([staging.path, ...relative.split('/')]));
        if (!await file.exists() || await _checksum(file) != entry.value) {
          throw FormatException('백업 파일이 손상되었습니다: ${entry.key}');
        }
      }
      return staging;
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    }
  }

  Future<Map<String, List<Map<String, Object?>>>> _readTables(
    Directory staging,
  ) async {
    final result = <String, List<Map<String, Object?>>>{};
    for (final table in tables) {
      final file = File(p.join(staging.path, 'data', '$table.json'));
      if (!await file.exists()) throw FormatException('$table.json이 없습니다.');
      final decoded = jsonDecode(await file.readAsString()) as List;
      result[table] = decoded
          .map((row) => Map<String, Object?>.from(row as Map))
          .toList();
      if (table == 'meal_photos') {
        for (final row in result[table]!) {
          row['thumbnail_relative_path'] = null;
        }
      }
    }
    return result;
  }

  void _validateReferences(Map<String, List<Map<String, Object?>>> data) {
    final mealIds = data['meals']!.map((row) => row['id']).toSet();
    final peopleIds = data['people']!.map((row) => row['id']).toSet();
    final covers = <Object?, int>{};
    for (final row in data['meal_photos']!) {
      if (!mealIds.contains(row['meal_id'])) {
        throw const FormatException('사진의 식사 참조가 올바르지 않습니다.');
      }
      if (row['is_cover'] == 1) {
        covers[row['meal_id']] = (covers[row['meal_id']] ?? 0) + 1;
      }
    }
    for (final mealId in mealIds) {
      final photos = data['meal_photos']!
          .where((row) => row['meal_id'] == mealId)
          .toList();
      if (photos.isEmpty || covers[mealId] != 1) {
        throw const FormatException('식사별 사진 또는 대표 사진 정보가 올바르지 않습니다.');
      }
    }
    for (final row in data['meal_items']!) {
      if (!mealIds.contains(row['meal_id'])) {
        throw const FormatException('메뉴 참조가 올바르지 않습니다.');
      }
    }
    for (final row in data['meal_people']!) {
      if (!mealIds.contains(row['meal_id']) ||
          !peopleIds.contains(row['person_id'])) {
        throw const FormatException('동행인 참조가 올바르지 않습니다.');
      }
    }
  }

  Future<void> _validatePhotoFiles(
    Map<String, List<Map<String, Object?>>> data,
    Directory staging,
  ) async {
    for (final row in data['meal_photos']!) {
      final relativePath = row['relative_path'] as String?;
      if (relativePath == null || p.basename(relativePath).isEmpty) {
        throw const FormatException('사진 경로가 올바르지 않습니다.');
      }
      final file = File(
        p.join(staging.path, 'photos', 'original', p.basename(relativePath)),
      );
      if (!await file.exists() || await file.length() == 0) {
        throw FormatException('사진 파일이 누락되었습니다: ${row['id']}');
      }
    }
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    if (!await source.exists()) return;
    await for (final entity in source.list(
      recursive: true,
      followLinks: false,
    )) {
      final relative = p.relative(entity.path, from: source.path);
      if (entity is Directory) {
        await Directory(p.join(target.path, relative)).create(recursive: true);
      }
      if (entity is File) {
        final destination = File(p.join(target.path, relative));
        await destination.parent.create(recursive: true);
        await entity.copy(destination.path);
      }
    }
  }

  Future<void> _regenerateThumbnails(
    Map<String, List<Map<String, Object?>>> data,
  ) async {
    final root = await _photos.appDirectory;
    final thumbnailDir = Directory(p.join(root.path, 'photos', 'thumbnails'));
    if (await thumbnailDir.exists()) await thumbnailDir.delete(recursive: true);
    await thumbnailDir.create(recursive: true);
    final db = await _database.database;
    for (final row in data['meal_photos']!) {
      try {
        final original = File(
          p.join(root.path, row['relative_path']! as String),
        );
        final decoded = img.decodeImage(await original.readAsBytes());
        if (decoded == null) continue;
        final relative = p.join('photos', 'thumbnails', '${row['id']}.jpg');
        final resized = img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 720 : null,
          height: decoded.height > decoded.width ? 720 : null,
          interpolation: img.Interpolation.average,
        );
        await File(
          p.join(root.path, relative),
        ).writeAsBytes(img.encodeJpg(resized, quality: 82), flush: true);
        await db.update(
          'meal_photos',
          {'thumbnail_relative_path': relative},
          where: 'id=?',
          whereArgs: [row['id']],
        );
      } catch (_) {
        // Originals remain usable when a codec cannot create a thumbnail.
      }
    }
  }
}

class RestoreSummary {
  const RestoreSummary({required this.meals, required this.photos});
  final int meals;
  final int photos;
}
