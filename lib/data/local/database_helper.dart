import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Owns the single SQLite connection and the schema.
///
/// Dates are stored as INTEGER milliseconds since epoch; enums as their
/// `.name`; booleans as 0/1.
class DatabaseHelper {
  DatabaseHelper._([this._factory, this._path]);

  static final DatabaseHelper instance = DatabaseHelper._();

  /// Fresh in-memory database, used by tests.
  factory DatabaseHelper.inMemory(DatabaseFactory factory) =>
      DatabaseHelper._(factory, inMemoryDatabasePath);

  /// Database file at [path], used by migration tests.
  factory DatabaseHelper.atPath(DatabaseFactory factory, String path) =>
      DatabaseHelper._(factory, path);

  static const String fileName = 'food_expiration.db';

  /// History:
  ///   1 — initial schema
  ///   2 — grocery_items.category
  static const int version = 2;

  final DatabaseFactory? _factory;
  final String? _path;
  Future<Database>? _db;

  /// Opens lazily; concurrent callers share the same open future.
  Future<Database> get database => _db ??= _open();

  Future<Database> _open() async {
    final factory = _factory ?? databaseFactory;
    final path = _path ?? join(await factory.getDatabasesPath(), fileName);
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null) await (await db).close();
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE users (
          id            TEXT PRIMARY KEY,
          name          TEXT NOT NULL,
          email         TEXT NOT NULL UNIQUE COLLATE NOCASE,
          password_hash TEXT NOT NULL,
          account_type  TEXT NOT NULL,
          created_at    INTEGER NOT NULL
        )''')
      ..execute('''
        CREATE TABLE households (
          id          TEXT PRIMARY KEY,
          name        TEXT NOT NULL,
          invite_code TEXT NOT NULL UNIQUE,
          created_at  INTEGER NOT NULL
        )''')
      ..execute('''
        CREATE TABLE household_members (
          household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
          user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          role         TEXT NOT NULL,
          color_index  INTEGER NOT NULL DEFAULT 0,
          joined_at    INTEGER NOT NULL,
          PRIMARY KEY (household_id, user_id)
        )''')
      ..execute('''
        CREATE TABLE food_items (
          id              TEXT PRIMARY KEY,
          household_id    TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
          name            TEXT NOT NULL,
          category        TEXT NOT NULL,
          quantity        INTEGER NOT NULL,
          unit            TEXT NOT NULL,
          brand           TEXT,
          storage         TEXT NOT NULL,
          purchase_date   INTEGER NOT NULL,
          expiration_date INTEGER NOT NULL,
          opening_date    INTEGER,
          status          TEXT NOT NULL,
          added_at        INTEGER NOT NULL
        )''')
      ..execute(
        'CREATE INDEX idx_food_household_exp '
        'ON food_items (household_id, expiration_date)',
      )
      ..execute('''
        CREATE TABLE grocery_items (
          id           TEXT PRIMARY KEY,
          household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
          name         TEXT NOT NULL,
          quantity     TEXT NOT NULL,
          priority     TEXT NOT NULL,
          category     TEXT,
          is_checked   INTEGER NOT NULL DEFAULT 0,
          created_at   INTEGER NOT NULL
        )''')
      ..execute('''
        CREATE TABLE notifications (
          id           TEXT PRIMARY KEY,
          household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
          food_id      TEXT REFERENCES food_items(id) ON DELETE CASCADE,
          title        TEXT NOT NULL,
          body         TEXT NOT NULL,
          type         TEXT NOT NULL,
          created_at   INTEGER NOT NULL,
          is_read      INTEGER NOT NULL DEFAULT 0
        )''');
    await batch.commit(noResult: true);
  }

  /// One step per version, applied in order, so any old install catches up.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE grocery_items ADD COLUMN category TEXT');
    }
  }
}
