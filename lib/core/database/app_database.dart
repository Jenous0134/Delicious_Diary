import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  AppDatabase.forTesting(Database database) : _database = database;
  static final instance = AppDatabase._();
  Database? _database;
  Future<Database> get database async => _database ??= await _open();
  Future<Database> _open() async => openDatabase(
    p.join(await getDatabasesPath(), 'hankki_diary.db'),
    version: 1,
    onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: (db, version) => createSchema(db),
  );

  static Future<void> createSchema(Database db) async {
    await db.execute(
      "CREATE TABLE meals (id TEXT PRIMARY KEY, eaten_date TEXT NOT NULL, eaten_time TEXT, meal_type TEXT NOT NULL CHECK (meal_type IN ('breakfast','lunch','dinner','snack','late_night','other')), place_name TEXT NOT NULL, place_name_normalized TEXT NOT NULL, place_source TEXT NOT NULL CHECK (place_source IN ('manual','map')), place_provider TEXT, place_provider_id TEXT, place_address TEXT, latitude REAL, longitude REAL, memo TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)",
    );
    await db.execute(
      'CREATE TABLE meal_photos (id TEXT PRIMARY KEY, meal_id TEXT NOT NULL REFERENCES meals(id) ON DELETE CASCADE, relative_path TEXT NOT NULL, thumbnail_relative_path TEXT, sort_order INTEGER NOT NULL, is_cover INTEGER NOT NULL DEFAULT 0 CHECK (is_cover IN (0,1)), original_filename TEXT, mime_type TEXT, byte_size INTEGER, created_at TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE meal_items (id TEXT PRIMARY KEY, meal_id TEXT NOT NULL REFERENCES meals(id) ON DELETE CASCADE, menu_name TEXT NOT NULL, menu_name_normalized TEXT NOT NULL, price_won INTEGER CHECK (price_won IS NULL OR price_won >= 0), sort_order INTEGER NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE people (id TEXT PRIMARY KEY, display_name TEXT NOT NULL, normalized_name TEXT NOT NULL UNIQUE)',
    );
    await db.execute(
      'CREATE TABLE meal_people (meal_id TEXT NOT NULL REFERENCES meals(id) ON DELETE CASCADE, person_id TEXT NOT NULL REFERENCES people(id), PRIMARY KEY (meal_id, person_id))',
    );
    await db.execute('CREATE INDEX idx_meals_date ON meals(eaten_date DESC)');
    await db.execute(
      'CREATE INDEX idx_meals_place ON meals(place_name_normalized)',
    );
    await db.execute(
      'CREATE INDEX idx_meal_items_name ON meal_items(menu_name_normalized)',
    );
    await db.execute(
      'CREATE INDEX idx_meal_photos_order ON meal_photos(meal_id, sort_order)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_cover_per_meal ON meal_photos(meal_id) WHERE is_cover = 1',
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
