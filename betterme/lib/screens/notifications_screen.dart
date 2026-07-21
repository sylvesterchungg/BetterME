import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final notifs = provider.notifications;
        final unread = provider.unreadNotificationCount;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Notifications',
                style: TextStyle(fontWeight: FontWeight.w600)),
            actions: [
              TextButton(
                onPressed: unread == 0
                    ? null
                    : () => provider.markAllNotificationsRead(),
                child: Text(
                  unread == 0 ? 'All read' : 'Mark all as read',
                  style: TextStyle(
                    color: unread == 0 ? AppTheme.outline : AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          body: notifs.isEmpty
              ? _buildEmpty()
              : _buildList(context, provider, notifs),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_off_outlined,
                color: AppTheme.outline, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('No notifications yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurface)),
          const SizedBox(height: 4),
          const Text("You're all caught up!",
              style:
                  TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildList(
      BuildContext context, AppProvider provider, List<AppNotification> notifs) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final today = notifs
        .where((n) => !n.createdAt.isBefore(todayStart))
        .toList();
    final earlier = notifs
        .where((n) => n.createdAt.isBefore(todayStart))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (today.isNotEmpty) ...[
          _sectionLabel('Today'),
          const SizedBox(height: 12),
          ...today.map((n) => _NotifCard(notif: n, provider: provider)),
        ],
        if (earlier.isNotEmpty) ...[
          if (today.isNotEmpty) const SizedBox(height: 24),
          _sectionLabel('Earlier'),
          const SizedBox(height: 12),
          ...earlier.map((n) => _NotifCard(notif: n, provider: provider)),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurfaceVariant));
  }
}

class _NotifCard extends StatelessWidget {
  final AppNotification notif;
  final AppProvider provider;

  const _NotifCard({required this.notif, required this.provider});

  @override
  Widget build(BuildContext context) {
    final info = _notifInfo(notif.type);

    return GestureDetector(
      onTap: notif.isRead
          ? null
          : () => provider.markNotificationRead(notif.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderDefault),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: info.bgColor, shape: BoxShape.circle),
              child: Icon(info.icon, color: info.fgColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(notif.title,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ),
                      if (!notif.isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(notif.body,
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text(_formatTime(notif.createdAt),
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.outline)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _NotifStyle _notifInfo(String type) {
    switch (type) {
      case 'streak_milestone':
        return _NotifStyle(
          icon: Icons.local_fire_department,
          bgColor: AppTheme.primaryFixed,
          fgColor: AppTheme.primary,
        );
      case 'friend_accepted':
        return _NotifStyle(
          icon: Icons.people,
          bgColor: AppTheme.secondaryFixed,
          fgColor: AppTheme.secondary,
        );
      case 'friend_request':
        return _NotifStyle(
          icon: Icons.person_add,
          bgColor: AppTheme.tertiaryFixed,
          fgColor: AppTheme.tertiary,
        );
      default:
        return _NotifStyle(
          icon: Icons.notifications_outlined,
          bgColor: AppTheme.surfaceContainerHigh,
          fgColor: AppTheme.outline,
        );
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday, ${DateFormat('h:mm a').format(dt)}';
    return DateFormat('MMM d, h:mm a').format(dt);
  }
}

class _NotifStyle {
  final IconData icon;
  final Color bgColor;
  final Color fgColor;
  const _NotifStyle(
      {required this.icon, required this.bgColor, required this.fgColor});
}
