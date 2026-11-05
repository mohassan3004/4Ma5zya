class DocumentEntity {
  const DocumentEntity({
    required this.id,
    required this.title,
    required this.filePath,
    required this.fileSize,
    required this.pageCount,
    required this.lastPage,
    required this.lastSentence,
    required this.isFavorite,
    required this.addedAt,
    this.category,
    this.lastOpenedAt,
  });

  final String id;
  final String title;
  final String filePath;
  final int fileSize;
  final int pageCount;
  final int lastPage;
  final int lastSentence;
  final String? category;
  final bool isFavorite;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;

  double get progress => pageCount <= 0 ? 0 : (lastPage / pageCount).clamp(0.0, 1.0);

  factory DocumentEntity.fromMap(Map<String, Object?> m) => DocumentEntity(
        id: m['id']! as String,
        title: m['title']! as String,
        filePath: m['file_path']! as String,
        fileSize: m['file_size']! as int,
        pageCount: m['page_count']! as int,
        lastPage: m['last_page']! as int,
        lastSentence: m['last_sentence']! as int,
        category: m['category'] as String?,
        isFavorite: (m['is_favorite']! as int) == 1,
        addedAt: DateTime.fromMillisecondsSinceEpoch(m['added_at']! as int),
        lastOpenedAt: m['last_opened_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['last_opened_at']! as int),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'file_path': filePath,
        'file_size': fileSize,
        'page_count': pageCount,
        'last_page': lastPage,
        'last_sentence': lastSentence,
        'category': category,
        'is_favorite': isFavorite ? 1 : 0,
        'added_at': addedAt.millisecondsSinceEpoch,
        'last_opened_at': lastOpenedAt?.millisecondsSinceEpoch,
      };

  DocumentEntity copyWith({
    String? title,
    int? lastPage,
    int? lastSentence,
    String? category,
    bool clearCategory = false,
    bool? isFavorite,
    DateTime? lastOpenedAt,
  }) =>
      DocumentEntity(
        id: id,
        title: title ?? this.title,
        filePath: filePath,
        fileSize: fileSize,
        pageCount: pageCount,
        lastPage: lastPage ?? this.lastPage,
        lastSentence: lastSentence ?? this.lastSentence,
        category: clearCategory ? null : (category ?? this.category),
        isFavorite: isFavorite ?? this.isFavorite,
        addedAt: addedAt,
        lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      );
}

class Bookmark {
  const Bookmark({
    required this.id,
    required this.docId,
    required this.page,
    required this.createdAt,
    this.note,
  });

  final int id;
  final String docId;
  final int page;
  final String? note;
  final DateTime createdAt;

  factory Bookmark.fromMap(Map<String, Object?> m) => Bookmark(
        id: m['id']! as int,
        docId: m['doc_id']! as String,
        page: m['page']! as int,
        note: m['note'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
      );
}

class VoiceProfile {
  const VoiceProfile({
    required this.voiceId,
    required this.name,
    required this.provider,
    required this.status,
    required this.consentType,
    required this.createdAt,
    required this.isDefault,
    required this.sampleCount,
    this.consentPerson,
    this.totalSeconds,
  });

  final String voiceId;
  final String name;
  final String provider;
  final String status;
  final String consentType;
  final String? consentPerson;
  final DateTime createdAt;
  final bool isDefault;
  final int sampleCount;
  final double? totalSeconds;

  bool get isReady => status == 'ready';
  bool get isOwnVoice => consentType == 'self';

  String get statusLabel {
    switch (status) {
      case 'ready':
        return 'جاهز';
      case 'requires_verification':
        return 'بانتظار التحقق لدى المزود';
      case 'processing':
        return 'قيد المعالجة';
      case 'missing':
        return 'غير موجود لدى المزود';
      default:
        return status;
    }
  }

  factory VoiceProfile.fromMap(Map<String, Object?> m) => VoiceProfile(
        voiceId: m['voice_id']! as String,
        name: m['name']! as String,
        provider: m['provider']! as String,
        status: m['status']! as String,
        consentType: m['consent_type']! as String,
        consentPerson: m['consent_person'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
        isDefault: (m['is_default']! as int) == 1,
        sampleCount: m['sample_count']! as int,
        totalSeconds: (m['total_seconds'] as num?)?.toDouble(),
      );

  /// Builds a profile from the backend JSON representation.
  factory VoiceProfile.fromApi(Map<String, dynamic> j, {bool isDefault = false}) => VoiceProfile(
        voiceId: j['voice_id'] as String,
        name: j['name'] as String,
        provider: j['provider'] as String? ?? 'elevenlabs',
        status: j['status'] as String? ?? 'ready',
        consentType: j['consent_type'] as String? ?? 'self',
        consentPerson: j['consent_person'] as String?,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
        isDefault: isDefault,
        sampleCount: (j['sample_count'] as num?)?.toInt() ?? 0,
        totalSeconds: (j['total_seconds'] as num?)?.toDouble(),
      );

  Map<String, Object?> toMap() => {
        'voice_id': voiceId,
        'name': name,
        'provider': provider,
        'status': status,
        'consent_type': consentType,
        'consent_person': consentPerson,
        'created_at': createdAt.millisecondsSinceEpoch,
        'is_default': isDefault ? 1 : 0,
        'sample_count': sampleCount,
        'total_seconds': totalSeconds,
      };
}

class VoiceSample {
  const VoiceSample({
    required this.filePath,
    required this.source,
    required this.createdAt,
    this.id,
    this.voiceId,
    this.durationMs,
  });

  final int? id;
  final String? voiceId;
  final String filePath;
  final int? durationMs;
  final String source; // 'recorded' | 'imported'
  final DateTime createdAt;

  Duration? get duration => durationMs == null ? null : Duration(milliseconds: durationMs!);

  factory VoiceSample.fromMap(Map<String, Object?> m) => VoiceSample(
        id: m['id'] as int?,
        voiceId: m['voice_id'] as String?,
        filePath: m['file_path']! as String,
        durationMs: m['duration_ms'] as int?,
        source: m['source']! as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'voice_id': voiceId,
        'file_path': filePath,
        'duration_ms': durationMs,
        'source': source,
        'created_at': createdAt.millisecondsSinceEpoch,
      };
}

class SearchHit {
  const SearchHit({required this.page, required this.snippet});
  final int page;
  final String snippet;
}
