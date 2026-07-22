import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import 'personal_info_screen.dart';

/// Full-screen wrapper around [ProfileTab] with a back-enabled app bar.
///
/// Every tab reaches Profile/Settings by pushing this route, so the header
/// chrome (back button, title, divider) lives in one place instead of being
/// duplicated at each entry point.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// Opens the Profile/Settings screen from anywhere in the app.
  static Future<void> open(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLow,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profile',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.borderDefault),
        ),
      ),
      body: const ProfileTab(),
    );
  }
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndUploadImage(AppProvider provider) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Uploading photo...')));
      }
      try {
        await provider.uploadProfilePhoto(File(image.path));
        if (mounted) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Photo updated!')));
          }
        }
      } catch (e) {
        if (mounted) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Failed to upload: $e')));
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        if (provider.currentUser == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildProfileHeader(context, provider),
                const SizedBox(height: 24),
                _buildStatsRow(provider),
                const SizedBox(height: 32),
                _buildSettingsGrid(context, provider),
                const SizedBox(height: 32),
                _buildLogoutSection(provider),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(BuildContext context, AppProvider provider) {
    final user = provider.currentUser!;

    return Column(
      children: [
        GestureDetector(
          onTap: () => _pickAndUploadImage(provider),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  backgroundColor: AppTheme.borderDefault,
                  backgroundImage: user.avatarUrl.isNotEmpty
                      ? NetworkImage(user.avatarUrl)
                      : null,
                  onBackgroundImageError:
                      user.avatarUrl.isNotEmpty ? (_, _) {} : null,
                  child: user.avatarUrl.isEmpty
                      ? Text(
                          user.username.isNotEmpty
                              ? user.username[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.name.isNotEmpty ? user.name : user.username,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        if (user.name.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            '@${user.username}',
            style: const TextStyle(fontSize: 14, color: AppTheme.outline),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          ' ${user.streak} Day Streak'
          '${provider.myLeaderboardRank > 0 ? '  ·  Rank #${provider.myLeaderboardRank}' : ''}',
          style: const TextStyle(fontSize: 14, color: AppTheme.outline),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => PersonalInfoScreen.open(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text(
            'Edit Profile',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(AppProvider provider) {
    final avgMood = provider.averageMood;
    final avgSleep = provider.averageSleep;
    final completion = provider.taskCompletionRate;

    return Row(
      children: [
        Expanded(child: _buildStatCard('Avg Mood', avgMood > 0 ? avgMood.toStringAsFixed(1) : '—', Icons.mood, AppTheme.primary)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Avg Sleep', avgSleep > 0 ? '${avgSleep.toStringAsFixed(1)}h' : '—', Icons.bedtime, AppTheme.tertiary)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Tasks Done', '${(completion * 100).toInt()}%', Icons.check_circle_outline, AppTheme.secondary)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDefault),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.outline)),
        ],
      ),
    );
  }

  Widget _buildSettingsGrid(BuildContext context, AppProvider provider) {
    return Column(
      children: [
        _buildAccountSection(provider),
        const SizedBox(height: 16),
        _buildNotificationsSection(context, provider),
        const SizedBox(height: 16),
        _buildSupportSection(),
      ],
    );
  }

  Widget _buildAccountSection(AppProvider provider) {
    return _buildCard(
      title: 'Account',
      icon: Icons.account_circle,
      children: [
        _buildListTile(
          'Personal Info',
          Icons.chevron_right,
          onTap: () => PersonalInfoScreen.open(context),
        ),
      ],
    );
  }

  Widget _buildNotificationsSection(BuildContext context, AppProvider provider) {
    final user = provider.currentUser!;
    return _buildCard(
      title: 'Notifications',
      icon: Icons.notifications_active,
      children: [
        _buildSwitchTile(
          'Task Reminders',
          'OS alerts for tasks with a set reminder time',
          user.notificationsEnabled,
          (v) => provider.updateNotificationPrefs(notificationsEnabled: v),
        ),
        _buildSwitchTile(
          'Friend Activity',
          'When someone accepts your friend request',
          user.friendActivityNotif,
          (v) => provider.updateNotificationPrefs(friendActivityNotif: v),
        ),
        _buildSwitchTile(
          'Streak Alerts',
          'Celebrate 7, 14, 30, 60 and 100-day milestones',
          user.streakAlertsNotif,
          (v) => provider.updateNotificationPrefs(streakAlertsNotif: v),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: const Border(
              left: BorderSide(color: AppTheme.primary, width: 4),
            ),
          ),
          child: const Text(
            '"You\'ve been most consistent when reminders are set for 8:00 AM."',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Color(0xFF2F2EBE),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildSupportSection() {
    return _buildCard(
      title: 'Support',
      icon: Icons.help,
      children: [
        _buildListTile('Help Center', Icons.launch),
        _buildListTile('Contact Us', Icons.mail),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildListTile(
    String title,
    IconData trailingIcon, {
    VoidCallback? onTap,
    String? value,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            if (value != null)
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(width: 6),
            Icon(trailingIcon, color: AppTheme.outline),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppTheme.outline),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutSection(AppProvider provider) {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: () {
            // Profile/Settings is a route pushed on top of AuthGate. Signing out
            // clears currentUser, but AuthGate's swap to LoginScreen happens on
            // the root route *underneath* this one — leaving this screen's
            // null-guard spinner on top forever. Pop back to the root first so
            // the LoginScreen AuthGate rebuilds is the visible route.
            Navigator.of(context).popUntil((route) => route.isFirst);
            provider.logout();
          },
          icon: const Icon(Icons.logout, color: AppTheme.error),
          label: const Text(
            'Logout',
            style: TextStyle(
              color: AppTheme.error,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.error),
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Version 2.4.1 (Stable)',
          style: TextStyle(fontSize: 12, color: AppTheme.outline),
        ),
      ],
    );
  }
}
