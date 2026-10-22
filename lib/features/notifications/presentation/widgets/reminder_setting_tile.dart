import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';

/// Settings row for reminders. Shows a switch when [onChanged] is given,
/// otherwise a tappable value (e.g. "8:00 AM") with a chevron.
class ReminderSettingTile extends StatelessWidget {
  const ReminderSettingTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onChanged,
    this.trailingText,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Switch mode.
  final bool? value;
  final ValueChanged<bool>? onChanged;

  /// Value mode.
  final String? trailingText;
  final VoidCallback? onTap;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSwitch = onChanged != null;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: !enabled
            ? null
            : isSwitch
                ? () => onChanged!(!(value ?? false))
                : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: cs.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.subtitle),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppTextStyles.caption.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (isSwitch)
                Switch(
                  value: value ?? false,
                  onChanged: enabled ? onChanged : null,
                )
              else ...[
                if (trailingText != null)
                  Text(
                    trailingText!,
                    style: AppTextStyles.subtitle.copyWith(color: cs.primary),
                  ),
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
