import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiration_reminder/core/constants/storage_locations.dart';
import 'package:food_expiration_reminder/data/local/daos/food_dao.dart';
import 'package:food_expiration_reminder/data/local/daos/grocery_dao.dart';
import 'package:food_expiration_reminder/data/local/daos/household_dao.dart';
import 'package:food_expiration_reminder/data/local/daos/notification_dao.dart';
import 'package:food_expiration_reminder/data/local/daos/user_dao.dart';
import 'package:food_expiration_reminder/data/local/database_helper.dart';
import 'package:food_expiration_reminder/data/local/dev_seeder.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';
import 'package:food_expiration_reminder/data/models/grocery_item_model.dart';
import 'package:food_expiration_reminder/data/models/household_model.dart';
import 'package:food_expiration_reminder/data/models/user_model.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/controllers/inventory_controller.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';


void main() {
  sqfliteFfiInit();

  late DatabaseHelper helper;
  const hid = 'H-4B27';

  setUp(() async {
    helper = DatabaseHelper.inMemory(databaseFactoryFfi);
    await DevSeeder.seedIfEmpty(helper);
  });

  tearDown(() => helper.close());

  test('seeder is idempotent', () async {
    await DevSeeder.seedIfEmpty(helper);
    final items = await SqfliteFoodDao(helper).getAll(hid);
    expect(items, hasLength(FoodItemModel.mockList.length));
  });

  group('FoodDao', () {
    test('getAll is sorted by expiration date', () async {
      final items = await SqfliteFoodDao(helper).getAll(hid);
      final dates = items.map((e) => e.expirationDate).toList();
      expect(dates, [...dates]..sort());
    });

    test('insert/getById round-trips every field, including nulls', () async {
      final dao = SqfliteFoodDao(helper);
      final item = FoodItemModel(
        id: 'new',
        name: 'Tofu',
        category: 'Produce',
        quantity: 2,
        unit: 'blocks',
        storage: StorageLocation.freezer,
        purchaseDate: DateTime(2026, 10, 1),
        expirationDate: DateTime(2026, 10, 30),
        addedAt: DateTime(2026, 10, 1, 9, 30),
      );
      await dao.insert(item, householdId: hid);

      final loaded = (await dao.getById('new'))!;
      expect(loaded.name, 'Tofu');
      expect(loaded.storage, StorageLocation.freezer);
      expect(loaded.expirationDate, item.expirationDate);
      expect(loaded.addedAt, item.addedAt);
      expect(loaded.brand, isNull);
      expect(loaded.openingDate, isNull);
      expect(loaded.status, FoodStatus.available);
    });

    test('updateStatus and delete', () async {
      final dao = SqfliteFoodDao(helper);
      await dao.updateStatus('f1', FoodStatus.consumed);
      expect((await dao.getById('f1'))!.status, FoodStatus.consumed);

      await dao.delete('f1');
      expect(await dao.getById('f1'), isNull);
    });

    test('deleting a household cascades to its food', () async {
      final db = await helper.database;
      await db.delete('households', where: 'id = ?', whereArgs: [hid]);
      expect(await SqfliteFoodDao(helper).getAll(hid), isEmpty);
    });
  });

  test('GroceryDao check, check-all and delete-checked', () async {
    final dao = SqfliteGroceryDao(helper);
    await dao.insert(
      const GroceryItemModel(id: 'gx', name: 'Rice'),
      householdId: hid,
    );
    await dao.setAllChecked(hid, false);
    await dao.setChecked('gx', true);
    await dao.deleteChecked(hid);

    final items = await dao.getAll(hid);
    expect(items.map((e) => e.id), isNot(contains('gx')));
    expect(items, hasLength(GroceryItemModel.mockList.length));
    expect(items.first.id, 'g1', reason: 'kept in insertion order');
  });

  test('HouseholdDao loads members in join order', () async {
    final dao = SqfliteHouseholdDao(helper);
    final h = (await dao.getForUser(UserModel.mock.id))!;
    expect(h.inviteCode, 'FRESH-4B27');
    expect(h.members.map((m) => m.name), [
      'Alex Rivera',
      'Jamie Cruz',
      'Mara Santos',
      'Tita Lyn',
    ]);
    expect(h.members.first.isCurrentUser, isTrue);
    expect(h.members.first.role, HouseholdRole.admin);
    expect(await dao.findIdByInviteCode('fresh-4b27'), hid);
  });

  test('UserDao resolves household and matches email case-insensitively',
      () async {
    final dao = SqfliteUserDao(helper);
    final user = (await dao.findByEmail('ALEX.RIVERA@email.com'))!;
    expect(user.id, UserModel.mock.id);
    expect(user.householdId, hid);
  });

  test('UserDao.register is atomic', () async {
    final dao = SqfliteUserDao(helper);
    const user = UserModel(
      id: 'u-new',
      name: 'Sam',
      email: 'sam@email.com',
      accountType: 'Personal',
    );
    // Household insert fails (duplicate invite code), so no user is left.
    await expectLater(
      dao.register(
        user,
        householdId: 'h-new',
        role: HouseholdRole.admin,
        newHousehold: const HouseholdModel(
          id: 'h-new',
          name: 'Dup',
          inviteCode: 'FRESH-4B27',
          members: [],
        ),
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect(await dao.getById('u-new'), isNull);

    // Joining an existing household takes the next avatar colour.
    await dao.register(
      user,
      householdId: hid,
      role: HouseholdRole.roommate,
    );
    final members =
        (await SqfliteHouseholdDao(helper).getForUser('u-new'))!.members;
    expect(members.last.name, 'Sam');
    expect(members.last.colorIndex, 4);
  });

  test('NotificationDao markAllRead', () async {
    final dao = SqfliteNotificationDao(helper);
    await dao.markAllRead(hid);
    expect((await dao.getAll(hid)).every((n) => n.isRead), isTrue);
  });

  test('InventoryController loads on bind and persists changes', () async {
    final dao = SqfliteFoodDao(helper);
    final controller = InventoryController(dao);
    expect(controller.isLoading, isTrue);

    controller.bind(hid);
    await controller.refresh();
    expect(controller.isLoading, isFalse);
    expect(controller.items, hasLength(FoodItemModel.mockList.length));

    await controller.setStatus('f2', FoodStatus.discarded);
    expect(controller.byId('f2')!.status, FoodStatus.discarded);
    expect((await dao.getById('f2'))!.status, FoodStatus.discarded);

    controller.bind(null);
    expect(controller.items, isEmpty);
  });

  group('GroceryDao.moveToInventory', () {
    FoodItemModel food(String id) => FoodItemModel(
          id: id,
          name: 'Eggs',
          category: 'Dairy',
          quantity: 1,
          unit: 'tray',
          storage: StorageLocation.fridge,
          purchaseDate: DateTime(2026, 10, 22),
          expirationDate: DateTime(2026, 10, 29),
          addedAt: DateTime(2026, 10, 22),
        );

    test('creates the food and removes the grocery item', () async {
      await SqfliteGroceryDao(helper)
          .moveToInventory(['g2'], [food('moved')], householdId: hid);
      expect(await SqfliteFoodDao(helper).getById('moved'), isNotNull);
      final groceries = await SqfliteGroceryDao(helper).getAll(hid);
      expect(groceries.map((e) => e.id), isNot(contains('g2')));
    });

    test('rolls back completely when any insert fails', () async {
      // 'f1' already exists, so the second insert violates the primary key.
      await expectLater(
        SqfliteGroceryDao(helper).moveToInventory(
          ['g1', 'g2'],
          [food('ok'), food('f1')],
          householdId: hid,
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect(await SqfliteFoodDao(helper).getById('ok'), isNull);
      final groceries = await SqfliteGroceryDao(helper).getAll(hid);
      expect(groceries.map((e) => e.id), containsAll(['g1', 'g2']));
    });
  });

  test('grocery category round-trips', () async {
    final items = await SqfliteGroceryDao(helper).getAll(hid);
    expect(items.firstWhere((e) => e.id == 'g1').category, 'Dairy');
    expect(items.firstWhere((e) => e.id == 'g5').category, isNull);
  });

  test('upgrades a version 1 database without losing grocery rows', () async {
    final dir = Directory.systemTemp.createTempSync('fer_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = p.join(dir.path, 'v1.db');

    // The version 1 grocery table, before `category` existed.
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE grocery_items (
              id TEXT PRIMARY KEY, household_id TEXT NOT NULL,
              name TEXT NOT NULL, quantity TEXT NOT NULL,
              priority TEXT NOT NULL, is_checked INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL
            )''');
          await db.insert('grocery_items', {
            'id': 'old',
            'household_id': hid,
            'name': 'Rice',
            'quantity': '5 kg',
            'priority': 'low',
            'created_at': 0,
          });
        },
      ),
    );
    await v1.close();

    final upgraded = DatabaseHelper.atPath(databaseFactoryFfi, path);
    addTearDown(upgraded.close);
    expect(await (await upgraded.database).getVersion(), DatabaseHelper.version);
    final rows = await SqfliteGroceryDao(upgraded).getAll(hid);
    expect(rows.single.name, 'Rice');
    expect(rows.single.category, isNull);
  });
}
