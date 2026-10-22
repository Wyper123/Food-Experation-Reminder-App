import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/utils/status_color_helper.dart';
import 'package:food_expiration_reminder/core/widgets/custom_button.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';

/// Lets the user mark a food item as Available, Consumed or Discarded.
Future<FoodStatus?> showFoodStatusDialog(
  BuildContext context, {
  required FoodStatus current,
}) {
  return showDialog<FoodStatus>(
    context: context,
    builder: (_) => FoodStatusDialog(current: current),
  );
}

class FoodStatusDialog extends StatefulWidget {
  const FoodStatusDialog({super.key, required this.current});

  final FoodStatus current;

  @override
  State<FoodStatusDialog> createState() => _FoodStatusDialogState();
}

class _FoodStatusDialogState extends State<FoodStatusDialog> {
  late FoodStatus _selected;

  static const _options = [
    (FoodStatus.available, 'Still in storage'),
    (FoodStatus.consumed, 'Eaten or used up'),
    (FoodStatus.discarded, 'Thrown away'),
  ];

  @override
  void initState() {
    super.initState();
    _selected = (widget.current == FoodStatus.consumed ||
            widget.current == FoodStatus.discarded)
        ? widget.current
        : FoodStatus.available;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Update status', style: AppTextStyles.headline),
              const SizedBox(height: 4),
              Text(
                'Expired and Use Soon are set automatically from the date.',
                style: AppTextStyles.caption.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              for (final (status, description) in _options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OptionTile(
                    status: status,
                    description: description,
                    selected: _selected == status,
                    onTap: () => setState(() => _selected = status),
                  ),
                ),
              const SizedBox(height: 6),
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
                      label: 'Save',
                      onPressed: () => Navigator.of(context).pop(_selected),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.status,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final FoodStatus status;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = StatusColorHelper.foreground(context, status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? StatusColorHelper.background(context, status)
              : Colors.transparent,
          border: Border.all(
            color: selected ? fg : cs.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(StatusColorHelper.icon(status), color: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(StatusColorHelper.label(status),
                      style: AppTextStyles.subtitle),
                  Text(
                    description,
                    style: AppTextStyles.caption
                        .copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: fg),
          ],
        ),
      ),
    );
  }
}
