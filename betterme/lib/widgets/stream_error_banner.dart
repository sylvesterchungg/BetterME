import 'package:flutter/material.dart';
import '../theme.dart';

/// Tells the user that a background data stream has failed, so the figures on
/// screen are the last ones received rather than the current ones.
///
/// Deliberately knows nothing about AppProvider or Firestore — it takes the
/// message and the retry callback — so it can be widget tested on its own.
class StreamErrorBanner extends StatelessWidget {
  const StreamErrorBanner({
    super.key,
    required this.summary,
    required this.onRetry,
  });

  final String summary;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(12),
            color: AppTheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, size: 20, color: AppTheme.outline),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const Text(
                          'Showing the last data received.',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  TextButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
