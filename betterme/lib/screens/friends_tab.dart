import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../models/models.dart';
import '../widgets/app_page_header.dart';

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final TextEditingController _searchController = TextEditingController();

  void _handleAddFriend(AppProvider provider) async {
    final username = _searchController.text.trim();
    if (username.isEmpty) return;

    try {
      await provider.addFriend(username);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Added $username as a friend!')));
      }
      _searchController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not find user $username.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppPageHeader(
                  title: 'Community',
                  user: provider.currentUser,
                  leadingWidget: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bubble_chart, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSearchAndAdd(provider),
                const SizedBox(height: 24),
                _buildFriendCircles(provider),
                const SizedBox(height: 24),
                _buildLeaderboardAndActivity(context, provider),
                const SizedBox(height: 24),
                _buildRecommendedCommunities(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchAndAdd(AppProvider provider) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderDefault),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppTheme.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Add friend by username...',
                      hintStyle: TextStyle(
                        color: AppTheme.outline,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => _handleAddFriend(provider),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendCircles(AppProvider provider) {
    final friends = provider.friends;

    // Get today's mood log if any
    LogEntry? todayLog;
    if (provider.logs.isNotEmpty) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      try {
        todayLog = provider.logs.firstWhere((log) {
          final logDate = DateTime(log.date.year, log.date.month, log.date.day);
          return logDate.isAtSameMomentAs(today);
        });
      } catch (e) {
        todayLog = null;
      }
    }

    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Friend Circles',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              'View All',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildMyMoodItem(todayLog),
              ...friends.map(
                (f) => _buildStoryItem(
                  f.username,
                  f.avatarUrl,
                  false,
                  AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyMoodItem(LogEntry? log) {
    IconData icon = Icons.add;
    Color bgIconColor = Colors.white;
    Color fgIconColor = AppTheme.primary;

    if (log != null) {
      if (log.moodScore >= 8) {
        icon = Icons.sentiment_very_satisfied;
        bgIconColor = AppTheme.primaryFixed;
        fgIconColor = AppTheme.primaryContainer;
      } else if (log.moodScore >= 6) {
        icon = Icons.sentiment_satisfied;
        bgIconColor = AppTheme.secondaryFixed;
        fgIconColor = AppTheme.secondary;
      } else if (log.moodScore <= 3) {
        icon = Icons.sentiment_very_dissatisfied;
        bgIconColor = const Color(0xFFFFDAD6);
        fgIconColor = AppTheme.error;
      } else {
        icon = Icons.sentiment_neutral;
        bgIconColor = AppTheme.surfaceContainerHighest;
        fgIconColor = AppTheme.onSurfaceVariant;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.transparent, width: 2),
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryContainer],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bgIconColor,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(icon, color: fgIconColor, size: 32),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'My Mood',
            style: TextStyle(fontSize: 12, color: AppTheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryItem(
    String name,
    String? avatarUrl,
    bool isAdd,
    Color borderColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isAdd ? Colors.transparent : borderColor,
                width: 2,
              ),
              gradient: isAdd
                  ? const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryContainer],
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isAdd ? Colors.white : AppTheme.borderDefault,
                  border: Border.all(color: Colors.white, width: 2),
                  image: (!isAdd && avatarUrl != null)
                      ? DecorationImage(
                          image: NetworkImage(avatarUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: isAdd
                    ? const Icon(Icons.add, color: AppTheme.primary, size: 32)
                    : (avatarUrl == null
                          ? Icon(
                              Icons.person,
                              color: Colors.grey.shade400,
                              size: 32,
                            )
                          : null),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(fontSize: 12, color: AppTheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardAndActivity(
    BuildContext context,
    AppProvider provider,
  ) {
    return Column(
      children: [
        _buildLeaderboardCard(context, provider),
        const SizedBox(height: 24),
        _buildActivityFeed(context, provider),
      ],
    );
  }

  Widget _buildLeaderboardCard(BuildContext context, AppProvider provider) {
    final leaderboard = provider.leaderboard;
    final currentUserId = provider.currentUser?.id;

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
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.leaderboard, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text(
                    'Leaderboard',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Text(
                'Weekly',
                style: TextStyle(fontSize: 12, color: AppTheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (leaderboard.isEmpty)
            const Text(
              'No data available',
              style: TextStyle(color: Colors.grey),
            ),
          ...leaderboard.asMap().entries.map((entry) {
            int idx = entry.key;
            var user = entry.value;
            bool isUser = user.id == currentUserId;
            return _buildLeaderboardRow(
              '${idx + 1}',
              isUser ? 'You (${user.username})' : user.username,
              '${user.streak} Day Streak',
              idx == 0,
              isUser,
              user.avatarUrl,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLeaderboardRow(
    String rank,
    String name,
    String streak,
    bool isFirst,
    bool isUser,
    String avatarUrl,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isUser
            ? AppTheme.primaryFixed.withValues(alpha: 0.4)
            : (isFirst
                  ? AppTheme.secondaryFixed.withValues(alpha: 0.3)
                  : Colors.transparent),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUser
              ? AppTheme.primary.withValues(alpha: 0.2)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              rank,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isFirst
                    ? AppTheme.secondary
                    : (isUser ? AppTheme.primary : AppTheme.outline),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.borderDefault,
            backgroundImage: NetworkImage(avatarUrl),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  streak,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.local_fire_department,
            color: isFirst
                ? AppTheme.secondary
                : (isUser ? AppTheme.primary : AppTheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFeed(BuildContext context, AppProvider provider) {
    // Dynamic activity feed is complex, we'll map friends to basic activity text for now
    final friends = provider.friends;

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
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Friend Activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              Icon(Icons.more_horiz, color: AppTheme.outline),
            ],
          ),
          const SizedBox(height: 16),
          if (friends.isEmpty)
            const Text(
              'Add friends to see their activity!',
              style: TextStyle(color: Colors.grey),
            ),
          ...friends.map((f) {
            return Column(
              children: [
                _buildActivityItem(
                  Icons.celebration,
                  AppTheme.secondaryFixed,
                  AppTheme.secondary,
                  f.username,
                  'reached a ${f.streak}-day streak!',
                  'Recently',
                ),
                const SizedBox(height: 16),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    IconData icon,
    Color bgColor,
    Color iconColor,
    String name,
    String text,
    String time, {
    bool hasButtons = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.onSurface,
                    fontFamily: 'Plus Jakarta Sans',
                  ),
                  children: [
                    TextSpan(
                      text: '$name ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: text),
                  ],
                ),
              ),
              if (hasButtons) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildActivityButton('Congrats! 👏'),
                    const SizedBox(width: 8),
                    _buildActivityButton('Inspiring! ✨'),
                  ],
                ),
              ],
              if (!hasButtons) ...[
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(fontSize: 12, color: AppTheme.outline),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityButton(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildRecommendedCommunities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommended Communities',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCommunityCard(
                'Sleep Seekers',
                '1.2k Members • Active Now',
                AppTheme.primaryContainer,
              ),
              _buildCommunityCard(
                'Daily Gratitude',
                '856 Members • Calm vibes',
                AppTheme.secondaryContainer,
              ),
              _buildCommunityCard(
                'Anxiety Allies',
                '3.4k Members • Safe Space',
                AppTheme.tertiaryContainer,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommunityCard(String title, String subtitle, Color bgColor) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.all(12),
            alignment: Alignment.bottomLeft,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppTheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}
