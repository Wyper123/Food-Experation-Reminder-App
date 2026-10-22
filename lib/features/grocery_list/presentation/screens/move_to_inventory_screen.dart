import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_constants.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/constants/shelf_life.dart';
import 'package:food_expiration_reminder/core/constants/storage_locations.dart';
import 'package:food_expiration_reminder/core/utils/date_formatter.dart';
import 'package:food_expiration_reminder/core/utils/quantity_parser.dart';
import 'package:food_expiration_reminder/core/utils/validators.dart';
import 'package:food_expiration_reminder/core/widgets/custom_button.dart';
import 'package:food_expiration_reminder/core/widgets/custom_text_field.dart';
import 'package:food_expiration_reminder/data/local/app_preferences.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';
import 'package:food_expiration_reminder/data/models/grocery_item_model.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/controllers/inventory_controller.dart';
import 'package:food_expiration_reminder/features/grocery_list/presentation/controllers/grocery_controller.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

/// Review step for checked groceries: confirm category, storage and an
/// (estimated) expiration date per item, then move them all at once.
/// Pops with the number of items moved.
class MoveToInventoryScreen extends StatefulWidget {
  const MoveToInventoryScreen({super.key, required this.items});

  final List<GroceryItemModel> items;

  @override
  State<MoveToInventoryScreen> createState() => _MoveToInventoryScreenState();
}

/// Editable state for one grocery item on its way to the inventory.
class _Draft {
  _Draft(this.source, this.storage, DateTime today)
      : category = source.category,
        name = TextEditingController(text: source.name) {
    final q = parseQuantity(source.quantity);
    quantity = TextEditingController(text: '${q.quantity}');
    unit = TextEditingController(text: q.unit);
    reestimate(today);
  }

  final GroceryItemModel source;

  /// Editable here so typos can be fixed on the way into the inventory.
  final TextEditingController name;
  late final TextEditingController quantity;
  late final TextEditingController unit;
  String? category;
  StorageLocation storage;
  late DateTime expiration;

  /// Once the user picks a date, category/storage changes stop overriding it.
  bool dateSetByUser = false;

  void dispose() {
    name.dispose();
    quantity.dispose();
    unit.dispose();
  }

  void reestimate(DateTime today) {
    if (dateSetByUser) return;
    expiration = today.add(
      Duration(days: ShelfLife.estimateDays(category, storage)),
    );
  }
}

class _MoveToInventoryScreenState extends State<MoveToInventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final DateTime _today = DateUtils.dateOnly(DateTime.now());
  late final List<_Draft> _drafts = [
    for (final g in widget.items)
      _Draft(g, context.read<AppPreferences>().defaultStorage, _today),
  ];
  bool _saving = false;

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  void _storeAllIn(StorageLocation storage) {
    setState(() {
      for (final d in _drafts) {
        d
          ..storage = storage
          ..reestimate(_today);
      }
    });
  }

  Future<void> _pickDate(_Draft d) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: d.expiration,
      firstDate: _today,
      lastDate: DateTime(_today.year + 5),
    );
    if (picked != null) {
      setState(() {
        d
          ..expiration = picked
          ..dateSetByUser = true;
      });
    }
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final foods = [
      for (final d in _drafts)
        FoodItemModel(
          id: const Uuid().v4(),
          name: d.name.text.trim(),
          category: d.category!,
          quantity: int.parse(d.quantity.text.trim()),
          unit: d.unit.text.trim(),
          storage: d.storage,
          purchaseDate: _today,
          expirationDate: d.expiration,
          addedAt: now,
        ),
    ];

    final grocery = context.read<GroceryController>();
    final inventory = context.read<InventoryController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await grocery.moveToInventory(
        [for (final d in _drafts) d.source.id],
        foods,
      );
    } catch (e) {
      debugPrint('Moving groceries failed: $e');
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not move items. Nothing changed.')),
      );
      return;
    }
    await inventory.refresh();
    navigator.pop(foods.length);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shared = _drafts.map((d) => d.storage).toSet();
    return Scaffold(
      appBar: AppBar(title: const Text('Move to inventory')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.pagePadding,
            8,
            AppConstants.pagePadding,
            12,
          ),
          child: CustomButton(
            label: _drafts.length == 1
                ? 'Add 1 item to inventory'
                : 'Add ${_drafts.length} items to inventory',
            icon: Icons.move_down_rounded,
            isLoading: _saving,
            onPressed: _confirm,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.pagePadding,
            4,
            AppConstants.pagePadding,
            24,
          ),
          children: [
            Text(
              'Expiration dates are estimates. Check them against the '
              'packages before saving.',
              style: AppTextStyles.body.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              'STORE ALL IN',
              style: AppTextStyles.label.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<StorageLocation>(
                showSelectedIcon: false,
                emptySelectionAllowed: true,
                segments: [
                  for (final s in StorageLocation.values)
                    ButtonSegment(value: s, label: Text(s.label)),
                ],
                // Nothing is highlighted once items use different places.
                selected: shared.length == 1 ? shared : const {},
                onSelectionChanged: (s) {
                  if (s.isNotEmpty) _storeAllIn(s.first);
                },
              ),
            ),
            const SizedBox(height: 20),
            for (final d in _drafts) ...[
              _DraftCard(
                draft: d,
                today: _today,
                onCategory: (c) => setState(() {
                  d
                    ..category = c
                    ..reestimate(_today);
                }),
                onStorage: (s) => setState(() {
                  d
                    ..storage = s
                    ..reestimate(_today);
                }),
                onPickDate: () => _pickDate(d),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.draft,
    required this.today,
    required this.onCategory,
    required this.onStorage,
    required this.onPickDate,
  });

  final _Draft draft;
  final DateTime today;
  final ValueChanged<String?> onCategory;
  final ValueChanged<StorageLocation> onStorage;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final days = draft.expiration.difference(today).inDays;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextField(
              label: 'Name',
              controller: draft.name,
              validator: (v) => Validators.required(v, 'Enter a name'),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: CustomTextField(
                    label: 'Quantity',
                    controller: draft.quantity,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      return n == null || n < 1 ? 'Whole number' : null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: CustomTextField(
                    label: 'Unit',
                    controller: draft.unit,
                    validator: (v) => Validators.required(v, 'Enter a unit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: draft.category,
                    isExpanded: true,
                    decoration: CustomTextField.decoration(
                      context,
                      label: 'Category',
                    ),
                    items: [
                      for (final c in AppConstants.categories)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: onCategory,
                    validator: (v) => v == null ? 'Choose one' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<StorageLocation>(
                    // Keyed so "Store all in" can replace the value.
                    key: ValueKey('${draft.source.id}-${draft.storage.name}'),
                    initialValue: draft.storage,
                    isExpanded: true,
                    decoration: CustomTextField.decoration(
                      context,
                      label: 'Storage',
                    ),
                    items: [
                      for (final s in StorageLocation.values)
                        DropdownMenuItem(value: s, child: Text(s.label)),
                    ],
                    onChanged: (s) => onStorage(s!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: onPickDate,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: CustomTextField.decoration(
                  context,
                  label: 'Expiration date',
                  prefixIcon: Icons.event_busy_outlined,
                  suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                ).copyWith(
                  helperText: draft.dateSetByUser
                      ? DateFormatter.daysLabel(days)
                      : 'Estimated · ${DateFormatter.daysLabel(days)}',
                ),
                child: Text(
                  DateFormatter.short(draft.expiration),
                  style: AppTextStyles.body,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
