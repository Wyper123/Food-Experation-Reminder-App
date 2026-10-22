import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_constants.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/widgets/custom_button.dart';
import 'package:food_expiration_reminder/core/widgets/custom_text_field.dart';
import 'package:food_expiration_reminder/data/models/grocery_item_model.dart';

/// Adds a new item, or edits [item] when given. Returns the result, or
/// null when cancelled.
Future<GroceryItemModel?> showAddGroceryDialog(
  BuildContext context, {
  GroceryItemModel? item,
}) {
  return showDialog<GroceryItemModel>(
    context: context,
    builder: (_) => AddGroceryDialog(item: item),
  );
}

class AddGroceryDialog extends StatefulWidget {
  const AddGroceryDialog({super.key, this.item});

  final GroceryItemModel? item;

  @override
  State<AddGroceryDialog> createState() => _AddGroceryDialogState();
}

class _AddGroceryDialogState extends State<AddGroceryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name);
  late final _quantity =
      TextEditingController(text: widget.item?.quantity ?? '1');
  late GroceryPriority _priority =
      widget.item?.priority ?? GroceryPriority.medium;
  late String? _category = widget.item?.category;

  bool get _isEdit => widget.item != null;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      GroceryItemModel(
        id: widget.item?.id ?? 'g${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        quantity: _quantity.text.trim().isEmpty ? '1' : _quantity.text.trim(),
        priority: _priority,
        category: _category,
        isChecked: widget.item?.isChecked ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Edit item' : 'Add to grocery list',
                  style: AppTextStyles.headline,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Item name',
                  hint: 'e.g. Bananas',
                  controller: _name,
                  prefixIcon: Icons.local_grocery_store_outlined,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter an item' : null,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Quantity',
                  hint: 'e.g. 2 packs',
                  controller: _quantity,
                  prefixIcon: Icons.numbers_rounded,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: CustomTextField.decoration(
                    context,
                    label: 'Category (optional)',
                    prefixIcon: Icons.category_outlined,
                  ),
                  items: [
                    for (final c in AppConstants.categories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() => _category = v),
                ),
                const SizedBox(height: 16),
                Text(
                  'PRIORITY',
                  style: AppTextStyles.label.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<GroceryPriority>(
                    showSelectedIcon: false,
                    segments: [
                      for (final p in GroceryPriority.values)
                        ButtonSegment(value: p, label: Text(p.label)),
                    ],
                    selected: {_priority},
                    onSelectionChanged: (s) =>
                        setState(() => _priority = s.first),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        label: 'Cancel',
                        variant: CustomButtonVariant.secondary,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        label: _isEdit ? 'Save' : 'Add',
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
