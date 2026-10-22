import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_colors.dart';
import 'package:food_expiration_reminder/core/constants/app_constants.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/utils/date_formatter.dart';
import 'package:food_expiration_reminder/core/widgets/empty_state_widget.dart';
import 'package:food_expiration_reminder/core/widgets/skeleton_loader.dart';
import 'package:food_expiration_reminder/data/local/app_preferences.dart';
import 'package:food_expiration_reminder/data/models/notification_model.dart';
import 'package:food_expiration_reminder/data/models/reminder_settings.dart';
import 'package:food_expiration_reminder/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:food_expiration_reminder/features/notifications/presentation/widgets/reminder_setting_tile.dart';
import 'package:food_expiration_reminder/features/notifications/reminders/reminder_scheduler.dart';
import 'package:provider/provider.dart';

/// Expiration reminders inbox + reminder preferences (Feature 9).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.initialTab = 0});

  /// 0 = Alerts, 1 = Reminder settings.
  final int initialTab;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final AppPreferences _prefs = context.read<AppPreferences>();
  late final ReminderScheduler _scheduler = context.read<ReminderScheduler>();
  late Future<bool> _permitted = _scheduler.isPermitted();

  ReminderSettings get _settings => _prefs.reminderSettings;

  Future<void> _save(ReminderSettings s) => _prefs.setReminderSettings(s);

  Future<void> _allowNotifications() async {
    await _scheduler.requestPermission();
    setState(() => _permitted = _scheduler.isPermitted());
  }

  Future<void> _sendTest() async {
    final messenger = ScaffoldMessenger.of(context);
    await _scheduler.showTest();
    messenger.showSnackBar(
      const SnackBar(content: Text('Test notification sent')),
    );
  }

  static String _daysLabel(int d) => switch (d) {
        0 => 'On the day only',
        1 => '1 day before',
        _ => '$d days before',
      };

  Future<void> _pickDaysBefore() async {
    final current = _settings.daysBefore;
    final picked = await showModalBottomSheet<int>(
      context: context,
      // Six options can exceed a short screen's sheet height.
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child:
                    Text('Remind me before expiry', style: AppTextStyles.title),
              ),
              for (final d in const [0, 1, 2, 3, 5, 7])
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  title: Text(_daysLabel(d)),
                  trailing: d == current
                      ? Icon(
                          Icons.check_rounded,
                          color: Theme.of(ctx).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(ctx).pop(d),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (picked != null) await _save(_settings.copyWith(daysBefore: picked));
  }

  Future<void> _pickTime() async {
    final s = _settings;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.hour, minute: s.minute),
    );
    if (picked != null) {
      await _save(s.copyWith(hour: picked.hour, minute: picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inbox = context.watch<NotificationsController>();
    final unread = inbox.unreadCount;
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: [
            if (!inbox.isLoading && unread > 0)
              TextButton(
                onPressed: inbox.markAllRead,
                child: const Text('Mark all read'),
              ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: unread > 0 ? 'Alerts ($unread)' : 'Alerts'),
              const Tab(text: 'Reminder settings'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildInbox(inbox),
            _buildSettings(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInbox(NotificationsController inbox) {
    if (inbox.isLoading) {
      return SkeletonLoader(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          itemCount: 6,
          separatorBuilder: (_, _) => const SizedBox(height: 18),
          itemBuilder: (_, _) => const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 42, height: 42, radius: 12),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 190, height: 13, radius: 6),
                    SizedBox(height: 8),
                    SkeletonBox(height: 11, radius: 6),
                    SizedBox(height: 6),
                    SkeletonBox(width: 60, height: 10, radius: 5),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    final items = inbox.items;
    if (items.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.notifications_off_outlined,
        title: 'All caught up',
        message: 'Expiration reminders will show up here.',
      );
    }
    return RefreshIndicator(
      onRefresh: inbox.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        itemBuilder: (_, i) => _NotificationTile(
          item: items[i],
          onDismissed: () => inbox.delete(items[i].id),
        ),
      ),
    );
  }

  Widget _buildSettings(BuildContext context) {
    // Rebuild when settings change (the screen itself only reads them).
    final settings = context.watch<AppPreferences>().reminderSettings;
    final on = settings.enabled;
    return ListView(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      children: [
        FutureBuilder<bool>(
          future: _permitted,
          builder: (context, snap) => snap.data == false
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _PermissionBanner(onAllow: _allowNotifications),
                )
              : const SizedBox.shrink(),
        ),
        Card(
          child: ReminderSettingTile(
            icon: Icons.notifications_active_outlined,
            title: 'Expiration reminders',
            subtitle: 'Phone notifications before food goes bad',
            value: on,
            onChanged: (v) async {
              await _save(settings.copyWith(enabled: v));
              if (v) await _allowNotifications();
            },
          ),
        ),
        const SizedBox(height: 20),
        _GroupLabel('Timing'),
        Card(
          child: Column(
            children: [
              ReminderSettingTile(
                icon: Icons.hourglass_bottom_rounded,
                title: 'Remind me',
                subtitle: 'Plus a reminder on the expiration day',
                trailingText: _daysLabel(settings.daysBefore),
                onTap: _pickDaysBefore,
                enabled: on,
              ),
              const Divider(indent: 68),
              ReminderSettingTile(
                icon: Icons.schedule_rounded,
                title: 'Reminder time',
                trailingText: TimeOfDay(
                  hour: settings.hour,
                  minute: settings.minute,
                ).format(context),
                onTap: _pickTime,
                enabled: on,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _GroupLabel('Alert types'),
        Card(
          child: Column(
            children: [
              ReminderSettingTile(
                icon: Icons.error_outline_rounded,
                title: 'Expired items',
                subtitle: 'The day after something expires',
                value: settings.expiredAlerts,
                onChanged: (v) => _save(settings.copyWith(expiredAlerts: v)),
                enabled: on,
              ),
              const Divider(indent: 68),
              ReminderSettingTile(
                icon: Icons.send_outlined,
                title: 'Send a test notification',
                onTap: _sendTest,
                enabled: on,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onAllow});

  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_off_outlined, color: cs.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Notifications are blocked for this app, so reminders '
              'cannot appear.',
              style: AppTextStyles.body.copyWith(color: cs.onErrorContainer),
            ),
          ),
          TextButton(onPressed: onAllow, child: const Text('Allow')),
        ],
      ),
    );
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

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onDismissed});

  final NotificationModel item;
  final VoidCallback onDismissed;

  (IconData, Color) get _visual => switch (item.type) {
        NotificationType.expiringSoon => (
            Icons.schedule_rounded,
            AppColors.amber
          ),
        NotificationType.expired => (
            Icons.error_outline_rounded,
            AppColors.crimson
          ),
        NotificationType.grocery => (
            Icons.shopping_basket_outlined,
            AppColors.blue
          ),
        NotificationType.household => (
            Icons.groups_outlined,
            AppColors.emerald
          ),
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, color) = _visual;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppColors.crimson.withValues(alpha: 0.12),
        child: Icon(
          Icons.delete_outline_rounded,
          color: AppColors.onTintOf(context, AppColors.crimson),
        ),
      ),
      child: Container(
        color: item.isRead ? null : cs.primary.withValues(alpha: 0.05),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.pagePadding,
          vertical: 14,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppColors.onTintOf(context, color),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTextStyles.subtitle.copyWith(
                      fontWeight:
                          item.isRead ? FontWeight.w600 : FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.body,
                    style: AppTextStyles.body.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormatter.relativeTime(item.createdAt),
                    style: AppTextStyles.caption.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!item.isRead)
              Container(
                margin: const EdgeInsets.only(top: 6, left: 8),
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
