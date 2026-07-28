import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models/models.dart';
import '../utils/image_helpers.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile_tab.dart';

/// Shared page header used across tabs: avatar (or custom leading) + title/date + notification bell.
class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final User? user;

  /// Overrides the user avatar with any widget (e.g. a brand icon).
  final Widget? leadingWidget;

  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.user,
    this.leadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = subtitle ?? DateFormat('MMMM d, yyyy').format(DateTime.now());

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            // Tapping the leading element opens Profile/Settings — consistent
            // entry point available from every tab that uses this header.
            GestureDetector(
              onTap: () => ProfileScreen.open(context),
              child: leadingWidget ?? _buildAvatar(),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 12, color: AppTheme.outline),
                ),
              ],
            ),
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.borderDefault),
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: AppTheme.onSurfaceVariant,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    final avatarUrl = user?.avatarUrl;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.outlineVariant, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: storedImage(
          avatarUrl ?? '',
          fit: BoxFit.cover,
          fallback: const Icon(Icons.person, color: AppTheme.outline),
        ),
      ),
    );
  }
}
