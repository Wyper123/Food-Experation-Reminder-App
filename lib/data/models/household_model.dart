import 'dart:math';

import 'package:uuid/uuid.dart';

enum HouseholdRole { admin, roommate, familyMember }

extension HouseholdRoleX on HouseholdRole {
  String get label => switch (this) {
        HouseholdRole.admin => 'Admin',
        HouseholdRole.roommate => 'Roommate',
        HouseholdRole.familyMember => 'Family Member',
      };
}

class HouseholdMember {
  const HouseholdMember({
    required this.id,
    required this.name,
    required this.role,
    this.colorIndex = 0,
    this.isCurrentUser = false,
  });

  final String id;
  final String name;
  final HouseholdRole role;
  final int colorIndex;
  final bool isCurrentUser;

  /// Row from `household_members` joined with `users.name`.
  factory HouseholdMember.fromMap(
    Map<String, Object?> map, {
    required String currentUserId,
  }) =>
      HouseholdMember(
        id: map['user_id']! as String,
        name: map['name']! as String,
        role: HouseholdRole.values.byName(map['role']! as String),
        colorIndex: map['color_index']! as int,
        isCurrentUser: map['user_id'] == currentUserId,
      );

  String get initials => name
      .trim()
      .split(' ')
      .where((p) => p.isNotEmpty)
      .map((p) => p[0])
      .take(2)
      .join()
      .toUpperCase();
}

class HouseholdModel {
  const HouseholdModel({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.members,
  });

  final String id;
  final String name;
  final String inviteCode;
  final List<HouseholdMember> members;

  /// A new single-member household for [ownerName], e.g. "Sam's Kitchen".
  factory HouseholdModel.personal(String ownerName) => HouseholdModel(
        id: const Uuid().v4(),
        name: "${ownerName.trim().split(' ').first}'s Kitchen",
        inviteCode: newInviteCode(),
        members: const [],
      );

  /// e.g. FRESH-7KQ2MX. Skips look-alike characters (0/O, 1/I).
  static String newInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    final suffix =
        List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
    return 'FRESH-$suffix';
  }

  HouseholdMember? get currentMember {
    for (final m in members) {
      if (m.isCurrentUser) return m;
    }
    return null;
  }

  /// Admins may rename, re-key and manage members.
  bool get canManage => currentMember?.role == HouseholdRole.admin;

  factory HouseholdModel.fromMap(
    Map<String, Object?> map, {
    required List<HouseholdMember> members,
  }) =>
      HouseholdModel(
        id: map['id']! as String,
        name: map['name']! as String,
        inviteCode: map['invite_code']! as String,
        members: members,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'invite_code': inviteCode,
      };

  /// Demo household inserted by DevSeeder on first launch.
  static const HouseholdModel mock = HouseholdModel(
    id: 'H-4B27',
    name: 'Dorm 4B Household',
    inviteCode: 'FRESH-4B27',
    members: [
      HouseholdMember(
        id: 'm1',
        name: 'Alex Rivera',
        role: HouseholdRole.admin,
        colorIndex: 0,
        isCurrentUser: true,
      ),
      HouseholdMember(
        id: 'm2',
        name: 'Jamie Cruz',
        role: HouseholdRole.roommate,
        colorIndex: 1,
      ),
      HouseholdMember(
        id: 'm3',
        name: 'Mara Santos',
        role: HouseholdRole.roommate,
        colorIndex: 2,
      ),
      HouseholdMember(
        id: 'm4',
        name: 'Tita Lyn',
        role: HouseholdRole.familyMember,
        colorIndex: 3,
      ),
    ],
  );
}
