import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../utils/stats.dart';
import '../widgets/app_page_header.dart';

// Symptom options shown in the Track Symptoms chip row
const _kSymptoms = [
  (name: 'Anxiety', icon: Icons.psychology),
  (name: 'Fatigue', icon: Icons.bolt),
  (name: 'Headache', icon: Icons.headset_off),
  (name: 'Nausea', icon: Icons.sick),
  (name: 'Pain', icon: Icons.warning_amber),
];

// Activity options shown in "What have you been up to?"
const _kActivities = ['Work', 'Relaxing', 'Exercise', 'Social', 'Hobbies'];
const _kKnownActivities = {'Work', 'Relaxing', 'Exercise', 'Social', 'Hobbies'};

// Sleep quality levels (index 0-4 → sleepQuality values 2,4,6,8,10)
const _kSleepQualityLabels = ['Restless', 'Poor', 'Good', 'Solid', 'Deep'];

// Severity levels (1-5)
const _kSeverityLabels = ['Mild', 'Low', 'Moderate', 'High', 'Severe'];

class DailyLogTab extends StatefulWidget {
  const DailyLogTab({super.key});

  @override
  State<DailyLogTab> createState() => _DailyLogTabState();
}

class _DailyLogTabState extends State<DailyLogTab> {
  // ── Mode ──────────────────────────────────────────────
  String _logMode = 'mood';

  // ── Mood ──────────────────────────────────────────────
  String? _selectedMoodEmoji;
  double _moodScore = 5.0;

  // ── Activities ────────────────────────────────────────
  final Set<String> _selectedActivities = {};
  bool _showOthersInput = false;
  final TextEditingController _othersController = TextEditingController();

  // ── Symptoms ──────────────────────────────────────────
  final Set<String> _selectedSymptoms = {};
  int _symptomSeverity = 3; // 1 = Mild … 5 = Severe
  final TextEditingController _symptomNotesController = TextEditingController();

  // ── Sleep ─────────────────────────────────────────────
  double _sleepHours = 7.0;
  int _sleepQuality = 0; // 0 = unset; 2,4,6,8,10 for Restless→Deep
  bool _hadNightmare = false;

