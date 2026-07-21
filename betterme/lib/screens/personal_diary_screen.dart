import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/app_page_header.dart';

class PersonalDiaryScreen extends StatefulWidget {
  const PersonalDiaryScreen({super.key});

  @override
  State<PersonalDiaryScreen> createState() => _PersonalDiaryScreenState();
}

class _PersonalDiaryScreenState extends State<PersonalDiaryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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

  void _showEditSheet(BuildContext context, AppProvider provider, {LogEntry? log}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditJournalSheet(provider: provider, log: log),
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
              _buildSearchBar(),
              const SizedBox(height: 24),
              _buildMyEntriesSection(context, provider, filtered),
              if (friendsLogs.isNotEmpty) ...[
                const SizedBox(height: 32),
                _buildFriendsSection(context, provider, friendsLogs),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showEditSheet(context, provider),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.edit_note),
          label: const Text('Write about today'),
        ),
      ),
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

          // Mood + sleep summary
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
                child: Image.network(
                  log.photoUrl,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
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
                backgroundImage: friend != null && friend.avatarUrl.isNotEmpty
                    ? NetworkImage(friend.avatarUrl)
                    : null,
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
              child: Image.network(
                log.photoUrl,
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
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
    if (score >= 8.5) return Icons.sentiment_very_satisfied;
    if (score >= 6) return Icons.sentiment_satisfied;
    if (score >= 4) return Icons.sentiment_neutral;
    if (score >= 2) return Icons.sentiment_dissatisfied;
    return Icons.sentiment_very_dissatisfied;
  }

  Color _moodColor(double score) {
    if (score <= 0) return AppTheme.outlineVariant;
    if (score >= 8.5) return const Color(0xFF2E7D32);
    if (score >= 6) return AppTheme.primary;
    if (score >= 4) return const Color(0xFFF57F17);
    return AppTheme.error;
  }
}

// Full-field journal editor. Kept as its own StatefulWidget (rather than a
// closure-built dialog with manually managed controllers) so all controller
// and field state follows the normal Flutter State lifecycle.
class _EditJournalSheet extends StatefulWidget {
  final AppProvider provider;
  final LogEntry? log;

  const _EditJournalSheet({required this.provider, this.log});

  @override
  State<_EditJournalSheet> createState() => _EditJournalSheetState();
}

class _EditJournalSheetState extends State<_EditJournalSheet> {
  static const _emotionOptions = ['Anxiety', 'Fatigue', 'Headache', 'Nausea', 'Pain', 'Joy', 'Stress', 'Calm'];
  static const _qualityLevels = [0, 2, 4, 6, 8, 10];
  static const _qualityLabels = ['Not set', 'Restless', 'Poor', 'Good', 'Solid', 'Deep'];

  late final DateTime _date;
  late double _moodScore;
  late double _sleepHours;
  late int _sleepQuality;
  late bool _hadNightmare;
  late bool _isShared;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _triggerCtrl;
  late final Set<String> _emotions;
  late String _photoUrl;
  bool _saving = false;
  bool _uploadingPhoto = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final log = widget.log;
    _date = log?.date ?? DateTime.now();
    _moodScore = log?.moodScore ?? 0;
    _sleepHours = log?.sleepHours ?? 0;
    _sleepQuality = log?.sleepQuality ?? 0;
    _hadNightmare = log?.hadNightmare ?? false;
    _isShared = log?.isSharedWithFriends ?? false;
    _notesCtrl = TextEditingController(text: log?.notes ?? '');
    _triggerCtrl = TextEditingController(text: log?.trigger ?? '');
    _emotions = {...(log?.emotions ?? const [])};
    _photoUrl = log?.photoUrl ?? '';
  }

  Future<void> _pickPhoto() async {
    if (_uploadingPhoto) return;
    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final url =
          await widget.provider.uploadJournalPhoto(File(image.path), _date);
      if (mounted) setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to upload photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _triggerCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final fields = <String, dynamic>{
      'moodScore': _moodScore,
      'sleepHours': _sleepHours,
      'sleepQuality': _sleepQuality,
      'hadNightmare': _hadNightmare,
      'isSharedWithFriends': _isShared,
      'notes': _notesCtrl.text.trim(),
      'trigger': _triggerCtrl.text.trim(),
      'emotions': _emotions.toList(),
      'photoUrl': _photoUrl,
    };
    await widget.provider.saveLogFields(_date, fields);
    if (mounted) Navigator.of(context).pop();
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

                _sectionLabel('Mood', _moodScore <= 0 ? 'Not logged' : _moodScore.toStringAsFixed(1)),
                Slider(
                  value: _moodScore,
                  min: 0,
                  max: 10,
                  divisions: 20,
                  activeColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _moodScore = v),
                ),
                const SizedBox(height: 8),

                _sectionLabel('Sleep hours', _sleepHours <= 0 ? 'Not logged' : '${_sleepHours.toStringAsFixed(1)}h'),
                Slider(
                  value: _sleepHours,
                  min: 0,
                  max: 12,
                  divisions: 24,
                  activeColor: AppTheme.secondary,
                  onChanged: (v) => setState(() => _sleepHours = v),
                ),
                const SizedBox(height: 12),

                const Text('Sleep quality', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_qualityLevels.length, (i) {
                    final level = _qualityLevels[i];
                    final selected = _sleepQuality == level;
                    return ChoiceChip(
                      label: Text(_qualityLabels[i]),
                      selected: selected,
                      selectedColor: AppTheme.primaryFixed,
                      onSelected: (_) => setState(() => _sleepQuality = level),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Had a nightmare', style: TextStyle(fontSize: 14)),
                  value: _hadNightmare,
                  onChanged: (v) => setState(() => _hadNightmare = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visible to friends', style: TextStyle(fontSize: 14)),
                  value: _isShared,
                  onChanged: (v) => setState(() => _isShared = v),
                ),
                const SizedBox(height: 8),

                const Text('Emotions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _emotionOptions.map((e) {
                    final selected = _emotions.contains(e);
                    return FilterChip(
                      label: Text(e),
                      selected: selected,
                      selectedColor: AppTheme.primaryFixed,
                      onSelected: (sel) => setState(() => sel ? _emotions.add(e) : _emotions.remove(e)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                const Text('Trigger', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                const SizedBox(height: 8),
                TextField(
                  controller: _triggerCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Work, Exercise',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Photo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                const SizedBox(height: 8),
                _buildPhotoField(),
                const SizedBox(height: 16),

                const Text('Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'How was your day?',
                    border: OutlineInputBorder(),
                  ),
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

  Widget _sectionLabel(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
          Text(value, style: const TextStyle(fontSize: 13, color: AppTheme.outline)),
        ],
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
          child: Image.network(
            _photoUrl,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 180,
              color: AppTheme.surfaceContainer,
              child: const Center(
                child: Icon(Icons.broken_image_outlined, color: AppTheme.outlineVariant),
              ),
            ),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : Container(
                    height: 180,
                    color: AppTheme.surfaceContainerLow,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
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
