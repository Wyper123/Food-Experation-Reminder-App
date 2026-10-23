import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiration_reminder/app.dart';
import 'package:food_expiration_reminder/data/local/app_preferences.dart';
import 'package:food_expiration_reminder/data/local/daos/food_dao.dart';
import 'package:food_expiration_reminder/data/local/daos/grocery_dao.dart';
import 'package:food_expiration_reminder/data/local/database_helper.dart';
import 'package:food_expiration_reminder/data/local/dev_seeder.dart';
import 'package:food_expiration_reminder/features/auth/presentation/screens/register_screen.dart';
import 'package:food_expiration_reminder/features/notifications/reminders/reminder_scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_helpers.dart';

/// Pumps frames without waiting for shimmer animations to settle.
Future<void> pumpFor(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Completes [future] inside the test's fake async zone by pumping frames.
Future<T> pumpUntilDone<T>(WidgetTester tester, Future<T> future) async {
  T? result;
  var done = false;
  future.then((v) {
    result = v;
    done = true;
  });
  for (var i = 0; i < 200 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(done, isTrue, reason: 'future did not complete');
  return result as T;
}

void main() {
  late AppPreferences prefs;
  late NoopReminderScheduler scheduler;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    sqfliteFfiInit();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await AppPreferences.load();
    scheduler = NoopReminderScheduler();
  });

  Future<DatabaseHelper> pumpApp(WidgetTester tester) async {
    // The no-isolate factory runs SQLite synchronously, so all queries
    // complete on the test's fake clock.
    final db = DatabaseHelper.inMemory(databaseFactoryFfiNoIsolate);
    await pumpUntilDone(tester, DevSeeder.seedIfEmpty(db, fastHasher));
    await tester.pumpWidget(
      FoodExpirationApp(
        database: db,
        preferences: prefs,
        scheduler: scheduler,
        hasher: fastHasher,
      ),
    );
    await pumpFor(tester, 3);
    return db;
  }

  Future<void> logIn(WidgetTester tester, String password) async {
    await tester.enterText(
      find.byType(TextFormField).at(0),
      DevSeeder.demoEmail,
    );
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await tester.tap(find.text('Log in'));
    await pumpFor(tester);
  }

  testWidgets('wrong password shows an error and stays on login',
      (tester) async {
    final db = await pumpApp(tester);
    await logIn(tester, 'not-the-password');

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.text('Use first'), findsNothing);
    await pumpUntilDone(tester, db.close());
  });

  testWidgets('log in, every tab renders from SQLite, log out', (tester) async {
    final db = await pumpApp(tester);
    await logIn(tester, DevSeeder.demoPassword);

    expect(find.text('Use first'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(prefs.sessionUserId, isNotNull);

    await tester.tap(find.text('Inventory').last);
    await pumpFor(tester);
    // Sorted by expiration date, so the most overdue item is first.
    expect(find.text('Pandesal'), findsOneWidget);

    await tester.tap(find.text('Groceries').last);
    await pumpFor(tester);
    expect(find.text('Fresh Milk'), findsOneWidget);

    await tester.tap(find.text('Household').last);
    await pumpFor(tester);
    expect(find.text('FRESH-4B27'), findsOneWidget);

    await tester.tap(find.text('Profile').last);
    await pumpFor(tester);
    expect(find.text(DevSeeder.demoEmail), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Log out'), 200);
    await tester.tap(find.text('Log out'));
    await pumpFor(tester);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(prefs.sessionUserId, isNull);

    await pumpUntilDone(tester, db.close());
  });

  testWidgets('add food: validates, saves to SQLite, shows in inventory',
      (tester) async {
    // A tall phone-like screen so the whole form is laid out at once.
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = await pumpApp(tester);
    await logIn(tester, DevSeeder.demoPassword);

    await tester.tap(find.text('Add food'));
    await pumpFor(tester, 5);

    // Saving an empty form shows the field errors and stays put.
    await tester.tap(find.text('Add to inventory'));
    await pumpFor(tester, 3);
    expect(find.text('Enter a food name'), findsOneWidget);
    expect(find.text('Enter a category'), findsOneWidget);
    // Once as a snackbar (dates may be off-screen), once under the field.
    expect(find.text('Set an expiration date'), findsNWidgets(2));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Food name'),
      'Tofu',
    );
    // Typed lowercase; saved with the built-in category's spelling.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Category'),
      'produce',
    );
    await pumpFor(tester, 3);

    // Expires today: the earliest date the picker allows.
    await tester.tap(find.widgetWithText(InkWell, 'Expiration date *'));
    await pumpFor(tester, 3);
    await tester.tap(find.text('${DateTime.now().day}').last);
    await tester.tap(find.text('OK'));
    await pumpFor(tester, 3);
    expect(find.text('Expires today'), findsOneWidget);

    await tester.tap(find.text('Add to inventory'));
    await pumpFor(tester);
    expect(find.text('Tofu added'), findsOneWidget);

    final saved = (await pumpUntilDone(
      tester,
      SqfliteFoodDao(db).getAll('H-4B27'),
    ))
        .where((e) => e.name == 'Tofu')
        .single;
    expect(saved.category, 'Produce');
    expect(saved.daysRemaining, 0);

    await tester.tap(find.text('Inventory').last);
    await pumpFor(tester);
    expect(find.text('Tofu'), findsOneWidget);
    await pumpUntilDone(tester, db.close());
  });

  testWidgets('edit food keeps its id and updates the detail screen',
      (tester) async {
    final db = await pumpApp(tester);
    await logIn(tester, DevSeeder.demoPassword);
    await tester.tap(find.text('Inventory').last);
    await pumpFor(tester);

    await tester.tap(find.text('Pandesal'));
    await pumpFor(tester);
    await tester.tap(find.byTooltip('Edit'));
    await pumpFor(tester, 5);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Pandesal'),
      'Pandesal (day-old)',
    );
    await tester.tap(find.text('Save changes'));
    await pumpFor(tester);

    expect(find.text('Food details'), findsOneWidget);
    expect(find.text('Pandesal (day-old)'), findsOneWidget);
    final stored =
        await pumpUntilDone(tester, SqfliteFoodDao(db).getById('f11'));
    expect(stored!.name, 'Pandesal (day-old)');
    await pumpUntilDone(tester, db.close());
  });

  testWidgets('tapping the Expired counter opens a filtered inventory',
      (tester) async {
    final db = await pumpApp(tester);
    await logIn(tester, DevSeeder.demoPassword);

    await tester.tap(find.text('Expired'));
    await pumpFor(tester);

    expect(find.text('Inventory'), findsWidgets);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('Pandesal'), findsOneWidget);
    expect(find.text('Baby Spinach'), findsOneWidget);
    expect(find.text('Eggs'), findsNothing);

    await tester.tap(find.text('All'));
    await pumpFor(tester);
    expect(find.text('2 items'), findsNothing);
    await pumpUntilDone(tester, db.close());
  });

  testWidgets('Use first quick action adds to the grocery list once',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = await pumpApp(tester);
    await logIn(tester, DevSeeder.demoPassword);

    Future<void> addChickenToGroceries() async {
      final card = find.ancestor(
        of: find.text('Chicken Breast'),
        matching: find.byType(Card),
      );
      await tester.tap(
        find.descendant(of: card, matching: find.byTooltip('Quick actions')),
      );
      await pumpFor(tester, 3);
      await tester.tap(find.text('Add to grocery list'));
      // Old snackbar animates out, the new one animates in.
      await pumpFor(tester, 15);
    }

    await addChickenToGroceries();
    expect(
      find.text('Chicken Breast added to your grocery list'),
      findsOneWidget,
    );
    await addChickenToGroceries();
    expect(
      find.text('Chicken Breast is already on your grocery list'),
      findsOneWidget,
    );

    await tester.tap(find.text('View'));
    await pumpFor(tester);
    expect(find.text('Chicken Breast'), findsOneWidget);
    expect(find.text('500 g · Meat & Seafood'), findsOneWidget);
    await pumpUntilDone(tester, db.close());
  });

  testWidgets('a new account starts with an empty kitchen', (tester) async {
    final db = await pumpApp(tester);
    await tester.tap(find.text('Create account'));
    await pumpFor(tester, 5);

    // The login screen's fields are still mounted underneath.
    final fields = find.descendant(
      of: find.byType(RegisterScreen),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(0), 'Sam Lee');
    await tester.enterText(fields.at(1), 'sam@email.com');
    await tester.enterText(fields.at(2), 'longenough');
    await tester.enterText(fields.at(3), 'longenough');
    await tester.ensureVisible(find.text('Create account').last);
    await tester.tap(find.text('Create account').last);
    await pumpFor(tester);

    expect(find.text('Sam'), findsOneWidget);
    expect(find.text("Sam's Kitchen · 1 member"), findsOneWidget);
    expect(find.text('Your kitchen is empty'), findsOneWidget);
    await pumpUntilDone(tester, db.close());
  });

  testWidgets('move checked groceries into the inventory', (tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = await pumpApp(tester);
    await logIn(tester, DevSeeder.demoPassword);

    await tester.tap(find.text('Groceries').last);
    await pumpFor(tester);
    // Eggs is checked in the demo data; also tick Tea Bags (no category).
    // Tapping the row edits, so tick its checkbox.
    await tester.tap(
      find.descendant(
        of: find.ancestor(
            of: find.text('Tea Bags'), matching: find.byType(Card)),
        matching: find.byType(Checkbox),
      ),
    );
    await pumpFor(tester, 3);
    await tester.tap(find.text('Move 2 checked to inventory'));
    await pumpFor(tester, 5);

    expect(find.text('Move to inventory'), findsOneWidget);
    expect(find.text('Estimated · 7 days left'), findsNWidgets(2));

    // Tea Bags has no category yet, so confirming is blocked.
    await tester.tap(find.text('Add 2 items to inventory'));
    await pumpFor(tester, 3);
    expect(find.text('Enter a category'), findsOneWidget);

    final teaCard = find.ancestor(
      of: find.text('Tea Bags'),
      matching: find.byType(Card),
    );
    await tester.enterText(
      find.descendant(
        of: teaCard,
        matching: find.widgetWithText(TextFormField, 'Category'),
      ),
      'Beverages',
    );
    await pumpFor(tester, 3);
    // Fridge default: Beverages estimate replaces the fallback.
    expect(find.text('Estimated · 10 days left'), findsOneWidget);

    await tester.tap(find.text('Add 2 items to inventory'));
    await pumpFor(tester);
    expect(find.text('2 items added to your inventory'), findsOneWidget);
    expect(find.text('Tea Bags'), findsNothing);

    final foods = await pumpUntilDone(
      tester,
      SqfliteFoodDao(db).getAll('H-4B27'),
    );
    final tea = foods.singleWhere((e) => e.name == 'Tea Bags');
    expect(tea.category, 'Beverages');
    expect((tea.quantity, tea.unit), (1, 'box'));
    expect(tea.daysRemaining, 10);
    expect(foods.where((e) => e.name == 'Eggs'), hasLength(2));
    await pumpUntilDone(tester, db.close());
  });

  testWidgets('reminder settings persist and drive the schedule',
      (tester) async {
    final db = await pumpApp(tester);
    await logIn(tester, DevSeeder.demoPassword);
    expect(scheduler.scheduled, isNotEmpty, reason: 'scheduled after login');

    await tester.tap(find.byTooltip('Notifications'));
    await pumpFor(tester, 5);
    await tester.tap(find.text('Reminder settings'));
    await pumpFor(tester, 5);

    await tester.tap(find.text('Send a test notification'));
    await pumpFor(tester, 3);
    expect(scheduler.testsShown, 1);

    await tester.tap(find.text('Remind me'));
    await pumpFor(tester, 5);
    await tester.tap(find.text('On the day only'));
    await pumpFor(tester, 5);
    expect(prefs.reminderSettings.daysBefore, 0);
    expect(
      scheduler.scheduled.where((r) => r.title.contains('expires in')),
      isEmpty,
    );

    await tester.tap(find.byType(Switch).first);
    await pumpFor(tester, 5);
    expect(prefs.reminderSettings.enabled, isFalse);
    expect(scheduler.scheduled, isEmpty);
    await pumpUntilDone(tester, db.close());
  });

  testWidgets('admin removes a member through the member menu', (tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = await pumpApp(tester);
    await logIn(tester, DevSeeder.demoPassword);
    await tester.tap(find.text('Household').last);
    await pumpFor(tester);

    final jamieRow = find
        .ancestor(
          of: find.text('Jamie Cruz'),
          matching: find.byType(Row),
        )
        .first;
    await tester.tap(
      find.descendant(of: jamieRow, matching: find.byTooltip('Member options')),
    );
    await pumpFor(tester, 3);
    await tester.tap(find.text('Remove from household'));
    await pumpFor(tester, 5);
    await tester.tap(find.text('Remove member'));
    await pumpFor(tester);

    expect(find.text('Jamie Cruz was removed'), findsOneWidget);
    expect(find.text('Jamie Cruz'), findsNothing);
    await pumpUntilDone(tester, db.close());
  });

  testWidgets('a new user joins the demo household with its invite code',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = await pumpApp(tester);

    await tester.tap(find.text('Create account'));
    await pumpFor(tester, 5);
    final fields = find.descendant(
      of: find.byType(RegisterScreen),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(0), 'Sam Lee');
    await tester.enterText(fields.at(1), 'sam@email.com');
    await tester.enterText(fields.at(2), 'longenough');
    await tester.enterText(fields.at(3), 'longenough');
    await tester.tap(find.text('Create account').last);
    await pumpFor(tester);

    await tester.tap(find.text('Household').last);
    await pumpFor(tester);
    expect(find.text("Sam's Kitchen"), findsOneWidget);
    expect(find.text('Leave household'), findsNothing, reason: 'sole member');

    await tester.tap(find.byTooltip('Join another household'));
    await pumpFor(tester, 5);
    await tester.enterText(find.byType(TextField).last, 'fresh-4b27');
    await tester.tap(find.text('Join household'));
    await pumpFor(tester, 5);
    // Sole member: confirm deleting the empty personal kitchen.
    expect(find.text("Delete Sam's Kitchen?"), findsOneWidget);
    await tester.tap(find.text('Delete and continue'));
    await pumpFor(tester, 15);

    expect(find.text('Dorm 4B Household'), findsOneWidget);
    expect(find.text('Sam Lee (You)'), findsOneWidget);
    expect(find.text('Leave household'), findsOneWidget);
    expect(find.byTooltip('Household options'), findsNothing,
        reason: 'roommates cannot manage');

    await tester.tap(find.text('Inventory').last);
    await pumpFor(tester);
    expect(find.text('Pandesal'), findsOneWidget, reason: 'shared food');
    await pumpUntilDone(tester, db.close());
  });

  testWidgets('scan screen without a camera falls back to manual entry',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = await pumpApp(tester);
    await logIn(tester, DevSeeder.demoPassword);
    await tester.tap(find.text('Add food'));
    await pumpFor(tester, 5);

    await tester.tap(find.text('Scan date via camera'));
    // No camera plugin in tests, so start-up times out (after 8 s) and the
    // screen offers the alternatives instead of loading forever.
    await pumpFor(tester, 90);
    expect(find.text('Scan a photo'), findsOneWidget);
    await tester.tap(find.text('Enter date manually'));
    await pumpFor(tester, 3);
    await tester.tap(find.text('OK'));
    await pumpFor(tester, 5);

    expect(find.text('Add food'), findsOneWidget);
    expect(find.text('Expires today'), findsOneWidget);
    await pumpUntilDone(tester, db.close());
  });

  testWidgets('tapping a grocery item edits it', (tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = await pumpApp(tester);
    await logIn(tester, DevSeeder.demoPassword);
    await tester.tap(find.text('Groceries').last);
    await pumpFor(tester);

    await tester.tap(find.text('Bananas'));
    await pumpFor(tester, 5);
    expect(find.text('Edit item'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Item name'), 'Lakatan Bananas');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantity'), '2 bunches');
    await tester.tap(find.text('Save'));
    await pumpFor(tester, 5);

    expect(find.text('Lakatan Bananas'), findsOneWidget);
    expect(find.text('2 bunches · Produce'), findsOneWidget);
    final stored = await pumpUntilDone(
      tester,
      SqfliteGroceryDao(db).getAll('H-4B27'),
    );
    final bananas = stored.singleWhere((e) => e.id == 'g3');
    expect((bananas.name, bananas.quantity, bananas.isChecked),
        ('Lakatan Bananas', '2 bunches', false));
    await pumpUntilDone(tester, db.close());
  });

  testWidgets('storage labels stay on one line on a 360dp phone',
      (tester) async {
    // Same size as the itel P661N: 720x1612 px at 2x.
    tester.view.physicalSize = const Size(720, 1612);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final db = await pumpApp(tester);
    await logIn(tester, DevSeeder.demoPassword);
    await tester.tap(find.text('Add food'));
    await pumpFor(tester, 5);
    await tester.scrollUntilVisible(
      find.text('Cabinet'),
      200,
      scrollable: find
          .descendant(of: find.byType(Form), matching: find.byType(Scrollable))
          .first,
    );
    await pumpFor(tester, 2);

    for (final label in ['Fridge', 'Freezer', 'Pantry', 'Cabinet']) {
      final text = find.text(label);
      final style = tester.widget<Text>(text).style!;
      // One line is font size x line height; a wrapped label is twice that.
      expect(
        tester.getSize(text).height,
        lessThan(style.fontSize! * 1.6),
        reason: '$label wrapped onto two lines',
      );
    }
    await pumpUntilDone(tester, db.close());
  });

  testWidgets('a custom category is saved as typed', (tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = await pumpApp(tester);
    await logIn(tester, DevSeeder.demoPassword);
    await tester.tap(find.text('Add food'));
    await pumpFor(tester, 5);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Food name'), 'Lakatan');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Category'), 'tropical fruit');
    await tester.tap(find.widgetWithText(InkWell, 'Expiration date *'));
    await pumpFor(tester, 3);
    await tester.tap(find.text('${DateTime.now().day}').last);
    await tester.tap(find.text('OK'));
    await pumpFor(tester, 3);
    await tester.tap(find.text('Add to inventory'));
    await pumpFor(tester);

    final saved = (await pumpUntilDone(
      tester,
      SqfliteFoodDao(db).getAll('H-4B27'),
    ))
        .singleWhere((e) => e.name == 'Lakatan');
    expect(saved.category, 'Tropical fruit');
    await pumpUntilDone(tester, db.close());
  });

  testWidgets('theme setting shows and switches System / Light / Dark',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = await pumpApp(tester);
    await logIn(tester, DevSeeder.demoPassword);
    await tester.tap(find.text('Profile').last);
    await pumpFor(tester);

    // First launch follows the phone, and says so.
    expect(prefs.themeMode, ThemeMode.system);
    expect(find.text('System'), findsOneWidget);

    await tester.tap(find.text('Theme'));
    await pumpFor(tester, 5);
    await tester.tap(find.text('Dark'));
    await pumpFor(tester, 5);
    expect(prefs.themeMode, ThemeMode.dark);
    expect(find.text('Dark'), findsOneWidget);
    await pumpUntilDone(tester, db.close());
  });
}