  // Sleep input method: 'hours' = drag the slider; 'time' = pick bedtime +
  // wake-up and derive the hours. Compute-only — the times themselves are not
  // persisted; they just fill _sleepHours (the value that gets saved).
  String _sleepInputMode = 'hours';
  TimeOfDay _bedtime = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);

  // ── Date navigation ───────────────────────────────────
  DateTime _selectedDate = DateTime.now();

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  // ── Pre-population tracking ───────────────────────────
  String _loadedForDate = '';
  double _prevMoodScore = 0.0;
  double _prevSleepHours = 0.0;

  @override
  void dispose() {
    _othersController.dispose();
    _symptomNotesController.dispose();
    super.dispose();
  }

  // ─────────────────────────────── HELPERS ───────────────────────────────

  String _severityLabel(int v) => _kSeverityLabels[(v - 1).clamp(0, 4)];

  int _severityFromLabel(String label) {
    final idx = _kSeverityLabels.indexOf(label);
    return idx >= 0 ? idx + 1 : 3;
  }

  void _parseSavedNotes(String notes) {
    if (notes.startsWith('Severity:')) {
      final nl = notes.indexOf('\n');
      final severityLine = nl >= 0 ? notes.substring(0, nl) : notes;
      _symptomSeverity = _severityFromLabel(severityLine.replaceFirst('Severity:', '').trim());
      _symptomNotesController.text = nl >= 0 ? notes.substring(nl + 1).trim() : '';
    } else {
      _symptomNotesController.text = notes;
    }
  }

  // ─────────────────────────────── DATE NAV ──────────────────────────────

  String get _dateKey =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  void _changeDate(int days, AppProvider provider) {
    final candidate = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day + days);
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    if (candidate.isAfter(todayStart)) return;
    setState(() {
      _selectedDate = candidate;
      _loadedForDate = '';
      _prevMoodScore = 0.0;
      _prevSleepHours = 0.0;
      // Reset form fields to defaults before loading new date
      _selectedMoodEmoji = null;
      _moodScore = 5.0;
      _selectedActivities.clear();
      _showOthersInput = false;
      _othersController.clear();
      _selectedSymptoms.clear();
      _symptomNotesController.clear();
      _symptomSeverity = 3;
      _sleepHours = 7.0;
      _sleepQuality = 0;
      _hadNightmare = false;
      _sleepInputMode = 'hours';
      _bedtime = const TimeOfDay(hour: 23, minute: 0);
      _wakeTime = const TimeOfDay(hour: 7, minute: 0);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadValuesForDate(provider, candidate);
    });
  }

  // ─────────────────────────────── LOAD DATE ─────────────────────────────

  void _loadValuesForDate(AppProvider provider, DateTime date) {
    LogEntry? todayLog;
    for (final l in provider.logs) {
      if (l.date.year == date.year && l.date.month == date.month && l.date.day == date.day) {
        todayLog = l;
        break;
      }
    }
    if (todayLog == null) return;

    setState(() {
      // ── Mood ──
      if (todayLog!.moodScore > 0) {
        _moodScore = todayLog.moodScore;
        _prevMoodScore = todayLog.moodScore;
        final s = todayLog.moodScore;
        _selectedMoodEmoji = s <= 2.0 ? 'awful' : s <= 4.0 ? 'bad' : s <= 6.0 ? 'meh' : s <= 8.5 ? 'good' : 'great';
      }

      // ── Activities ──
      _selectedActivities.clear();
      _showOthersInput = false;
      _othersController.text = '';
      final customActs = <String>[];
      for (final act in todayLog.trigger.split(', ').where((s) => s.isNotEmpty)) {
        if (_kKnownActivities.contains(act)) {
          _selectedActivities.add(act);
        } else {
          customActs.add(act);
        }
      }
      if (customActs.isNotEmpty) {
        _selectedActivities.add('Others');
        _othersController.text = customActs.join(', ');
        _showOthersInput = true;
      }

      // ── Symptoms ──
      _selectedSymptoms.clear();
      _selectedSymptoms.addAll(todayLog.emotions);
      _parseSavedNotes(todayLog.notes);

      // ── Sleep ──
      if (todayLog.sleepHours > 0) {
        _sleepHours = todayLog.sleepHours;
        _prevSleepHours = todayLog.sleepHours;
        _sleepQuality = todayLog.sleepQuality;
        _hadNightmare = todayLog.hadNightmare;
      }
    });
  }

  // ─────────────────────────────── SAVE ──────────────────────────────────

  Future<void> _saveLog() async {
    final provider = context.read<AppProvider>();

    if (_logMode == 'mood') {
      final newScore = _moodScore.clamp(1.0, 10.0);
      final prevForDisplay = _prevMoodScore;
      final hasMoodChange = _prevMoodScore > 0 && _prevMoodScore != newScore;

      // Resolve custom activity
      final allActivities = Set<String>.from(_selectedActivities);
      if (allActivities.contains('Others')) {
        allActivities.remove('Others');
        final custom = _othersController.text.trim();
        if (custom.isNotEmpty) allActivities.add(custom);
      }

      // Build notes string (severity + free text) — saved to journal via LogEntry.notes
      String notesText = '';
      if (_selectedSymptoms.isNotEmpty) {
        notesText = 'Severity: ${_severityLabel(_symptomSeverity)}';
        final userNotes = _symptomNotesController.text.trim();
        if (userNotes.isNotEmpty) notesText += '\n$userNotes';
      } else {
        notesText = _symptomNotesController.text.trim();
      }

      await provider.saveLogFields(_selectedDate, {
        'previousMoodScore': hasMoodChange ? _prevMoodScore : 0.0,
        'moodScore': newScore,
        'emotions': _selectedSymptoms.toList(),
        'trigger': allActivities.join(', '),
        'notes': notesText,
      });

      setState(() => _prevMoodScore = newScore);
      _showSuccessSnackbar(hasMoodChange ? prevForDisplay : null, null);
    } else {
      final newHours = _sleepHours.clamp(0.0, 24.0);
      final prevForDisplay = _prevSleepHours;
      final hasSleepChange = _prevSleepHours > 0 && _prevSleepHours != newHours;

      await provider.saveLogFields(_selectedDate, {
        'previousSleepHours': hasSleepChange ? _prevSleepHours : 0.0,
        'sleepHours': newHours,
        'sleepQuality': _sleepQuality.clamp(0, 10),
        'hadNightmare': _hadNightmare,
      });

      setState(() => _prevSleepHours = newHours);
      _showSuccessSnackbar(null, hasSleepChange ? prevForDisplay : null);
    }
  }

  void _showSuccessSnackbar(double? prevMood, double? prevSleep) {
    if (!mounted) return;
    String message;
    if (_logMode == 'mood') {
      message = prevMood != null
          ? 'Mood updated: ${prevMood.toStringAsFixed(1)} → ${_moodScore.toStringAsFixed(1)} / 10'
          : 'Mood saved: ${_moodScore.toStringAsFixed(1)} / 10.0';
    } else {
      message = prevSleep != null
          ? 'Sleep updated: ${prevSleep.toStringAsFixed(1)}h → ${_sleepHours.toStringAsFixed(1)}h'
          : 'Sleep saved: ${_sleepHours.toStringAsFixed(1)}h';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.primary),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (_loadedForDate != _dateKey && provider.logs.isNotEmpty) {
      _loadedForDate = _dateKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadValuesForDate(provider, _selectedDate);
      });
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(title: 'Daily Log', user: provider.currentUser),
            const SizedBox(height: 24),
            _buildDateNav(provider),
            const SizedBox(height: 12),
            _buildModeToggle(),
            const SizedBox(height: 16),
            _buildTodayBanner(),
            const SizedBox(height: 16),

            if (_logMode == 'mood') ...[
              _buildMoodSection(),
              const SizedBox(height: 32),
              _buildMoodSlider(),
              const SizedBox(height: 32),
              _buildActivitiesSection(),
              const SizedBox(height: 32),
              _buildSymptomsSection(),
            ] else ...[
              _buildSleepSection(),
            ],

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveLog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryContainer,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Log Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────── SHARED WIDGETS ────────────────────────

  Widget _buildDateNav(AppProvider provider) {
    final label = _isToday
        ? 'Today'
        : DateFormat('MMM d, yyyy').format(_selectedDate);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          color: AppTheme.onSurface,
          onPressed: () => _changeDate(-1, provider),
        ),
        Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        IconButton(
          icon: Icon(Icons.chevron_right,
              color: _isToday ? AppTheme.outlineVariant : AppTheme.onSurface),
          onPressed: _isToday ? null : () => _changeDate(1, provider),
        ),
      ],
    );
  }

  Widget _buildTodayBanner() {
    final hasMood = _prevMoodScore > 0;
    final hasSleep = _prevSleepHours > 0;
    if (!hasMood && !hasSleep) return const SizedBox.shrink();
    final parts = <String>[];
    if (hasMood) parts.add('Mood: ${_prevMoodScore.toStringAsFixed(1)}/10');
    if (hasSleep) parts.add('Sleep: ${_prevSleepHours.toStringAsFixed(1)}h');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryFixed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_note, color: AppTheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Updating ${_isToday ? "today's" : DateFormat("MMM d").format(_selectedDate)} entry · ${parts.join('  ·  ')}',
              style: const TextStyle(fontSize: 12, color: AppTheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(color: AppTheme.borderDefault, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: ['mood', 'sleep'].map((mode) {
          final isActive = _logMode == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _logMode = mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isActive ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  mode == 'mood' ? 'Mood' : 'Sleep',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isActive ? AppTheme.primary : AppTheme.outline,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  MOOD TAB
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildMoodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('How are you feeling?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Select your current mood', style: TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant)),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMoodButton('awful', Icons.sentiment_very_dissatisfied, 'Awful', 1.0),
            _buildMoodButton('bad', Icons.sentiment_dissatisfied, 'Bad', 3.0),
            _buildMoodButton('meh', Icons.sentiment_neutral, 'Meh', 5.0),
            _buildMoodButton('good', Icons.sentiment_satisfied, 'Good', 7.5),
            _buildMoodButton('great', Icons.sentiment_very_satisfied, 'Great', 10.0),
          ],
        ),
      ],
    );
  }

  Widget _buildMoodButton(String id, IconData emoji, String label, double defaultScore) {
    final isSelected = _selectedMoodEmoji == id;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedMoodEmoji = id;
        _moodScore = defaultScore;
      }),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryFixed : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? Colors.transparent : AppTheme.outlineVariant),
            ),
            alignment: Alignment.center,
            child: Icon(emoji, size: isSelected ? 32 : 28, color: isSelected ? AppTheme.primary : AppTheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildMoodSlider() {
    final showTransition = _prevMoodScore > 0 && _prevMoodScore != _moodScore;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mood Intensity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        showTransition
            ? RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant),
                  children: [
                    TextSpan(
                        text: _prevMoodScore.toStringAsFixed(1),
                        style: const TextStyle(decoration: TextDecoration.lineThrough)),
                    TextSpan(
                        text: '  →  ${_moodScore.toStringAsFixed(1)} / 10.0',
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            : Text('Score: ${_moodScore.toStringAsFixed(1)} / 10.0',
                style: const TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        Slider(
          value: _moodScore,
          min: 1.0,
          max: 10.0,
          divisions: 90,
          activeColor: AppTheme.primary,
          inactiveColor: AppTheme.surfaceContainer,
          onChanged: (value) {
            setState(() {
              _moodScore = value;
              if (value <= 2.0) {
                _selectedMoodEmoji = 'awful';
              } else if (value <= 4.0) {
                _selectedMoodEmoji = 'bad';
              } else if (value <= 6.0) {
                _selectedMoodEmoji = 'meh';
              } else if (value <= 8.5) {
                _selectedMoodEmoji = 'good';
              } else {
                _selectedMoodEmoji = 'great';
              }
            });
          },
        ),
      ],
    );
  }

  // ─────────────────────────────── ACTIVITIES ────────────────────────────

  Widget _buildActivitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What have you been up to?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderDefault),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._kActivities.map((act) => _buildActivityPill(act)),
                  _buildActivityPill('Others', isOthers: true),
                ],
              ),
              if (_showOthersInput) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _othersController,
                  decoration: InputDecoration(
                    hintText: 'Describe your activity...',
                    hintStyle: TextStyle(color: AppTheme.outline.withValues(alpha: 0.7), fontSize: 14),
                    filled: true,
                    fillColor: AppTheme.surfaceContainer,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityPill(String label, {bool isOthers = false}) {
    final isSelected = _selectedActivities.contains(label);
    return GestureDetector(
      onTap: () => setState(() {
        if (isSelected) {
          _selectedActivities.remove(label);
          if (isOthers) {
            _showOthersInput = false;
            _othersController.clear();
          }
        } else {
          _selectedActivities.add(label);
          if (isOthers) _showOthersInput = true;
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryFixed : AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant,
              ),
            ),
            if (isOthers) ...[
              const SizedBox(width: 4),
              Icon(
                isSelected ? Icons.edit : Icons.add,
                size: 14,
                color: isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────── SYMPTOMS ──────────────────────────────

  Widget _buildSymptomsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Track Symptoms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        // Horizontally scrollable symptom chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _kSymptoms.map((s) {
              final isSelected = _selectedSymptoms.contains(s.name);
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => setState(() {
                    if (isSelected) {
                      _selectedSymptoms.remove(s.name);
                    } else {
                      _selectedSymptoms.add(s.name);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryFixed : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary.withValues(alpha: 0.35) : AppTheme.borderDefault,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(s.icon, size: 18, color: isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(
                          s.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (_selectedSymptoms.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderDefault),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Severity: ${_severityLabel(_symptomSeverity)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                _buildSeverityBar(),
                const SizedBox(height: 16),
                TextField(
                  controller: _symptomNotesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add specific notes about symptoms...',
                    hintStyle: TextStyle(color: AppTheme.outline.withValues(alpha: 0.7), fontSize: 14),
                    filled: true,
                    fillColor: AppTheme.surfaceContainer,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14, color: AppTheme.onSurface),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSeverityBar() {
    return Row(
      children: List.generate(5, (i) {
        final isActive = i < _symptomSeverity;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _symptomSeverity = i + 1),
            child: Padding(
              padding: EdgeInsets.only(right: i < 4 ? 4 : 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.secondary.withValues(alpha: 0.65) : AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  SLEEP TAB
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildSleepSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sleep Log', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
          _sleepInputMode == 'hours'
              ? 'How many hours did you sleep?'
              : 'When did you go to sleep and wake up?',
          style: const TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        _buildSleepInputModeToggle(),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              const Icon(Icons.bedtime, size: 64, color: AppTheme.primary),
              const SizedBox(height: 16),
              if (_prevSleepHours > 0 && _prevSleepHours != _sleepHours)
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(fontFamily: 'Roboto'),
                    children: [
                      TextSpan(
                        text: '${_prevSleepHours.toStringAsFixed(1)}h',
                        style: const TextStyle(fontSize: 22, color: AppTheme.outline, decoration: TextDecoration.lineThrough),
                      ),
                      const TextSpan(text: '  →  ', style: TextStyle(fontSize: 22, color: AppTheme.outline)),
                      TextSpan(
                        text: '${_sleepHours.toStringAsFixed(1)} hrs',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  '${_sleepHours.toStringAsFixed(1)} hrs',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_sleepInputMode == 'hours') ...[
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              // Sleep computed from bedtime/wake-up (time mode) can exceed the
              // 12h slider max, so clamp the *displayed* value to the slider's
              // range. The full value is still what gets saved.
              value: _sleepHours.clamp(0.0, 12.0),
              min: 0.0,
              max: 12.0,
              divisions: 48,
              activeColor: AppTheme.primary,
              inactiveColor: AppTheme.surfaceContainer,
              onChanged: (value) => setState(() => _sleepHours = value),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0h', style: TextStyle(fontSize: 12, color: AppTheme.outline)),
                Text('12h', style: TextStyle(fontSize: 12, color: AppTheme.outline)),
              ],
            ),
          ),
        ] else
          _buildSleepTimePickers(),
        const SizedBox(height: 32),
        _buildSleepQualitySection(),
        const SizedBox(height: 32),
        _buildNightmareSection(),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.surfaceContainerHigh),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _sleepHours < 6.0
                      ? 'Try to get a bit more sleep tonight for better recovery!'
                      : (_sleepHours > 9.0
                          ? 'You got plenty of rest! Ready to tackle the day.'
                          : 'Great job hitting the recommended sleep target!'),
                  style: const TextStyle(fontSize: 14, color: AppTheme.onSurface),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─────────────────── SLEEP INPUT: HOURS vs TIME ───────────────────────

  // Recompute the saved hours from the currently-picked bedtime and wake-up.
  void _syncSleepHoursFromTime() {
    _sleepHours = sleepHoursBetween(
      _bedtime.hour, _bedtime.minute, _wakeTime.hour, _wakeTime.minute,
    ).clamp(0.0, 24.0);
  }

  Future<void> _pickTime({required bool isBedtime}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isBedtime ? _bedtime : _wakeTime,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isBedtime) {
        _bedtime = picked;
      } else {
        _wakeTime = picked;
      }
      _syncSleepHoursFromTime();
    });
  }

  Widget _buildSleepInputModeToggle() {
    return Container(
      decoration: BoxDecoration(color: AppTheme.surfaceContainer, borderRadius: BorderRadius.circular(50)),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          (label: 'By hours', mode: 'hours'),
          (label: 'By time', mode: 'time'),
        ].map((opt) {
          final isActive = _sleepInputMode == opt.mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _sleepInputMode = opt.mode;
                // Entering time mode: make the saved hours match what the
                // pickers currently show, so the readout and the value agree.
                if (opt.mode == 'time') _syncSleepHoursFromTime();
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: isActive
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  opt.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive ? AppTheme.primary : AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSleepTimePickers() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTimeField('Bedtime', Icons.bedtime_outlined, _bedtime,
                  () => _pickTime(isBedtime: true)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTimeField('Wake up', Icons.wb_sunny_outlined, _wakeTime,
                  () => _pickTime(isBedtime: false)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Tap a time to change it — hours are calculated for you.',
          style: TextStyle(fontSize: 12, color: AppTheme.outline.withValues(alpha: 0.9)),
        ),
      ],
    );
  }

  Widget _buildTimeField(String label, IconData icon, TimeOfDay time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderDefault),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              time.format(context),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────── SLEEP QUALITY (segmented pill bar) ────────────────

  Widget _buildSleepQualitySection() {
    // _sleepQuality: 0=unset, 2,4,6,8,10 → index 0-4
    final selectedIdx = _sleepQuality == 0 ? -1 : (_sleepQuality ~/ 2 - 1).clamp(0, 4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sleep Quality', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          selectedIdx >= 0 ? _kSleepQualityLabels[selectedIdx] : 'How restful was your sleep?',
          style: TextStyle(
            fontSize: 14,
            color: selectedIdx >= 0 ? AppTheme.primary : AppTheme.onSurfaceVariant,
            fontWeight: selectedIdx >= 0 ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Row(
            children: List.generate(5, (i) {
              final isSelected = selectedIdx == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _sleepQuality = (i + 1) * 2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: isSelected
                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _kSleepQualityLabels[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────── NIGHTMARE ─────────────────────────────

  Widget _buildNightmareSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dream Experience', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Did you experience any nightmares?', style: TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildDreamChoice(false, Icons.nightlight_round, 'No Nightmares', const Color(0xFF6366F1))),
            const SizedBox(width: 12),
            Expanded(child: _buildDreamChoice(true, Icons.cloud, 'Had Nightmares', AppTheme.error)),
          ],
        ),
      ],
    );
  }

  Widget _buildDreamChoice(bool value, IconData icon, String label, Color color) {
    final isSelected = _hadNightmare == value;
    return GestureDetector(
      onTap: () => setState(() => _hadNightmare = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : AppTheme.outlineVariant, width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : AppTheme.outline, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
