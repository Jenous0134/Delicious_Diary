import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:hankki_diary/core/database/app_database.dart';
import 'package:hankki_diary/core/file_storage/photo_storage_service.dart';
import 'package:hankki_diary/features/backup/data/backup_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('사진과 관계 데이터를 ZIP으로 백업하고 전체 복원한다', () async {
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
    final root = await Directory.systemTemp.createTemp('hankki-backup-test-');
    final appRoot = await Directory(p.join(root.path, 'app')).create();
    final tempRoot = await Directory(p.join(root.path, 'temp')).create();
    final originalDir = await Directory(
      p.join(appRoot.path, 'photos', 'original'),
    ).create(recursive: true);
    final photoFile = File(p.join(originalDir.path, 'photo-a.jpg'));
    await photoFile.writeAsBytes([1, 2, 3, 4], flush: true);
    const now = '2026-10-18T00:00:00.000Z';
    await db.insert('meals', {
      'id': 'meal-a',
      'eaten_date': '2026-10-18',
      'meal_type': 'lunch',
      'place_name': '회사',
      'place_name_normalized': '회사',
      'place_source': 'manual',
      'memo': '점심 식사',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('meal_photos', {
      'id': 'photo-a',
      'meal_id': 'meal-a',
      'relative_path': 'photos/original/photo-a.jpg',
      'sort_order': 0,
      'is_cover': 1,
      'created_at': now,
    });
    await db.insert('meal_items', {
      'id': 'item-a',
      'meal_id': 'meal-a',
      'menu_name': '김치찌개',
      'menu_name_normalized': '김치찌개',
      'price_won': 9000,
      'sort_order': 0,
    });
    await db.insert('people', {
      'id': 'person-a',
      'display_name': '동료A',
      'normalized_name': '동료a',
    });
    await db.insert('meal_people', {
      'meal_id': 'meal-a',
      'person_id': 'person-a',
    });

    final service = BackupService(
      database: AppDatabase.forTesting(db),
      photos: PhotoStorageService(rootOverride: appRoot),
      temporaryDirectory: tempRoot,
    );
    final backup = await service.createBackup();
    expect(await backup.exists(), isTrue);
    expect((await service.inspectBackup(backup)).meals, 1);
    await db.delete('meals');
    await photoFile.delete();
    final restored = await service.restoreBackup(backup);
    expect(restored.meals, 1);
    expect(restored.photos, 1);
    expect((await db.query('meal_items')).single['price_won'], 9000);
    expect((await db.query('meal_people')).single['person_id'], 'person-a');
    expect(
      await File(
        p.join(appRoot.path, 'photos', 'original', 'photo-a.jpg'),
      ).readAsBytes(),
      [1, 2, 3, 4],
    );

    await db.close();
    await root.delete(recursive: true);
  });

  test('ZIP Slip 경로를 거부하고 대상 밖에 파일을 만들지 않는다', () async {
    final root = await Directory.systemTemp.createTemp('hankki-zipslip-test-');
    final zip = File(p.join(root.path, 'malicious.zip'));
    final archive = Archive()
      ..addFile(ArchiveFile.string('../outside.txt', 'unsafe'));
    await zip.writeAsBytes(ZipEncoder().encode(archive), flush: true);
    final service = BackupService(
      temporaryDirectory: root,
      photos: PhotoStorageService(rootOverride: root),
    );
    await expectLater(service.inspectBackup(zip), throwsA(anything));
    expect(
      await File(p.join(root.parent.path, 'outside.txt')).exists(),
      isFalse,
    );
    await root.delete(recursive: true);
  });
}
