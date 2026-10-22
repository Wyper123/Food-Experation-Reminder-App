import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_expiration_reminder/core/constants/app_colors.dart';
import 'package:food_expiration_reminder/core/constants/app_constants.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/widgets/confirm_sheet.dart';
import 'package:food_expiration_reminder/core/widgets/custom_button.dart';
import 'package:food_expiration_reminder/core/widgets/custom_text_field.dart';
import 'package:food_expiration_reminder/core/widgets/empty_state_widget.dart';
import 'package:food_expiration_reminder/core/widgets/skeleton_loader.dart';
import 'package:food_expiration_reminder/data/models/household_model.dart';
import 'package:food_expiration_reminder/features/auth/presentation/controllers/session_controller.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/controllers/inventory_controller.dart';
import 'package:food_expiration_reminder/features/household/presentation/controllers/household_controller.dart';
import 'package:food_expiration_reminder/features/household/presentation/widgets/member_avatar_chip.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

/// Shared inventory: invite code + member list (Feature 12).
class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  HouseholdController get _controller => context.read<HouseholdController>();

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) _toast('Invite code copied');
  }

  Future<void> _shareCode(HouseholdModel h) => SharePlus.instance.share(
        ShareParams(
          subject: 'Join my household on ${AppConstants.appName}',
          text: 'Join "${h.name}" on ${AppConstants.appName} so we can '
              'share one food inventory. Use invite code ${h.inviteCode} '
              'when you sign up, or in the Household tab.',
        ),
      );

  /// Warns before a sole member's household (and its food) is deleted.
  Future<bool> _confirmLeaving(HouseholdModel h, {required String action}) {
    if (h.members.length > 1) return Future.value(true);
    final count = context.read<InventoryController>().items.length;
    return showConfirmSheet(
      context,
      title: 'Delete ${h.name}?',
      message: "You're its only member, so $action deletes it"
          '${count == 0 ? '' : ' along with its $count food '
              '${count == 1 ? 'item' : 'items'}'}. This cannot be undone.',
      confirmLabel: 'Delete and continue',
      destructive: true,
    );
  }

  Future<void> _showJoinSheet(HouseholdModel? current) async {
    final joined = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _JoinSheet(
        onJoin: (code) async {
          if (current != null &&
              !await _confirmLeaving(current, action: 'joining another')) {
            return null;
          }
          if (!mounted) return null;
          await context.read<SessionController>().joinHousehold(code);
          return true;
        },
      ),
    );
    if (joined == true && mounted) {
      _toast('Welcome to ${_controller.household?.name ?? 'your household'}');
    }
  }

  Future<void> _leave(HouseholdModel h) async {
    final ok = await showConfirmSheet(
      context,
      title: 'Leave ${h.name}?',
      message: "You'll get your own new, empty kitchen. The shared food "
          'stays with the other members.',
      confirmLabel: 'Leave household',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await context.read<SessionController>().leaveHousehold();
    if (mounted) _toast('You left ${h.name}');
  }

  Future<void> _rename(HouseholdModel h) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: h.name),
    );
    if (name != null && name.trim().isNotEmpty && name.trim() != h.name) {
      await _controller.rename(name);
    }
  }

  Future<void> _newCode() async {
    final ok = await showConfirmSheet(
      context,
      title: 'Create a new invite code?',
      message: 'The current code stops working right away. Members who '
          'already joined stay in the household.',
      confirmLabel: 'Create new code',
    );
    if (!ok) return;
    await _controller.regenerateInviteCode();
    if (mounted) _toast('New invite code created');
  }

  Future<void> _setRole(HouseholdMember m, HouseholdRole role) async {
    await _controller.setRole(m, role);
    if (mounted) _toast('${m.name} is now ${role.label}');
  }

  Future<void> _remove(HouseholdMember m) async {
    final ok = await showConfirmSheet(
      context,
      title: 'Remove ${m.name}?',
      message: "They'll lose access to this household's food and get their "
          'own new, empty kitchen.',
      confirmLabel: 'Remove member',
      destructive: true,
    );
    if (!ok) return;
    await _controller.removeMember(m);
    if (mounted) _toast('${m.name} was removed');
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HouseholdController>();
    final isLoading = controller.isLoading;
    final household = controller.household;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Household'),
        actions: [
          IconButton(
            tooltip: 'Join another household',
            onPressed: isLoading ? null : () => _showJoinSheet(household),
            icon: const Icon(Icons.group_add_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.pagePadding,
            4,
            AppConstants.pagePadding,
            32,
          ),
          children: isLoading
              ? const [_HouseholdSkeleton()]
              : household == null
                  ? [
                      EmptyStateWidget(
                        icon: Icons.groups_outlined,
                        title: 'No household yet',
                        message: 'Join one with an invite code to share '
                            'your inventory.',
                        actionLabel: 'Join household',
                        onAction: () => _showJoinSheet(null),
                      ),
                    ]
                  : _buildContent(household),
        ),
      ),
    );
  }

  List<Widget> _buildContent(HouseholdModel household) {
    final cs = Theme.of(context).colorScheme;
    final canManage = household.canManage;
    return [
      _InviteCard(
        household: household,
        onCopy: () => _copyCode(household.inviteCode),
        onShare: () => _shareCode(household),
        onRename: canManage ? () => _rename(household) : null,
        onNewCode: canManage ? _newCode : null,
      ),
      const SizedBox(height: 28),
      Row(
        children: [
          Text('Members', style: AppTextStyles.headline),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${household.members.length}',
              style: AppTextStyles.label.copyWith(color: cs.primary),
            ),
          ),
        ],
      ),
      if (household.members.length == 1) ...[
        const SizedBox(height: 6),
        Text(
          'Share your invite code so others can join and use the same '
          'inventory and grocery list.',
          style: AppTextStyles.caption.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
      const SizedBox(height: 12),
      Card(
        child: Column(
          children: [
            for (var i = 0; i < household.members.length; i++) ...[
              if (i > 0) const Divider(indent: 78),
              _MemberRow(
                member: household.members[i],
                // Admins manage everyone but themselves.
                onSetRole: canManage && !household.members[i].isCurrentUser
                    ? (role) => _setRole(household.members[i], role)
                    : null,
                onRemove: canManage && !household.members[i].isCurrentUser
                    ? () => _remove(household.members[i])
                    : null,
              ),
            ],
          ],
        ),
      ),
      // A sole member has nothing to leave; joining another is the way out.
      if (household.members.length > 1) ...[
        const SizedBox(height: 24),
        CustomButton(
          label: 'Leave household',
          icon: Icons.logout_rounded,
          variant: CustomButtonVariant.text,
          onPressed: () => _leave(household),
        ),
      ],
    ];
  }
}

