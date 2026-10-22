import 'package:food_expiration_reminder/core/state/scoped_controller.dart';
import 'package:food_expiration_reminder/data/local/daos/notification_dao.dart';
import 'package:food_expiration_reminder/data/models/notification_model.dart';

class NotificationsController
    extends ScopedController<List<NotificationModel>> {
  NotificationsController(this._dao);

  final NotificationDao _dao;

  @override
  Future<List<NotificationModel>> fetch(String scopeId) =>
      _dao.getAll(scopeId);

  List<NotificationModel> get items => data ?? const [];
  int get unreadCount => items.where((n) => !n.isRead).length;

  Future<void> markAllRead() async {
    await _dao.markAllRead(scopeId!);
    data = [for (final n in items) n.copyWith(isRead: true)];
  }

  Future<void> delete(String id) async {
    await _dao.delete(id);
    data = items.where((n) => n.id != id).toList();
  }
}
