import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme.dart';

class DailyLogTab extends StatefulWidget {
  const DailyLogTab({super.key});

  @override
  State<DailyLogTab> createState() => _DailyLogTabState();
}

class _DailyLogTabState extends State<DailyLogTab> {
  // Mode Selection: 'mood' or 'sleep'
  String _logMode = 'mood';

  // Mood State
  String? _selectedMoodEmoji;
  double _moodScore = 5.0; // Slider value 1.0 to 10.0
  final Set<String> _selectedActivities = {};
  final Map<String, bool> _symptoms = {
    'Headache': false,
    'Fatigue': false,
    'Anxiety': false,
    'Pain': false,
  };

  // Sleep State
  double _sleepHours = 7.0; // Slider value 0.0 to 24.0


  void _toggleActivity(String activity) {
    setState(() {
      if (_selectedActivities.contains(activity)) {
        _selectedActivities.remove(activity);
      } else {
        _selectedActivities.add(activity);
      }
    });
  }

  Future<void> _saveLog() async {
    final provider = context.read<AppProvider>();

    // Check if a log for today already exists
    final now = DateTime.now();
    LogEntry? existingLog;
    try {
      existingLog = provider.logs.firstWhere((log) {
        return log.date.year == now.year &&
               log.date.month == now.month &&
               log.date.day == now.day;
      });
    } catch (e) {
      existingLog = null;
    }

    if (existingLog != null) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Log Already Exists'),
          content: const Text('You have already logged data for today. Would you like to update the existing log or add a new separate entry?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executeSaveLog(provider, false, null);
              },
              child: const Text('Add New'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executeSaveLog(provider, true, existingLog);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      );
    } else {
      await _executeSaveLog(provider, false, null);
    }
  }

  Future<void> _executeSaveLog(AppProvider provider, bool isUpdate, LogEntry? existingLog) async {
    final notes = 'Logged via ${_logMode == 'mood' ? 'Mood' : 'Sleep'} tab';

    final activeSymptoms = _symptoms.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    // Only overwrite the dimension belonging to the current mode; preserve the
    // other dimension (and its associated fields) from the existing log so that
    // logging sleep doesn't wipe out a previously recorded mood, and vice-versa.
    final double finalMoodScore =
        _logMode == 'mood' ? _moodScore : (existingLog?.moodScore ?? 0.0);
    final double finalSleepHours =
        _logMode == 'sleep' ? _sleepHours : (existingLog?.sleepHours ?? 0.0);

    // emotions/trigger are mood-only inputs; keep prior values when logging sleep
    final List<String> finalEmotions =
        _logMode == 'mood' ? activeSymptoms : (existingLog?.emotions ?? const []);
    final String finalTrigger = _logMode == 'mood'
        ? _selectedActivities.join(', ')
        : (existingLog?.trigger ?? '');

    final entry = LogEntry(
      id: existingLog?.id ?? '',
      date: DateTime.now(),
      sleepHours: finalSleepHours,
      moodScore: finalMoodScore,
      emotions: finalEmotions,
      notes: notes,
      trigger: finalTrigger,
    );

    if (isUpdate) {
      await provider.updateLog(entry);
    } else {
      await provider.addLog(entry);
    }

    _showSuccessSnackbar();
  }

  void _showSuccessSnackbar() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_logMode entry saved successfully!'),
          backgroundColor: AppTheme.primary,
        ),
      );

      // Optionally reset state
      if (_logMode == 'mood') {
        setState(() {
          _selectedMoodEmoji = null;
          _moodScore = 5.0;
          _selectedActivities.clear();
          _symptoms.updateAll((key, value) => false);
        });
      } else if (_logMode == 'sleep') {
        setState(() {
          _sleepHours = 7.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModeToggle(),
            const SizedBox(height: 32),

            if (_logMode == 'mood') ...[
              _buildMoodSection(),
              const SizedBox(height: 32),
              _buildMoodSlider(),
              const SizedBox(height: 32),
              _buildActivitiesSection(),
              const SizedBox(height: 32),
              _buildSymptomsSection(),
            ] else if (_logMode == 'sleep') ...[
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _logMode = 'mood'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _logMode == 'mood' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _logMode == 'mood'
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Mood',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _logMode == 'mood' ? AppTheme.primary : AppTheme.outline,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _logMode = 'sleep'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _logMode == 'sleep' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _logMode == 'sleep'
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Sleep',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _logMode == 'sleep' ? AppTheme.primary : AppTheme.outline,
                  ),
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }

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
              border: Border.all(
                color: isSelected ? Colors.transparent : AppTheme.outlineVariant,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(emoji, size: isSelected ? 32 : 28, color: isSelected ? Colors.white : AppTheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildMoodSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mood Intensity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Score: ${_moodScore.toStringAsFixed(1)} / 10.0', style: const TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant)),
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
              // Auto-update emoji based on slider
              if (value <= 2.0) {
                _selectedMoodEmoji = 'awful';
              } else if (value <= 4.0) _selectedMoodEmoji = 'bad';
              else if (value <= 6.0) _selectedMoodEmoji = 'meh';
              else if (value <= 8.5) _selectedMoodEmoji = 'good';
              else _selectedMoodEmoji = 'great';
            });
          },
        ),
      ],
    );
  }

  Widget _buildActivitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What have you been up to?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildActivityChip('Work', Icons.work),
              _buildActivityChip('Family', Icons.family_restroom),
              _buildActivityChip('Friends', Icons.group),
              _buildActivityChip('Hobbies', Icons.palette),
              _buildActivityChip('Diet', Icons.restaurant),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityChip(String label, IconData icon) {
    final isSelected = _selectedActivities.contains(label);

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => _toggleActivity(label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? Colors.white : AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSymptomsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Symptoms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildSymptomRow('Headache', Icons.headset_off),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _buildSymptomRow('Fatigue', Icons.bolt),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _buildSymptomRow('Anxiety', Icons.psychology),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _buildSymptomRow('Pain', Icons.warning),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSymptomRow(String symptom, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(symptom, style: const TextStyle(fontSize: 16, color: AppTheme.onSurface)),
            ],
          ),
          Switch(
            value: _symptoms[symptom] ?? false,
            onChanged: (value) {
              setState(() {
                _symptoms[symptom] = value;
              });
            },
            activeThumbColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }

  // --- SLEEP LOG UI ---
  Widget _buildSleepSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sleep Log', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('How many hours did you sleep?', style: TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant)),
        const SizedBox(height: 48),

        Center(
          child: Column(
            children: [
              const Icon(Icons.bedtime, size: 64, color: AppTheme.primary),
              const SizedBox(height: 16),
              Text(
                '${_sleepHours.toStringAsFixed(1)} hrs',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),

        Slider(
          value: _sleepHours,
          min: 0.0,
          max: 12.0,
          divisions: 48, // 30 min intervals
          activeColor: AppTheme.primary,
          inactiveColor: AppTheme.surfaceContainer,
          onChanged: (value) {
            setState(() {
              _sleepHours = value;
            });
          },
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

        const SizedBox(height: 48),
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
      ],
    );
  }

}
