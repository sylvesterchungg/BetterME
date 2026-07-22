/// A short, digestible AI wellness insight (FR_405/FR_406). Cached in Firestore
/// so the dashboard loads instantly and Gemini is only called when the user's
/// recent data actually changes (or the cache is older than a day).
class AIInsight {
  /// e.g. "Positive Sleep-Productivity Link"
  final String correlationType;

  /// One encouraging sentence, e.g. "Sufficient sleep is driving your focus."
  final String headline;

  /// 1-2 plain-language sentences grounded in the user's own numbers.
  final String breakdown;

  /// One gentle, specific, non-judgmental suggestion.
  final String nudge;

  /// Fingerprint of the 7-day data window this insight was generated from.
  /// When the live data's signature differs, the insight is regenerated.
  final String dataSignature;

  /// When this insight was produced (used for the 24-hour freshness check).
  final DateTime generatedAt;

  AIInsight({
    required this.correlationType,
    required this.headline,
    required this.breakdown,
    required this.nudge,
    this.dataSignature = '',
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  bool get isEmpty => headline.isEmpty && breakdown.isEmpty && nudge.isEmpty;

  /// Parses the raw JSON returned by Gemini (snake_case keys).
  factory AIInsight.fromJson(Map<String, dynamic> json) => AIInsight(
        correlationType: (json['correlation_type'] ?? '').toString().trim(),
        headline: (json['headline_insight'] ?? '').toString().trim(),
        breakdown: (json['detailed_breakdown'] ?? '').toString().trim(),
        nudge: (json['actionable_nudge'] ?? '').toString().trim(),
      );

  /// Reads back a cached insight from Firestore.
  factory AIInsight.fromMap(Map<String, dynamic> map) => AIInsight(
        correlationType: (map['correlationType'] ?? '').toString(),
        headline: (map['headline'] ?? '').toString(),
        breakdown: (map['breakdown'] ?? '').toString(),
        nudge: (map['nudge'] ?? '').toString(),
        dataSignature: (map['dataSignature'] ?? '').toString(),
        generatedAt: DateTime.tryParse((map['generatedAt'] ?? '').toString()),
      );

  Map<String, dynamic> toMap() => {
        'correlationType': correlationType,
        'headline': headline,
        'breakdown': breakdown,
        'nudge': nudge,
        'dataSignature': dataSignature,
        'generatedAt': generatedAt.toIso8601String(),
      };

  AIInsight copyWith({String? dataSignature, DateTime? generatedAt}) =>
      AIInsight(
        correlationType: correlationType,
        headline: headline,
        breakdown: breakdown,
        nudge: nudge,
        dataSignature: dataSignature ?? this.dataSignature,
        generatedAt: generatedAt ?? this.generatedAt,
      );
}

/// A single calming coping action suggested by the AI.
class AICopingTip {
  final String title; // short action, e.g. "Wind-down routine"
  final String detail; // one supportive sentence explaining how

  const AICopingTip({required this.title, required this.detail});

  factory AICopingTip.fromMap(Map<String, dynamic> map) => AICopingTip(
        title: (map['title'] ?? '').toString().trim(),
        detail: (map['detail'] ?? '').toString().trim(),
      );

  Map<String, dynamic> toMap() => {'title': title, 'detail': detail};
}

/// AI-generated coping support shown when rough days (nightmares, symptoms,
/// low mood) cluster in the recent logs. Gentle, non-clinical self-care ideas.
class AICopingTips {
  /// One warm sentence acknowledging the rough patch.
  final String intro;

  /// 2-3 tailored coping actions.
  final List<AICopingTip> tips;

  /// Fingerprint of the rough-day content this was generated for.
  final String signature;

  /// When it was produced (for the freshness check).
  final DateTime generatedAt;

  AICopingTips({
    required this.intro,
    required this.tips,
    this.signature = '',
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  bool get isEmpty => tips.isEmpty;

  /// Parses the raw JSON returned by Gemini (snake_case keys).
  factory AICopingTips.fromJson(Map<String, dynamic> json) {
    final rawTips = (json['tips'] as List?) ?? const [];
    return AICopingTips(
      intro: (json['intro'] ?? '').toString().trim(),
      tips: rawTips
          .whereType<Map>()
          .map((m) => AICopingTip.fromMap(Map<String, dynamic>.from(m)))
          .where((t) => t.title.isNotEmpty || t.detail.isNotEmpty)
          .toList(),
    );
  }

  /// Reads back cached coping tips from Firestore.
  factory AICopingTips.fromMap(Map<String, dynamic> map) {
    final rawTips = (map['tips'] as List?) ?? const [];
    return AICopingTips(
      intro: (map['intro'] ?? '').toString(),
      tips: rawTips
          .whereType<Map>()
          .map((m) => AICopingTip.fromMap(Map<String, dynamic>.from(m)))
          .toList(),
      signature: (map['signature'] ?? '').toString(),
      generatedAt: DateTime.tryParse((map['generatedAt'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toMap() => {
        'intro': intro,
        'tips': tips.map((t) => t.toMap()).toList(),
        'signature': signature,
        'generatedAt': generatedAt.toIso8601String(),
      };

  AICopingTips copyWith({String? signature, DateTime? generatedAt}) =>
      AICopingTips(
        intro: intro,
        tips: tips,
        signature: signature ?? this.signature,
        generatedAt: generatedAt ?? this.generatedAt,
      );
}

/// One-line personalized "good morning" tip for the dashboard, built from last
/// night's sleep/mood + today's task load. Cached like [AIInsight]/[AICopingTips]
/// so it loads instantly and only calls Gemini when its inputs change.
class MorningNudge {
  /// The single friendly sentence shown to the user.
  final String text;

  /// Fingerprint of the inputs it was built from (see nudgeSignatureFor).
  final String signature;

  /// When it was produced (for the freshness check).
  final DateTime generatedAt;

  MorningNudge({required this.text, this.signature = '', DateTime? generatedAt})
      : generatedAt = generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  bool get isEmpty => text.isEmpty;

  /// Parses the raw JSON returned by Gemini.
  factory MorningNudge.fromJson(Map<String, dynamic> json) =>
      MorningNudge(text: (json['nudge'] ?? '').toString().trim());

  /// Reads back a cached nudge from Firestore.
  factory MorningNudge.fromMap(Map<String, dynamic> map) => MorningNudge(
        text: (map['text'] ?? '').toString(),
        signature: (map['signature'] ?? '').toString(),
        generatedAt: DateTime.tryParse((map['generatedAt'] ?? '').toString()),
      );

  Map<String, dynamic> toMap() => {
        'text': text,
        'signature': signature,
        'generatedAt': generatedAt.toIso8601String(),
      };

  MorningNudge copyWith({String? signature, DateTime? generatedAt}) =>
      MorningNudge(
        text: text,
        signature: signature ?? this.signature,
        generatedAt: generatedAt ?? this.generatedAt,
      );
}
