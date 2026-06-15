import 'package:flutter/material.dart';
import '../theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _allRead = false;

  void _markAllRead() {
    setState(() {
      _allRead = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _allRead ? null : _markAllRead,
            child: Text(
              _allRead ? 'All read' : 'Mark all as read',
              style: TextStyle(
                color: _allRead ? AppTheme.outline : AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Today', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            _buildNotificationCard(
              context,
              Icons.local_fire_department,
              AppTheme.primaryFixed,
              AppTheme.primary,
              'You reached a 12-day streak!',
              "Consistency is key. You're doing an amazing job staying on track with your goals.",
              '2h ago',
              isUnread: !_allRead,
            ),
            const SizedBox(height: 16),
            _buildNotificationCard(
              context,
              Icons.front_hand,
              AppTheme.secondaryFixed,
              AppTheme.secondary,
              'Maya sent you a High Five',
              'Maya celebrated your recent morning meditation session. High five!',
              '5h ago',
              isUnread: !_allRead,
              extraWidget: Row(
                children: const [
                  CircleAvatar(radius: 12, backgroundColor: Color(0xFFE2E8F0), child: Icon(Icons.person, size: 16, color: Colors.grey)),
                  SizedBox(width: 8),
                  Text('Community Cheer', style: TextStyle(fontSize: 12, color: AppTheme.secondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildNotificationCard(
              context,
              Icons.water_drop,
              AppTheme.surfaceContainerHigh,
              AppTheme.primary,
              'Time for your afternoon hydration reminder',
              "You're 400ml away from your daily target. Take a moment to drink some water.",
              '8h ago',
            ),
            const SizedBox(height: 32),
            const Text('Yesterday', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            _buildNotificationCard(
              context,
              Icons.emoji_events,
              AppTheme.tertiaryFixed,
              AppTheme.tertiary,
              'Jordan started a new challenge',
              'Join "30 Days of Mindfulness" and track your progress alongside Jordan.',
              'Yesterday, 4:30 PM',
              extraWidget: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                ),
                child: const Text('View Challenge', style: TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(height: 16),
            _buildNotificationCard(
              context,
              Icons.update,
              AppTheme.surfaceContainerHigh,
              AppTheme.outline,
              'Weekly Summary Ready',
              'Your health trends from last week have been analyzed. View your insights now.',
              'Yesterday, 9:00 AM',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    IconData icon,
    Color bgIconColor,
    Color fgIconColor,
    String title,
    String description,
    String time, {
    bool isUnread = false,
    Widget? extraWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: bgIconColor, shape: BoxShape.circle),
            child: Icon(icon, color: fgIconColor),
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
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                    if (isUnread) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant)),
                if (extraWidget != null) ...[
                  const SizedBox(height: 8),
                  extraWidget,
                ],
                const SizedBox(height: 8),
                Text(time, style: const TextStyle(fontSize: 12, color: AppTheme.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
