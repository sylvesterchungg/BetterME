import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../models/models.dart';
import '../utils/image_helpers.dart';
import '../widgets/app_page_header.dart';

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final TextEditingController _searchController = TextEditingController();

  void _handleSendRequest(AppProvider provider) async {
    final username = _searchController.text.trim();
    if (username.isEmpty) return;

    try {
      await provider.sendFriendRequest(username);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend request sent to $username!')),
        );
      }
      _searchController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _handleRespond(
    AppProvider provider,
    String requestId,
    String fromId,
    bool accept,
  ) async {
    try {
      await provider.respondToRequest(requestId, fromId, accept);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept ? 'Friend request accepted!' : 'Request declined.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                  title: 'Friends',
                  user: provider.currentUser,
                ),
                const SizedBox(height: 24),
                _buildSearchAndAdd(provider),
                if (provider.incomingRequests.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildIncomingRequests(provider),
                ],
                const SizedBox(height: 24),
                _buildFriendCircles(provider),
                const SizedBox(height: 24),
                _buildFriendsFeed(provider),
                const SizedBox(height: 24),
                _buildLeaderboardAndActivity(context, provider),
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
          onTap: () => _handleSendRequest(provider),
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

  Widget _buildIncomingRequests(AppProvider provider) {
    final requests = provider.incomingRequests;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Friend Requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${requests.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
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
            children: requests.asMap().entries.map((entry) {
              final idx = entry.key;
              final req = entry.value;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.borderDefault,
                          backgroundImage: imageProviderFor(req.fromAvatarUrl),
                          child: req.fromAvatarUrl.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: AppTheme.outline,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req.fromUsername,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Text(
                                'Wants to be your friend',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _handleRespond(
                                provider,
                                req.id,
                                req.fromId,
                                true,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Accept',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _handleRespond(
                                provider,
                                req.id,
                                req.fromId,
                                false,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Decline',
                                  style: TextStyle(
                                    color: AppTheme.onSurfaceVariant,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (idx < requests.length - 1)
                    const Divider(height: 1, color: AppTheme.borderDefault),
                ],
              );
            }).toList(),
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
        const Text(
          'Friend Circles',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildMyMoodItem(todayLog),
              ...friends.map(_buildFriendMoodItem),
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
      final mood = _moodVisual(log.moodScore);
      icon = mood.icon;
      bgIconColor = mood.bg;
      fgIconColor = mood.fg;
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

  // Maps a mood score (1–10) to its face icon and colors. Shared by the
  // current user's "My Mood" item and the friends' mood badges.
  ({IconData icon, Color bg, Color fg}) _moodVisual(double score) {
    if (score >= 8) {
      return (
        icon: Icons.sentiment_very_satisfied,
        bg: AppTheme.primaryFixed,
        fg: AppTheme.primaryContainer,
      );
    } else if (score >= 6) {
      return (
        icon: Icons.sentiment_satisfied,
        bg: AppTheme.secondaryFixed,
        fg: AppTheme.secondary,
      );
    } else if (score <= 3) {
      return (
        icon: Icons.sentiment_very_dissatisfied,
        bg: const Color(0xFFFFDAD6),
        fg: AppTheme.error,
      );
    } else {
      return (
        icon: Icons.sentiment_neutral,
        bg: AppTheme.surfaceContainerHighest,
        fg: AppTheme.onSurfaceVariant,
      );
    }
  }

  // Friend's avatar with a mood-face badge. The badge only appears when the
  // friend has logged a mood today (moodScore > 0), sourced from their public
  // profile doc since friends' logs are private.
  Widget _buildFriendMoodItem(User friend) {
    final hasMood = friend.moodScore > 0;
    final mood = hasMood ? _moodVisual(friend.moodScore) : null;

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.borderDefault,
                    border: Border.all(color: AppTheme.primary, width: 2),
                    image: imageProviderFor(friend.avatarUrl) != null
                        ? DecorationImage(
                            image: imageProviderFor(friend.avatarUrl)!,
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: friend.avatarUrl.isEmpty
                      ? Icon(Icons.person, color: Colors.grey.shade400, size: 32)
                      : null,
                ),
                if (mood != null)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: mood.bg,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(mood.icon, color: mood.fg, size: 16),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            friend.username,
            style: const TextStyle(fontSize: 12, color: AppTheme.onSurface),
          ),
        ],
      ),
    );
  }

  // ── Friends' Journal feed ──────────────────────────────────────────────
  // A simple social feed of the journal entries friends have chosen to share
  // (isSharedWithFriends). An entry only shows once the friend shares it AND
  // you're mutual friends — and your OWN shared entries appear in your friends'
  // feeds, not your own (see streamFriendsSharedLogs).
  Widget _buildFriendsFeed(AppProvider provider) {
    final logs = provider.friendsSharedLogs;
    final friendMap = {for (final f in provider.friends) f.id: f};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.dynamic_feed, size: 18, color: AppTheme.primary),
            SizedBox(width: 6),
            Text(
              "Friends' Journal",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (logs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderDefault),
            ),
            child: const Column(
              children: [
                Icon(Icons.auto_stories_outlined, color: AppTheme.outline, size: 28),
                SizedBox(height: 8),
                Text('No shared entries yet',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text(
                  "When a friend shares a journal entry, it'll show up here.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                ),
              ],
            ),
          )
        else
          ...logs.map((log) => _buildFeedPost(log, friendMap[log.userId])),
      ],
    );
  }

  Widget _buildFeedPost(LogEntry log, User? friend) {
    final avatar = imageProviderFor(friend?.avatarUrl ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.surfaceContainerHighest,
                backgroundImage: avatar,
                child: avatar == null
                    ? const Icon(Icons.person, size: 18, color: AppTheme.outlineVariant)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(friend?.username ?? 'Friend',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(DateFormat('EEE, MMM d').format(log.date),
                        style: const TextStyle(fontSize: 11, color: AppTheme.outline)),
                  ],
                ),
              ),
              if (log.moodScore > 0)
                Icon(_feedMoodIcon(log.moodScore),
                    color: _feedMoodColor(log.moodScore), size: 22),
            ],
          ),
          if (log.moodScore > 0 || log.sleepHours > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (log.moodScore > 0)
                  _feedChip(Icons.mood, 'Mood ${log.moodScore.toStringAsFixed(1)}/10'),
                if (log.sleepHours > 0)
                  _feedChip(Icons.bedtime_outlined,
                      '${log.sleepHours.toStringAsFixed(1)}h sleep'),
              ],
            ),
          ],
          if (log.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(log.notes,
                style: const TextStyle(fontSize: 14, color: AppTheme.onSurface, height: 1.5)),
          ],
          if (log.emotions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: log.emotions
                  .map((e) => Chip(
                        label: Text(e, style: const TextStyle(fontSize: 11)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: AppTheme.surfaceContainerHighest,
                        side: BorderSide.none,
                      ))
                  .toList(),
            ),
          ],
          if (log.photoUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: storedImage(
                log.photoUrl,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                fallback: Container(
                  height: 180,
                  color: AppTheme.surfaceContainer,
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined, color: AppTheme.outlineVariant),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _feedChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  IconData _feedMoodIcon(double s) {
    if (s <= 2) return Icons.sentiment_very_dissatisfied;
    if (s <= 4) return Icons.sentiment_dissatisfied;
    if (s <= 6) return Icons.sentiment_neutral;
    if (s <= 8.5) return Icons.sentiment_satisfied;
    return Icons.sentiment_very_satisfied;
  }

  Color _feedMoodColor(double s) {
    if (s <= 4) return AppTheme.error;
    if (s <= 6) return AppTheme.tertiary;
    return AppTheme.secondary;
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
    // Friends-only leaderboard ranked by streak (FR_505 / LeaderboardEntry).
    // `provider.leaderboard` is already streak-sorted with a username tiebreak.
    final sorted = provider.leaderboard; // current user + friends
    final currentUser = provider.currentUser;
    final currentUserId = currentUser?.id;
    String subtitle(User u) => '${u.streak}d streak';

    final myRank = provider.myLeaderboardRank;
    final userInList = sorted.any((u) => u.id == currentUserId);

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
          const Row(
            children: [
              Icon(Icons.leaderboard, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Friends Leaderboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Ranked by daily streak',
            style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (sorted.isEmpty)
            const Text('No data available', style: TextStyle(color: Colors.grey))
          else
            ...sorted.asMap().entries.map((entry) {
              final idx = entry.key;
              final user = entry.value;
              final isUser = user.id == currentUserId;
              return _buildLeaderboardRow(
                '${idx + 1}',
                isUser ? 'You (${user.username})' : user.username,
                subtitle(user),
                idx == 0,
                isUser,
                user.avatarUrl,
              );
            }),
          if (!userInList && currentUser != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('···', style: TextStyle(color: AppTheme.outline)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
            ),
            _buildLeaderboardRow(
              myRank > 0 ? '#$myRank' : '—',
              'You (${currentUser.username})',
              subtitle(currentUser),
              false,
              true,
              currentUser.avatarUrl,
            ),
          ],
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
            backgroundImage: imageProviderFor(avatarUrl),
            child: imageProviderFor(avatarUrl) == null
                ? const Icon(Icons.person, size: 20, color: AppTheme.outline)
                : null,
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

}
