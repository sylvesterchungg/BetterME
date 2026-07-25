import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/image_helpers.dart';
import '../widgets/app_page_header.dart';

class PersonalDiaryScreen extends StatefulWidget {
  const PersonalDiaryScreen({super.key});

  @override
  State<PersonalDiaryScreen> createState() => _PersonalDiaryScreenState();
}

class _PersonalDiaryScreenState extends State<PersonalDiaryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // View mode
  bool _calendarView = false;
  DateTime _calendarMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(LogEntry log) {
    if (_searchQuery.isEmpty) return true;
    final dateStr = DateFormat('MMM dd yyyy').format(log.date).toLowerCase();
    return log.notes.toLowerCase().contains(_searchQuery) ||
        log.trigger.toLowerCase().contains(_searchQuery) ||
        log.emotions.any((e) => e.toLowerCase().contains(_searchQuery)) ||
        dateStr.contains(_searchQuery);
  }

  void _showEditSheet(BuildContext context, AppProvider provider,
      {LogEntry? log, DateTime? date}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _EditJournalSheet(provider: provider, log: log, initialDate: date),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final myLogs = List<LogEntry>.from(provider.logs)
      ..sort((a, b) => b.date.compareTo(a.date));
    final filtered = myLogs.where(_matchesSearch).toList();
    final friendsLogs = provider.friendsSharedLogs;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppPageHeader(title: 'My Journal', user: provider.currentUser),
              const SizedBox(height: 8),
              const Text(
                'Review your journey and celebrate your progress.',
                style: TextStyle(fontSize: 14, color: AppTheme.outline),
              ),
              const SizedBox(height: 20),
              _buildStatsRow(provider.currentUser?.streak ?? 0, myLogs.length),
              const SizedBox(height: 20),
              // View toggle + search (search only in list view)
              _buildViewToggle(),
              if (!_calendarView) ...[
                const SizedBox(height: 12),
                _buildSearchBar(),
              ],
              const SizedBox(height: 20),
              if (_calendarView)
                _buildCalendar(context, provider, myLogs)
              else ...[
                _buildMyEntriesSection(context, provider, filtered),
                if (friendsLogs.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _buildFriendsSection(context, provider, friendsLogs),
                ],
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            // Prefill with today's existing entry if one exists — without
            // this, the sheet always opened blank and saving it overwrote
            // (erased) any notes/photo already written for today.
            final now = DateTime.now();
            final todayLogs = myLogs.where((l) =>
                l.date.year == now.year &&
                l.date.month == now.month &&
                l.date.day == now.day).toList();
            if (todayLogs.isNotEmpty) {
              _showEditSheet(context, provider, log: todayLogs.first);
            } else {
              _showEditSheet(context, provider, date: now);
            }
          },
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.edit_note),
          label: const Text('Write about today'),
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      decoration: BoxDecoration(
          color: AppTheme.borderDefault, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _toggleBtn(label: 'List', icon: Icons.list, active: !_calendarView,
              onTap: () => setState(() => _calendarView = false)),
          _toggleBtn(label: 'Calendar', icon: Icons.calendar_month, active: _calendarView,
              onTap: () => setState(() => _calendarView = true)),
        ],
      ),
    );
  }

  Widget _toggleBtn({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16,
                  color: active ? AppTheme.primary : AppTheme.outline),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: active ? AppTheme.primary : AppTheme.outline)),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────── CALENDAR VIEW ─────────────────────────────

  Widget _buildCalendar(BuildContext context, AppProvider provider, List<LogEntry> logs) {
    final logMap = <String, LogEntry>{};
    for (final l in logs) {
      final key = '${l.date.year}-${l.date.month}-${l.date.day}';
      logMap.putIfAbsent(key, () => l);
    }

    final year = _calendarMonth.year;
    final month = _calendarMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // weekday: Mon=1…Sun=7 → offset so Sunday=0
    final firstWeekday = DateTime(year, month, 1).weekday % 7;

    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month}-${now.day}';
    final canGoForward =
        year < now.year || (year == now.year && month < now.month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month navigation
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderDefault),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () => setState(
                    () => _calendarMonth = DateTime(year, month - 1)),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(_calendarMonth),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right,
                    size: 20,
                    color: canGoForward
                        ? AppTheme.onSurface
                        : AppTheme.outlineVariant),
                onPressed: canGoForward
                    ? () => setState(
                        () => _calendarMonth = DateTime(year, month + 1))
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Calendar grid
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderDefault),
          ),
          child: Column(
            children: [
              // Weekday headers
              Row(
                children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                    .map((d) => Expanded(
                          child: Center(
                            child: Text(d,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.outline)),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),

              // Day cells — 7-column grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.0,
                  mainAxisSpacing: 4,
                ),
                itemCount: firstWeekday + daysInMonth,
                itemBuilder: (ctx, index) {
                  if (index < firstWeekday) return const SizedBox();
                  final day = index - firstWeekday + 1;
                  final date = DateTime(year, month, day);
                  final key = '$year-$month-$day';
                  final isToday = key == todayStr;
                  final isFuture = date.isAfter(DateTime(now.year, now.month, now.day));
                  final log = logMap[key];

                  return GestureDetector(
                    onTap: isFuture
                        ? null
                        : () {
                            if (log != null) {
                              _showEditSheet(context, provider, log: log);
                            } else {
                              _showEditSheet(context, provider, date: date);
                            }
                          },
                    child: _buildDayCell(day, log, isToday, isFuture),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        // Legend
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            _legendDot(AppTheme.primary, 'Today'),
            _legendDot(const Color(0xFF2E7D32), 'High (7+)'),
            _legendDot(const Color(0xFFF57F17), 'Moderate (4–7)'),
            _legendDot(AppTheme.error, 'Low (<4)'),
            _legendDot(AppTheme.outlineVariant, 'No entry'),
          ],
        ),
      ],
    );
  }

  Widget _buildDayCell(int day, LogEntry? log, bool isToday, bool isFuture) {
    Color bgColor = Colors.transparent;
    Color textColor = isFuture ? AppTheme.outlineVariant : AppTheme.onSurface;
    Widget? dot;

    if (isToday) {
      bgColor = AppTheme.primary;
      textColor = Colors.white;
    } else if (log != null) {
      final moodColor = _moodColor(log.moodScore);
      bgColor = moodColor.withValues(alpha: 0.12);
      dot = Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(color: moodColor, shape: BoxShape.circle),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$day',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isToday ? FontWeight.w700 : FontWeight.w400,
                  color: textColor)),
          ?dot,
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.outline)),
      ],
    );
  }

  Widget _buildStatsRow(int streak, int total) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryFixed.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderDefault),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Streak', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                    const SizedBox(height: 2),
                    Text('$streak days', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2F2EBE))),
                  ],
                ),
                const Icon(Icons.local_fire_department, color: AppTheme.primary, size: 32),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderDefault),
            ),
            child: Column(
              children: [
                const Text('Entries', style: TextStyle(fontSize: 12, color: AppTheme.outline)),
                const SizedBox(height: 4),
                Text('$total', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.onSurface)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
                hintText: 'Search by mood, notes, trigger...',
                hintStyle: TextStyle(color: AppTheme.outline, fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () => _searchController.clear(),
              child: const Icon(Icons.close, color: AppTheme.outline, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _buildMyEntriesSection(BuildContext context, AppProvider provider, List<LogEntry> logs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('My Entries', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.onSurface)),
        const SizedBox(height: 12),
        if (logs.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  const Icon(Icons.book_outlined, size: 48, color: AppTheme.outlineVariant),
                  const SizedBox(height: 12),
                  Text(
                    _searchQuery.isEmpty ? 'No entries yet. Tap "Write about today" to start.' : 'No entries match your search.',
                    style: const TextStyle(color: AppTheme.outline),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...logs.map((log) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildMyEntryCard(context, provider, log),
          )),
      ],
    );
  }

  Widget _buildMyEntryCard(BuildContext context, AppProvider provider, LogEntry log) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final logDay = DateTime(log.date.year, log.date.month, log.date.day);
    final String dateLabel;
    if (logDay == today) {
      dateLabel = 'Today · ${DateFormat('MMM dd').format(log.date)}';
    } else if (logDay == today.subtract(const Duration(days: 1))) {
      dateLabel = 'Yesterday · ${DateFormat('MMM dd').format(log.date)}';
    } else {
      dateLabel = DateFormat('EEE, MMM dd, yyyy').format(log.date);
    }

    final hasMood = log.moodScore > 0;
    final hasSleep = log.sleepHours > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderDefault),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Icon(_moodIcon(log.moodScore), color: _moodColor(log.moodScore), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(dateLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                ),
                // Share toggle
                Tooltip(
                  message: log.isSharedWithFriends ? 'Visible to friends' : 'Only visible to you',
                  child: IconButton(
                    icon: Icon(
                      log.isSharedWithFriends ? Icons.people : Icons.lock_outline,
                      size: 20,
                      color: log.isSharedWithFriends ? AppTheme.primary : AppTheme.outlineVariant,
                    ),
                    onPressed: () => provider.toggleLogSharing(log),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.outlineVariant),
                  onPressed: () => _showEditSheet(context, provider, log: log),
                ),
              ],
            ),
          ),

          // Mood + sleep summary (read-only preview — edit these in the Daily Log tab)
          if (hasMood || hasSleep)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (hasMood)
                    _summaryChip(
                      Icons.mood,
                      '${log.moodScore.toStringAsFixed(1)} / 10',
                      _moodColor(log.moodScore).withValues(alpha: 0.12),
                      _moodColor(log.moodScore),
                    ),
                  if (hasSleep) ...[
                    _summaryChip(
                      Icons.bedtime_outlined,
                      '${log.sleepHours.toStringAsFixed(1)}h',
                      AppTheme.secondaryFixed.withValues(alpha: 0.5),
                      AppTheme.secondary,
                    ),
                    if (log.sleepQuality > 0)
                      _summaryChip(
                        Icons.star_outline,
                        'Quality ${log.sleepQuality}/10',
                        AppTheme.secondaryFixed.withValues(alpha: 0.3),
                        AppTheme.secondary,
                      ),
                    if (log.hadNightmare)
                      _summaryChip(
                        Icons.nightlight_outlined,
                        'Nightmare',
                        const Color(0xFFFFDAD6),
                        AppTheme.error,
                      ),
                  ],
                ],
              ),
            ),

          // Emotions
          if (log.emotions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: log.emotions.map((e) => Chip(
                  label: Text(e, style: const TextStyle(fontSize: 11)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: AppTheme.surfaceContainerHighest,
                  side: BorderSide.none,
                )).toList(),
              ),
            ),

          // Trigger
          if (log.trigger.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.bolt, size: 14, color: AppTheme.outline),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      log.trigger,
                      style: const TextStyle(fontSize: 12, color: AppTheme.outline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // Notes
          if (log.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                log.notes,
                style: const TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant, height: 1.5),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Photo
          if (log.photoUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ClipRRect(
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
            ),

          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildFriendsSection(BuildContext context, AppProvider provider, List<LogEntry> friendsLogs) {
    // Build a map from userId → User for display
    final friendMap = {for (final f in provider.friends) f.id: f};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.people_outline, size: 18, color: AppTheme.primary),
            SizedBox(width: 6),
            Text('Friends\' Shared Entries', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.onSurface)),
          ],
        ),
        const SizedBox(height: 12),
        ...friendsLogs.map((log) {
          final friend = friendMap[log.userId];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildFriendLogCard(log, friend),
          );
        }),
      ],
    );
  }

  Widget _buildFriendLogCard(LogEntry log, User? friend) {
    final dateLabel = DateFormat('EEE, MMM dd').format(log.date);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderDefault),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Friend avatar
              CircleAvatar(
                radius: 16,
                backgroundImage:
                    friend != null ? imageProviderFor(friend.avatarUrl) : null,
                backgroundColor: AppTheme.surfaceContainerHighest,
                child: friend == null || friend.avatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 16, color: AppTheme.outlineVariant)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(friend?.username ?? 'Friend', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(dateLabel, style: const TextStyle(fontSize: 11, color: AppTheme.outline)),
                  ],
                ),
              ),
              Icon(_moodIcon(log.moodScore), color: _moodColor(log.moodScore), size: 20),
            ],
          ),
          if (log.moodScore > 0 || log.sleepHours > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (log.moodScore > 0)
                  _summaryChip(Icons.mood, '${log.moodScore.toStringAsFixed(1)} / 10', _moodColor(log.moodScore).withValues(alpha: 0.12), _moodColor(log.moodScore)),
                if (log.sleepHours > 0)
                  _summaryChip(Icons.bedtime_outlined, '${log.sleepHours.toStringAsFixed(1)}h sleep', AppTheme.secondaryFixed.withValues(alpha: 0.5), AppTheme.secondary),
              ],
            ),
          ],
          if (log.emotions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: log.emotions.map((e) => Chip(
                label: Text(e, style: const TextStyle(fontSize: 11)),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: AppTheme.surfaceContainerHighest,
                side: BorderSide.none,
              )).toList(),
            ),
          ],
          if (log.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              log.notes,
              style: const TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant, height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (log.photoUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: storedImage(
                log.photoUrl,
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                fallback: Container(
                  height: 160,
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

}

// Shared read-only chip/mood helpers, used by both the entry cards and the
// editor's read-only preview (top-level so both State classes can call them).
Widget _summaryChip(IconData icon, String label, Color bg, Color fg) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: fg),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

IconData _moodIcon(double score) {
  if (score <= 0) return Icons.sentiment_neutral;
  if (score >= 7) return Icons.sentiment_very_satisfied; // High
  if (score >= 4) return Icons.sentiment_satisfied; // Moderate
  return Icons.sentiment_dissatisfied; // Low
}

Color _moodColor(double score) {
  if (score <= 0) return AppTheme.outlineVariant;
  if (score >= 7) return const Color(0xFF2E7D32); // High
  if (score >= 4) return const Color(0xFFF57F17); // Moderate
  return AppTheme.error; // Low
}

// Full-field journal editor. Kept as its own StatefulWidget (rather than a
// closure-built dialog with manually managed controllers) so all controller
// and field state follows the normal Flutter State lifecycle.
class _EditJournalSheet extends StatefulWidget {
  final AppProvider provider;
  final LogEntry? log;
  final DateTime? initialDate;

  const _EditJournalSheet({required this.provider, this.log, this.initialDate});

  @override
  State<_EditJournalSheet> createState() => _EditJournalSheetState();
}

class _EditJournalSheetState extends State<_EditJournalSheet> {
  // The journal entry is intentionally just a photo + a note (+ a share
  // toggle). Mood, sleep and symptoms are captured in the Daily Log tab and are
  // deliberately not edited here, so writing a journal entry never overwrites
  // them.
  late final DateTime _date;
  late bool _isShared;
  late final TextEditingController _notesCtrl;
  late String _photoUrl;
  bool _saving = false;
  bool _uploadingPhoto = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final log = widget.log;
    _date = log?.date ?? widget.initialDate ?? DateTime.now();
    _isShared = log?.isSharedWithFriends ?? false;
    _notesCtrl = TextEditingController(text: log?.notes ?? '');
    _photoUrl = log?.photoUrl ?? '';
  }

  Future<void> _pickPhoto() async {
    if (_uploadingPhoto) return;
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 70,
    );
    if (image == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      // No Firebase Storage on the free plan — encode the (resized) image as
      // base64 and keep it on the log document itself.
      final encoded = await fileToBase64(File(image.path));
      if (!mounted) return;
      if (encoded == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('That photo is too large to save. Try a smaller one.')));
      } else {
        setState(() => _photoUrl = encoded);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to add photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  // The day's log (for showing mood/sleep read-only). Uses the passed-in entry
  // when editing, otherwise finds today's log so "Write about today" can still
  // show what was already logged in the Daily Log tab.
  LogEntry? get _dayLog {
    if (widget.log != null) return widget.log;
    for (final l in widget.provider.logs) {
      if (l.date.year == _date.year &&
          l.date.month == _date.month &&
          l.date.day == _date.day) {
        return l;
      }
    }
    return null;
  }

  // Read-only preview of the day's logged mood/sleep/quality/emotions — same
  // chips as the entry cards. These are edited in the Daily Log tab, not here.
  // Renders nothing when the day has nothing logged yet.
  Widget _buildLoggedInfo() {
    final log = _dayLog;
    final mood = log?.moodScore ?? 0;
    final sleep = log?.sleepHours ?? 0;
    final quality = log?.sleepQuality ?? 0;
    final nightmare = log?.hadNightmare ?? false;
    final emotions = log?.emotions ?? const <String>[];
    final hasAny =
        mood > 0 || sleep > 0 || quality > 0 || nightmare || emotions.isNotEmpty;
    if (!hasAny) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (mood > 0)
              _summaryChip(Icons.mood, '${mood.toStringAsFixed(1)} / 10',
                  _moodColor(mood).withValues(alpha: 0.12), _moodColor(mood)),
            if (sleep > 0)
              _summaryChip(Icons.bedtime_outlined, '${sleep.toStringAsFixed(1)}h',
                  AppTheme.secondaryFixed.withValues(alpha: 0.5), AppTheme.secondary),
            if (quality > 0)
              _summaryChip(Icons.star_outline, 'Quality $quality/10',
                  AppTheme.secondaryFixed.withValues(alpha: 0.3), AppTheme.secondary),
            if (nightmare)
              _summaryChip(Icons.nightlight_outlined, 'Nightmare',
                  const Color(0xFFFFDAD6), AppTheme.error),
          ],
        ),
        if (emotions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: emotions
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
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    // Only the journal fields — mood/sleep/quality live in the Daily Log tab, so
    // we deliberately don't write them here (the upsert leaves them untouched).
    final fields = <String, dynamic>{
      'isSharedWithFriends': _isShared,
      'notes': _notesCtrl.text.trim(),
      'photoUrl': _photoUrl,
    };
    try {
      await widget.provider.saveLogFields(_date, fields);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save — check your connection and try again.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.log != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  isEditing ? 'Edit — ${DateFormat('MMM dd, yyyy').format(_date)}' : 'Write about today',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
                ),
                const SizedBox(height: 20),

                _buildLoggedInfo(),

                const Text('Photo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                const SizedBox(height: 8),
                _buildPhotoField(),
                const SizedBox(height: 20),

                const Text('Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 6,
                  // Bounded so a very long entry plus a near-max-size photo
                  // can't push the whole log document past Firestore's 1MB
                  // document limit (the photo alone is already capped, but
                  // the combined document wasn't).
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    hintText: 'How was your day?',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visible to friends', style: TextStyle(fontSize: 14)),
                  subtitle: const Text(
                    'Share this entry to your friends’ feed',
                    style: TextStyle(fontSize: 12, color: AppTheme.outline),
                  ),
                  value: _isShared,
                  onChanged: (v) => setState(() => _isShared = v),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                        child: _saving
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoField() {
    final hasPhoto = _photoUrl.isNotEmpty;

    if (_uploadingPhoto) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderDefault),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
              SizedBox(height: 8),
              Text('Uploading…', style: TextStyle(fontSize: 12, color: AppTheme.outline)),
            ],
          ),
        ),
      );
    }

    if (!hasPhoto) {
      return OutlinedButton.icon(
        onPressed: _pickPhoto,
        icon: const Icon(Icons.add_a_photo_outlined, size: 18),
        label: const Text('Add a photo'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          minimumSize: const Size(double.infinity, 0),
          side: const BorderSide(color: AppTheme.borderDefault),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: storedImage(
            _photoUrl,
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
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Replace'),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: () => setState(() => _photoUrl = ''),
                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                label: const Text('Remove', style: TextStyle(color: AppTheme.error)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
