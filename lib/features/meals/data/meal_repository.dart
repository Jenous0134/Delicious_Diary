import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/file_storage/photo_storage_service.dart';
import '../domain/meal.dart';

String normalizeText(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

class MealRepository {
  MealRepository({AppDatabase? database, PhotoStorageService? photos})
    : _database = database ?? AppDatabase.instance,
      _photos = photos ?? PhotoStorageService();
  final AppDatabase _database;
  final PhotoStorageService _photos;
  static const _uuid = Uuid();
  static final _date = DateFormat('yyyy-MM-dd');

  Future<List<String>> recentPlaces() async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT place_name, MAX(updated_at) AS last_used FROM meals GROUP BY place_name_normalized ORDER BY last_used DESC LIMIT 20',
    );
    return rows.map((row) => row['place_name']! as String).toList();
  }

  Future<List<String>> recentPeople() async {
    final db = await _database.database;
    final rows = await db.query(
      'people',
      columns: ['display_name'],
      orderBy: 'display_name',
      limit: 30,
    );
    return rows.map((row) => row['display_name']! as String).toList();
  }

  Future<List<Meal>> find([MealFilter filter = const MealFilter()]) async {
    final db = await _database.database;
    final where = <String>[];
    final args = <Object?>[];
    if (filter.startDate != null) {
      where.add('m.eaten_date >= ?');
      args.add(_date.format(filter.startDate!));
    }
    if (filter.endDate != null) {
      where.add('m.eaten_date <= ?');
      args.add(_date.format(filter.endDate!));
    }
    if (normalizeText(filter.place ?? '').isNotEmpty) {
      where.add('m.place_name_normalized LIKE ?');
      args.add('%${normalizeText(filter.place!)}%');
    }
    if (filter.type != null) {
      where.add('m.meal_type = ?');
      args.add(filter.type!.dbValue);
    }
    if (normalizeText(filter.menu ?? '').isNotEmpty) {
      where.add(
        'EXISTS (SELECT 1 FROM meal_items i WHERE i.meal_id=m.id AND i.menu_name_normalized LIKE ?)',
      );
      args.add('%${normalizeText(filter.menu!)}%');
    }
    if (normalizeText(filter.person ?? '').isNotEmpty) {
      where.add(
        'EXISTS (SELECT 1 FROM meal_people mp JOIN people p ON p.id=mp.person_id WHERE mp.meal_id=m.id AND p.normalized_name LIKE ?)',
      );
      args.add('%${normalizeText(filter.person!)}%');
    }
    final rows = await db.rawQuery(
      'SELECT m.* FROM meals m ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} ORDER BY m.eaten_date DESC, COALESCE(m.eaten_time, \'\') DESC, m.created_at DESC',
      args,
    );
    return Future.wait(rows.map((row) => _hydrate(db, row)));
  }

  Future<Meal?> byId(String id) async {
    final db = await _database.database;
    final rows = await db.query('meals', where: 'id=?', whereArgs: [id]);
    return rows.isEmpty ? null : _hydrate(db, rows.first);
  }

  Future<Meal> _hydrate(Database db, Map<String, Object?> row) async {
    final id = row['id']! as String;
    final photoRows = await db.query(
      'meal_photos',
      where: 'meal_id=?',
      whereArgs: [id],
      orderBy: 'sort_order',
    );
    final itemRows = await db.query(
      'meal_items',
      where: 'meal_id=?',
      whereArgs: [id],
      orderBy: 'sort_order',
    );
    final peopleRows = await db.rawQuery(
      'SELECT p.display_name FROM people p JOIN meal_people mp ON mp.person_id=p.id WHERE mp.meal_id=? ORDER BY p.display_name',
      [id],
    );
    return Meal(
      id: id,
      eatenDate: DateTime.parse(row['eaten_date']! as String),
      eatenTime: row['eaten_time'] as String?,
      type: MealTypeText.fromDb(row['meal_type']! as String),
      placeName: row['place_name']! as String,
      placeSource: row['place_source']! as String,
      placeAddress: row['place_address'] as String?,
      latitude: row['latitude'] as double?,
      longitude: row['longitude'] as double?,
      memo: row['memo'] as String?,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
      photos: photoRows
          .map(
            (p) => MealPhoto(
              id: p['id']! as String,
              relativePath: p['relative_path']! as String,
              thumbnailRelativePath: p['thumbnail_relative_path'] as String?,
              sortOrder: p['sort_order']! as int,
              isCover: p['is_cover'] == 1,
            ),
          )
          .toList(),
      items: itemRows
          .map(
            (i) => MealItem(
              name: i['menu_name']! as String,
              priceWon: i['price_won'] as int?,
            ),
          )
          .toList(),
      people: peopleRows.map((p) => p['display_name']! as String).toList(),
    );
  }

  Future<String> save(MealDraft draft) async {
    if (draft.placeName.trim().isEmpty) throw ArgumentError('장소를 입력해 주세요.');
    if (draft.photoPaths.isEmpty && draft.existingPhotos.isEmpty) {
      throw ArgumentError('사진을 한 장 이상 선택해 주세요.');
    }
    final previousPhotos = draft.id == null
        ? const <MealPhoto>[]
        : (await byId(draft.id!))?.photos ?? const <MealPhoto>[];
    final copied = <StoredPhoto>[];
    try {
      for (final path in draft.photoPaths) {
        copied.add(await _photos.copyIntoApp(path));
      }
    } catch (_) {
      for (final photo in copied) {
        await _photos.deletePhotoAndThumbnail(
          photo.relativePath,
          photo.thumbnailRelativePath,
        );
      }
      rethrow;
    }
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final id = draft.id ?? _uuid.v4();
    try {
      await db.transaction((txn) async {
        final old = draft.id == null
            ? <Map<String, Object?>>[]
            : await txn.query(
                'meals',
                columns: ['created_at'],
                where: 'id=?',
                whereArgs: [id],
              );
        await txn.insert('meals', {
          'id': id,
          'eaten_date': _date.format(draft.eatenDate),
          'eaten_time': draft.eatenTime,
          'meal_type': draft.type.dbValue,
          'place_name': draft.placeName.trim(),
          'place_name_normalized': normalizeText(draft.placeName),
          'place_source': draft.placeSource,
          'place_provider': draft.placeProvider,
          'place_provider_id': draft.placeProviderId,
          'place_address': draft.placeAddress,
          'latitude': draft.latitude,
          'longitude': draft.longitude,
          'memo': draft.memo?.trim(),
          'created_at': old.isEmpty ? now : old.first['created_at'],
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await txn.delete('meal_photos', where: 'meal_id=?', whereArgs: [id]);
        await txn.delete('meal_items', where: 'meal_id=?', whereArgs: [id]);
        await txn.delete('meal_people', where: 'meal_id=?', whereArgs: [id]);
        final unorderedPhotos = [
          ...draft.existingPhotos,
          ...copied.map(
            (e) => MealPhoto(
              id: e.id,
              relativePath: e.relativePath,
              thumbnailRelativePath: e.thumbnailRelativePath,
              sortOrder: 0,
              isCover: false,
            ),
          ),
        ];
        final copiedByPath = <String, StoredPhoto>{
          for (var i = 0; i < draft.photoPaths.length; i++)
            draft.photoPaths[i]: copied[i],
        };
        final byKey = <String, MealPhoto>{
          for (final photo in unorderedPhotos) photo.id: photo,
        };
        for (final entry in copiedByPath.entries) {
          final photo = unorderedPhotos.firstWhere(
            (value) => value.id == entry.value.id,
          );
          byKey[entry.key] = photo;
        }
        final photos = draft.orderedPhotoKeys.isEmpty
            ? unorderedPhotos
            : draft.orderedPhotoKeys
                  .map((key) => byKey[key])
                  .whereType<MealPhoto>()
                  .toList();
        for (var i = 0; i < photos.length; i++) {
          final p = photos[i];
          final stored = copied.where((e) => e.id == p.id).firstOrNull;
          await txn.insert('meal_photos', {
            'id': p.id,
            'meal_id': id,
            'relative_path': p.relativePath,
            'thumbnail_relative_path': p.thumbnailRelativePath,
            'sort_order': i,
            'is_cover': i == 0 ? 1 : 0,
            'original_filename': stored?.originalName,
            'byte_size': stored?.size,
            'created_at': now,
          });
        }
        for (var i = 0; i < draft.items.length; i++) {
          final item = draft.items[i];
          if (item.name.trim().isEmpty) continue;
          await txn.insert('meal_items', {
            'id': _uuid.v4(),
            'meal_id': id,
            'menu_name': item.name.trim(),
            'menu_name_normalized': normalizeText(item.name),
            'price_won': item.priceWon,
            'sort_order': i,
          });
        }
        for (final display
            in draft.people
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toSet()) {
          final normalized = normalizeText(display);
          final found = await txn.query(
            'people',
            where: 'normalized_name=?',
            whereArgs: [normalized],
          );
          final personId = found.isEmpty
              ? _uuid.v4()
              : found.first['id']! as String;
          if (found.isEmpty) {
            await txn.insert('people', {
              'id': personId,
              'display_name': display,
              'normalized_name': normalized,
            });
          }
          await txn.insert('meal_people', {
            'meal_id': id,
            'person_id': personId,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      });
    } catch (_) {
      for (final photo in copied) {
        await _photos.deletePhotoAndThumbnail(
          photo.relativePath,
          photo.thumbnailRelativePath,
        );
      }
      rethrow;
    }
    final retainedPaths = draft.existingPhotos
        .map((photo) => photo.relativePath)
        .toSet();
    for (final removed in previousPhotos.where(
      (photo) => !retainedPaths.contains(photo.relativePath),
    )) {
      try {
        await _photos.deletePhotoAndThumbnail(
          removed.relativePath,
          removed.thumbnailRelativePath,
        );
      } catch (_) {
        // The DB no longer references this file; stale-file cleanup is best effort.
      }
    }
    return id;
  }

  Future<void> delete(String id) async {
    final meal = await byId(id);
    if (meal == null) return;
    final db = await _database.database;
    await db.delete('meals', where: 'id=?', whereArgs: [id]);
    for (final photo in meal.photos) {
      try {
        await _photos.deletePhotoAndThumbnail(
          photo.relativePath,
          photo.thumbnailRelativePath,
        );
      } catch (_) {
        // The DB is authoritative; an unreferenced file can be cleaned later.
      }
    }
  }
}
