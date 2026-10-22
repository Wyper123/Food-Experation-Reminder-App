import 'package:food_expiration_reminder/core/state/scoped_controller.dart';
import 'package:food_expiration_reminder/data/local/daos/household_dao.dart';
import 'package:food_expiration_reminder/data/models/household_model.dart';

/// Scoped to the signed-in user (not the household), since it answers
/// "which household am I in?". Joining/leaving lives on SessionController
/// because it changes the session's household.
class HouseholdController extends ScopedController<HouseholdModel?> {
  HouseholdController(this._dao);

  final HouseholdDao _dao;

  @override
  Future<HouseholdModel?> fetch(String scopeId) => _dao.getForUser(scopeId);

  HouseholdModel? get household => data;

  String? _householdId;

  /// Binds to the user, and also reloads when the same user switches
  /// household (joining or leaving), which [bind] alone would not notice.
  void bindSession(String? userId, String? householdId) {
    final switched = userId != null &&
        userId == scopeId &&
        householdId != _householdId;
    _householdId = householdId;
    bind(userId);
    if (switched) refresh();
  }

  Future<void> rename(String name) async {
    await _dao.rename(household!.id, name);
    await refresh();
  }

  /// Old codes stop working immediately.
  Future<void> regenerateInviteCode() async {
    await _dao.setInviteCode(household!.id, HouseholdModel.newInviteCode());
    await refresh();
  }

  Future<void> setRole(HouseholdMember member, HouseholdRole role) async {
    await _dao.updateMemberRole(household!.id, member.id, role);
    await refresh();
  }

  /// The removed member gets a new personal household of their own.
  Future<void> removeMember(HouseholdMember member) async {
    final fresh = HouseholdModel.personal(member.name);
    await _dao.moveMember(
      userId: member.id,
      fromHouseholdId: household!.id,
      toHouseholdId: fresh.id,
      role: HouseholdRole.admin,
      newHousehold: fresh,
    );
    await refresh();
  }
}
