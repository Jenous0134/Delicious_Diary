import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hankki_diary/core/database/app_database.dart';
import 'package:hankki_diary/core/file_storage/photo_storage_service.dart';
import 'package:hankki_diary/features/meals/data/meal_repository.dart';
import 'package:hankki_diary/features/meals/domain/meal.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('사진 3장 저장 후 순서·대표 변경과 제거 파일 정리를 유지한다', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        version: 1,
        onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
        onCreate: (database, _) => AppDatabase.createSchema(database),
      ),
    );
    final root = await Directory.systemTemp.createTemp('hankki-photo-test-');
    final sources = await Directory(p.join(root.path, 'sources')).create();
    final sourcePaths = <String>[];
    for (var i = 0; i < 3; i++) {
      final file = File(p.join(sources.path, '$i.jpg'));
      await file.writeAsBytes([i + 1, i + 2, i + 3]);
      sourcePaths.add(file.path);
    }
    final storage = PhotoStorageService(
      rootOverride: Directory(p.join(root.path, 'app')),
    );
    final repository = MealRepository(
      database: AppDatabase.forTesting(db),
      photos: storage,
    );
    final id = await repository.save(
      MealDraft(
        eatenDate: DateTime(2026, 10, 18),
        type: MealType.lunch,
        placeName: '회사',
        photoPaths: sourcePaths,
      ),
    );
    final created = (await repository.byId(id))!;
    expect(created.photos, hasLength(3));
    expect(created.photos.where((photo) => photo.isCover), hasLength(1));
    expect(created.photos.first.isCover, isTrue);
    final removedPath = created.photos[1].relativePath;

    final reordered = [created.photos[2], created.photos[0]];
    await repository.save(
      MealDraft(
        id: id,
        eatenDate: created.eatenDate,
        type: created.type,
        placeName: created.placeName,
        photoPaths: const [],
        existingPhotos: reordered,
        orderedPhotoKeys: reordered.map((photo) => photo.id).toList(),
      ),
    );
    final updated = (await repository.byId(id))!;
    expect(updated.photos.map((photo) => photo.id), [
      created.photos[2].id,
      created.photos[0].id,
    ]);
    expect(updated.photos.first.isCover, isTrue);
    expect(updated.photos.last.isCover, isFalse);
    expect(await (await storage.resolve(removedPath)).exists(), isFalse);

    await db.close();
    await root.delete(recursive: true);
  });
}
