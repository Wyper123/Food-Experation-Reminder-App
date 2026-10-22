import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_constants.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/constants/storage_locations.dart';
import 'package:food_expiration_reminder/core/utils/date_formatter.dart';
import 'package:food_expiration_reminder/core/utils/validators.dart';
import 'package:food_expiration_reminder/core/widgets/custom_button.dart';
import 'package:food_expiration_reminder/core/widgets/custom_text_field.dart';
import 'package:food_expiration_reminder/data/local/app_preferences.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/controllers/inventory_controller.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/screens/camera_scan_screen.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

/// Add mode when [item] is null, edit mode otherwise.
class AddEditFoodScreen extends StatefulWidget {
  const AddEditFoodScreen({super.key, this.item});

  final FoodItemModel? item;

  @override
  State<AddEditFoodScreen> createState() => _AddEditFoodScreenState();
}

class _AddEditFoodScreenState extends State<AddEditFoodScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name);
  late final _unit = TextEditingController(text: widget.item?.unit ?? 'pcs');

  late String? _category = widget.item?.category;
  late int _quantity = widget.item?.quantity ?? 1;
  // All dates are kept date-only so day counts are exact.
  late DateTime _purchaseDate = DateUtils.dateOnly(
    widget.item?.purchaseDate ?? DateTime.now(),
  );
  late DateTime? _expirationDate = _dateOnly(widget.item?.expirationDate);
  late DateTime? _openingDate = _dateOnly(widget.item?.openingDate);
  late StorageLocation _storage =
      widget.item?.storage ?? context.read<AppPreferences>().defaultStorage;
  bool _saving = false;

  /// Date errors appear only after the first save attempt.
  bool _showDateErrors = false;

  bool get _isEdit => widget.item != null;

  static DateTime? _dateOnly(DateTime? d) =>
      d == null ? null : DateUtils.dateOnly(d);

  DateTime get _today => DateUtils.dateOnly(DateTime.now());

  String? get _purchaseError => Validators.purchaseDate(_purchaseDate, _today);
  String? get _expirationError =>
      Validators.expirationDate(_expirationDate, _purchaseDate);
  String? get _openingError =>
      Validators.openingDate(_openingDate, _purchaseDate, _today);

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(
    DateTime? initial, {
    DateTime? first,
    DateTime? last,
  }) {
    final today = _today;
    first ??= DateTime(today.year - 2);
    last ??= DateTime(today.year + 5);
    var start = initial ?? today;
    if (start.isBefore(first)) start = first;
    if (start.isAfter(last)) start = last;
    return showDatePicker(
      context: context,
      initialDate: start,
      firstDate: first,
      lastDate: last,
    );
  }

  Future<void> _scan() async {
    final date = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute(builder: (_) => const CameraScanScreen()),
    );
    if (date != null) setState(() => _expirationDate = DateUtils.dateOnly(date));
  }

  Future<void> _save() async {
    final fieldsValid = _formKey.currentState!.validate();
    setState(() => _showDateErrors = true);
    final datesValid = _purchaseError == null &&
        _expirationError == null &&
        _openingError == null;
    if (!datesValid) {
      // The date fields may be scrolled out of view.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(_expirationError ?? 'Check the dates')),
        );
    }
    if (!fieldsValid || !datesValid) return;

    final existing = widget.item;
    final item = FoodItemModel(
      id: existing?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      category: _category!,
      quantity: _quantity,
      unit: _unit.text.trim(),
      brand: existing?.brand,
      storage: _storage,
      purchaseDate: _purchaseDate,
      expirationDate: _expirationDate!,
      openingDate: _openingDate,
      // Editing keeps history: when it was added and consumed/discarded.
      addedAt: existing?.addedAt ?? DateTime.now(),
      status: existing?.status ?? FoodStatus.available,
    );

    final inventory = context.read<InventoryController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await inventory.update(item);
      } else {
        await inventory.add(item);
      }
    } catch (e) {
      debugPrint('Saving food failed: $e');
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Changes saved' : '${item.name} added'),
        ),
      );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit food' : 'Add food')),
      body: _buildForm(context),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.pagePadding,
            8,
            AppConstants.pagePadding,
            12,
          ),
          child: CustomButton(
            label: _isEdit ? 'Save changes' : 'Add to inventory',
            icon: Icons.check_rounded,
            isLoading: _saving,
            onPressed: _save,
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.pagePadding,
          4,
          AppConstants.pagePadding,
          24,
        ),
        children: [
          _ScanBanner(onTap: _scan),
          const SizedBox(height: 24),
          const _SectionLabel('Item'),
          CustomTextField(
            label: 'Food name',
            hint: 'e.g. Fresh Milk',
            controller: _name,
            prefixIcon: Icons.restaurant_rounded,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter a food name' : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: CustomTextField.decoration(
              context,
              label: 'Category',
              prefixIcon: Icons.category_outlined,
            ),
            items: [
              for (final c in AppConstants.categories)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => setState(() => _category = v),
            validator: (v) => v == null ? 'Choose a category' : null,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _QuantityStepper(
                  value: _quantity,
                  onChanged: (v) => setState(() => _quantity = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: CustomTextField(
                  label: 'Unit',
                  hint: 'pcs, kg, L',
                  controller: _unit,
                  validator: (v) => Validators.required(v, 'Enter a unit'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Dates'),
          _DateField(
            label: 'Purchase date',
            icon: Icons.shopping_cart_outlined,
            value: _purchaseDate,
            errorText: _showDateErrors ? _purchaseError : null,
            onTap: () async {
              final d = await _pickDate(_purchaseDate, last: _today);
              if (d != null) setState(() => _purchaseDate = d);
            },
          ),
          const SizedBox(height: 14),
          _DateField(
            label: 'Expiration date',
            icon: Icons.event_busy_outlined,
            value: _expirationDate,
            required: true,
            errorText: _showDateErrors ? _expirationError : null,
            helperText: _expirationDate == null
                ? null
                : DateFormatter.daysLabel(
                    _expirationDate!.difference(_today).inDays,
                  ),
            onTap: () async {
              final d = await _pickDate(_expirationDate, first: _purchaseDate);
              if (d != null) setState(() => _expirationDate = d);
            },
          ),
          const SizedBox(height: 14),
          _DateField(
            label: 'Opening date (optional)',
            icon: Icons.lock_open_rounded,
            value: _openingDate,
            errorText: _showDateErrors ? _openingError : null,
            onTap: () async {
              final d = await _pickDate(
                _openingDate,
                first: _purchaseDate,
                last: _today,
              );
              if (d != null) setState(() => _openingDate = d);
            },
            onClear: _openingDate == null
                ? null
                : () => setState(() => _openingDate = null),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Storage location'),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<StorageLocation>(
              showSelectedIcon: false,
              segments: [
                for (final s in StorageLocation.values)
                  ButtonSegment(
                    value: s,
                    icon: Icon(s.icon, size: 18),
                    label: Text(s.label),
                  ),
              ],
              selected: {_storage},
              onSelectionChanged: (s) => setState(() => _storage = s.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: cs.primary.withValues(alpha: 0.14),
                selectedForegroundColor: cs.primary,
                textStyle: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanBanner extends StatelessWidget {
  const _ScanBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.document_scanner_outlined,
                  color: cs.onPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan date via camera',
                      style: AppTextStyles.title.copyWith(color: cs.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Read the expiration date from the package',
                      style: AppTextStyles.caption.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.label.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Decrease',
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Quantity',
                  style: AppTextStyles.caption.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                Text('$value', style: AppTextStyles.title),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Increase',
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
    this.required = false,
    this.onClear,
    this.errorText,
    this.helperText,
  });

  final String label;
  final IconData icon;
  final DateTime? value;
  final VoidCallback onTap;
  final bool required;
  final VoidCallback? onClear;
  final String? errorText;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        isEmpty: value == null,
        decoration: CustomTextField.decoration(
          context,
          label: required ? '$label *' : label,
          prefixIcon: icon,
          suffixIcon: onClear != null
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClear,
                )
              : const Icon(Icons.calendar_today_outlined, size: 20),
        ).copyWith(errorText: errorText, helperText: helperText),
        child: Text(
          value == null ? '' : DateFormatter.short(value!),
          style: AppTextStyles.body,
        ),
      ),
    );
  }
}
