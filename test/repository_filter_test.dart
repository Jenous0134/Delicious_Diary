import 'package:flutter_test/flutter_test.dart';
import 'package:hankki_diary/core/database/app_database.dart';
import 'package:hankki_diary/features/meals/data/meal_repository.dart';
import 'package:hankki_diary/features/meals/domain/meal.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late MealRepository repository;
  setUpAll(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        version: 1,
        onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
        onCreate: (database, _) => AppDatabase.createSchema(database),
      ),
    );
    repository = MealRepository(database: AppDatabase.forTesting(db));
    const now = '2026-10-18T00:00:00.000Z';
    await db.insert('meals', {
      'id': 'a',
      'eaten_date': '2026-10-18',
      'meal_type': 'lunch',
      'place_name': '회사',
      'place_name_normalized': '회사',
      'place_source': 'manual',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('meals', {
      'id': 'b',
      'eaten_date': '2026-10-17',
      'meal_type': 'dinner',
      'place_name': '집',
      'place_name_normalized': '집',
      'place_source': 'manual',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('meal_photos', {
      'id': 'pa',
      'meal_id': 'a',
      'relative_path': 'photos/original/pa.jpg',
      'sort_order': 0,
      'is_cover': 1,
      'created_at': now,
    });
    await db.insert('meal_photos', {
      'id': 'pb',
      'meal_id': 'b',
      'relative_path': 'photos/original/pb.jpg',
      'sort_order': 0,
      'is_cover': 1,
      'created_at': now,
    });
    await db.insert('meal_items', {
      'id': 'ia',
      'meal_id': 'a',
      'menu_name': '김치찌개',
      'menu_name_normalized': '김치찌개',
      'price_won': 9000,
      'sort_order': 0,
    });
    await db.insert('people', {
      'id': 'p1',
      'display_name': '동료A',
      'normalized_name': '동료a',
    });
    await db.insert('meal_people', {'meal_id': 'a', 'person_id': 'p1'});
  });
  tearDownAll(() async => db.close());

  test('날짜 장소 메뉴 동행인 식사 구분을 AND로 결합한다', () async {
    final result = await repository.find(
      MealFilter(
        startDate: DateTime(2026, 10, 18),
        endDate: DateTime(2026, 10, 18),
        place: '회사',
        menu: '김치',
        person: '동료A',
        type: MealType.lunch,
      ),
    );
    expect(result.map((meal) => meal.id), ['a']);
  });

  test('조건 중 하나라도 다르면 결과에서 제외한다', () async {
    final result = await repository.find(
      const MealFilter(place: '회사', menu: '김치찌개', person: '없는 사람'),
    );
    expect(result, isEmpty);
  });
}
