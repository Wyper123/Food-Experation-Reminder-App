import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_colors.dart';
import 'package:food_expiration_reminder/core/constants/app_constants.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/constants/storage_locations.dart';
import 'package:food_expiration_reminder/core/widgets/custom_button.dart';
import 'package:food_expiration_reminder/core/widgets/skeleton_loader.dart';
import 'package:food_expiration_reminder/data/local/app_preferences.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';
import 'package:food_expiration_reminder/data/models/user_model.dart';
import 'package:food_expiration_reminder/features/auth/presentation/controllers/session_controller.dart';
import 'package:food_expiration_reminder/features/food_inventory/inventory_csv.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/controllers/inventory_controller.dart';
import 'package:food_expiration_reminder/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:food_expiration_reminder/features/notifications/presentation/widgets/reminder_setting_tile.dart';
import 'package:food_expiration_reminder/features/profile/presentation/widgets/account_sheets.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

/// User profile & preferences (Feature 2).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _pickDefaultStorage() async {
    final prefs = context.read<AppPreferences>();
    final picked = await showModalBottomSheet<StorageLocation>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Default storage', style: AppTextStyles.title),
            ),
            for (final s in StorageLocation.values)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: Icon(s.icon),
                title: Text(s.fullLabel),
                trailing: s == prefs.defaultStorage
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(ctx).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(ctx).pop(s),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) await prefs.setDefaultStorage(picked);
  }

  Future<void> _exportInventory() async {
    final items = context.read<InventoryController>().items;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to export yet')),
      );
      return;
    }
    final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Food inventory $stamp',
        files: [
          XFile.fromData(
            utf8.encode(inventoryToCsv(items)),
            mimeType: 'text/csv',
          ),
        ],
        fileNameOverrides: ['food-inventory-$stamp.csv'],
      ),
    );
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  Future<void> _pickTheme() async {
    final prefs = context.read<AppPreferences>();
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Theme', style: AppTextStyles.title),
            ),
            for (final (mode, icon, subtitle) in const [
              (
                ThemeMode.system,
                Icons.brightness_auto_outlined,
                'Match your phone',
              ),
              (ThemeMode.light, Icons.light_mode_outlined, null),
              (ThemeMode.dark, Icons.dark_mode_outlined, null),
            ])
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: Icon(icon),
                title: Text(_themeLabel(mode)),
                subtitle: subtitle == null ? null : Text(subtitle),
                trailing: mode == prefs.themeMode
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(ctx).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(ctx).pop(mode),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) await prefs.setThemeMode(picked);
  }

  Future<void> _changePassword() async {
    final changed = await showChangePasswordSheet(context);
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
    }
  }

  void _logout() {
    // StartupGate (the first route) shows the login screen once signed out.
    Navigator.of(context).popUntil((r) => r.isFirst);
    context.read<SessionController>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    final inventory = context.watch<InventoryController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.pagePadding,
          4,
          AppConstants.pagePadding,
          32,
        ),
        children: inventory.isLoading || user == null
            ? const [_ProfileSkeleton()]
            : _buildContent(user, inventory),
      ),
    );
  }

  List<Widget> _buildContent(UserModel user, InventoryController inventory) {
    final cs = Theme.of(context).colorScheme;
    final prefs = context.watch<AppPreferences>();
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: cs.primary.withValues(alpha: 0.14),
                child: Text(
                  user.initials,
                  style: AppTextStyles.headline.copyWith(color: cs.primary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: AppTextStyles.title),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: AppTextStyles.caption.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        user.accountType,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.onTintOf(context, AppColors.blue),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit profile',
                onPressed: () => showEditProfileSheet(context),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _MiniStat(
              label: 'Items used up',
              value: '${inventory.countByStatus(FoodStatus.consumed)}',
              icon: Icons.task_alt_rounded,
              color: AppColors.emerald,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MiniStat(
              label: 'Items wasted',
              value: '${inventory.countByStatus(FoodStatus.discarded)}',
              icon: Icons.delete_outline_rounded,
              color: AppColors.crimson,
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      const _GroupLabel('Preferences'),
      Card(
        child: Column(
          children: [
            // A 3-way choice: an on/off switch read "off" while the app was
            // dark because it followed the phone, and tapping seemed to do
            // nothing.
            ReminderSettingTile(
              icon: Icons.dark_mode_outlined,
              title: 'Theme',
              trailingText: _themeLabel(prefs.themeMode),
              onTap: _pickTheme,
            ),
            const Divider(indent: 68),
            ReminderSettingTile(
              icon: prefs.defaultStorage.icon,
              title: 'Default storage',
              subtitle: 'Pre-selected when adding food',
              trailingText: prefs.defaultStorage.label,
              onTap: _pickDefaultStorage,
            ),
            const Divider(indent: 68),
            ReminderSettingTile(
              icon: Icons.notifications_none_rounded,
              title: 'Reminder settings',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(initialTab: 1),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const _GroupLabel('Account'),
      Card(
        child: Column(
          children: [
            ReminderSettingTile(
              icon: Icons.lock_outline_rounded,
              title: 'Change password',
              onTap: _changePassword,
            ),
            const Divider(indent: 68),
            ReminderSettingTile(
              icon: Icons.download_outlined,
              title: 'Export inventory',
              subtitle: 'Share a spreadsheet (CSV) of your items',
              onTap: _exportInventory,
            ),
            const Divider(indent: 68),
            ReminderSettingTile(
              icon: Icons.info_outline_rounded,
              title: 'About',
              trailingText: 'v1.0.0',
              onTap: () => showAboutDialog(
                context: context,
                applicationName: AppConstants.appName,
                applicationVersion: '1.0.0',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      CustomButton(
        label: 'Log out',
        icon: Icons.logout_rounded,
        variant: CustomButtonVariant.secondary,
        onPressed: _logout,
      ),
    ];
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.label.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                color: AppColors.onTintOf(context, color),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: AppTextStyles.headline),
                  Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SkeletonLoader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 104, radius: AppConstants.radiusMd),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 68, radius: 16)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 68, radius: 16)),
            ],
          ),
          SizedBox(height: 28),
          SkeletonBox(width: 90, height: 10, radius: 4),
          SizedBox(height: 12),
          SkeletonBox(height: 190, radius: AppConstants.radiusMd),
          SizedBox(height: 28),
          SkeletonBox(width: 70, height: 10, radius: 4),
          SizedBox(height: 12),
          SkeletonBox(height: 190, radius: AppConstants.radiusMd),
        ],
      ),
    );
  }
}
