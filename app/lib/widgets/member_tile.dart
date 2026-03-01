import 'package:flutter/material.dart';

import '../config/theme.dart';

/// A family member row — avatar, name, and role label.
class MemberTile extends StatelessWidget {
  final String displayName;
  final String role;
  final String? avatarUrl;
  final VoidCallback? onTap;

  const MemberTile({
    super.key,
    required this.displayName,
    required this.role,
    this.avatarUrl,
    this.onTap,
  });

  String get _initials {
    final parts = displayName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: BudgetlyTheme.primary,
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
        child: avatarUrl == null
            ? Text(
                _initials,
                style: const TextStyle(
                  color: BudgetlyTheme.textMain,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              )
            : null,
      ),
      title: Text(displayName, style: Theme.of(context).textTheme.titleSmall),
      subtitle: Text(role, style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(
        Icons.chevron_right,
        color: BudgetlyTheme.textMuted,
        size: 20,
      ),
    );
  }
}