/// Code entry. [onJoin] returns true on success, null if the user backed
/// out of a confirmation, or throws an [AuthException] to show.
class _JoinSheet extends StatefulWidget {
  const _JoinSheet({required this.onJoin});

  final Future<bool?> Function(String code) onJoin;

  @override
  State<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends State<_JoinSheet> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.text.trim().isEmpty) {
      setState(() => _error = 'Enter an invite code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await widget.onJoin(_code.text);
      if (ok == true && mounted) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Join another household', style: AppTextStyles.headline),
          const SizedBox(height: 6),
          Text(
            "Enter the invite code shared with you. You'll leave your "
            'current household.',
            style: AppTextStyles.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (_) => _submit(),
            decoration: CustomTextField.decoration(
              context,
              label: 'Invite code',
              hint: 'FRESH-XXXXXX',
              prefixIcon: Icons.vpn_key_outlined,
            ).copyWith(errorText: _error),
          ),
          const SizedBox(height: 16),
          CustomButton(
            label: 'Join household',
            isLoading: _busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename household'),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: CustomTextField.decoration(context, label: 'Name'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_name.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

enum _InviteAction { rename, newCode }

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.household,
    required this.onCopy,
    required this.onShare,
    this.onRename,
    this.onNewCode,
  });

  final HouseholdModel household;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  /// Admin-only; null hides the option.
  final VoidCallback? onRename;
  final VoidCallback? onNewCode;

  @override
  Widget build(BuildContext context) {
    final manage = onRename != null || onNewCode != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        gradient: const LinearGradient(
          colors: AppColors.brandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.home_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  household.name,
                  style: AppTextStyles.title.copyWith(color: Colors.white),
                ),
              ),
              if (manage)
                PopupMenuButton<_InviteAction>(
                  tooltip: 'Household options',
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white,
                  ),
                  onSelected: (a) => switch (a) {
                    _InviteAction.rename => onRename?.call(),
                    _InviteAction.newCode => onNewCode?.call(),
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _InviteAction.rename,
                      child: Text('Rename household'),
                    ),
                    PopupMenuItem(
                      value: _InviteAction.newCode,
                      child: Text('Create new invite code'),
                    ),
                  ],
                )
              else
                const SizedBox(height: 48),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              'Everyone here shares one inventory and grocery list.',
              style: AppTextStyles.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'INVITE CODE',
            style: AppTextStyles.label.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      household.inviteCode,
                      style: AppTextStyles.headline.copyWith(
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy code',
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, color: Colors.white),
                ),
                IconButton.filled(
                  tooltip: 'Share invite',
                  onPressed: onShare,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.emeraldDark,
                  ),
                  icon: const Icon(Icons.share_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Menu value for removal. (A null value would read as "menu dismissed".)
enum _MemberAction { remove }

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, this.onSetRole, this.onRemove});

  final HouseholdMember member;
  final ValueChanged<HouseholdRole>? onSetRole;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAdmin = member.role == HouseholdRole.admin;
    final manageable = onSetRole != null || onRemove != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      child: Row(
        children: [
          MemberAvatarChip(member: member),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.isCurrentUser ? '${member.name} (You)' : member.name,
                  style: AppTextStyles.subtitle,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      MemberAvatarChip.roleIcon(member.role),
                      size: 13,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      member.role.label,
                      style: AppTextStyles.caption.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isAdmin)
            Container(
              margin: EdgeInsets.only(right: manageable ? 0 : 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Admin',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.onTintOf(context, AppColors.emerald),
                ),
              ),
            ),
          if (manageable)
            PopupMenuButton<Object>(
              tooltip: 'Member options',
              icon: Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant),
              onSelected: (choice) => choice is HouseholdRole
                  ? onSetRole?.call(choice)
                  : onRemove?.call(),
              itemBuilder: (_) => [
                for (final r in HouseholdRole.values)
                  if (r != member.role && onSetRole != null)
                    PopupMenuItem(
                      value: r,
                      child: Text('Make ${r.label.toLowerCase()}'),
                    ),
                if (onRemove != null) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: _MemberAction.remove,
                    child: Text(
                      'Remove from household',
                      style: TextStyle(color: cs.error),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _HouseholdSkeleton extends StatelessWidget {
  const _HouseholdSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(height: 196, radius: AppConstants.radiusLg),
          const SizedBox(height: 28),
          const SkeletonBox(width: 120, height: 20, radius: 6),
          const SizedBox(height: 16),
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  SkeletonCircle(size: 48),
                  SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 130, height: 13, radius: 6),
                      SizedBox(height: 8),
                      SkeletonBox(width: 80, height: 10, radius: 5),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
