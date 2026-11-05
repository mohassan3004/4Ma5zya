import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../core/constants.dart';
import '../core/errors.dart';
import '../data/file_storage.dart';
import '../data/models.dart';
import '../data/remote/api_client.dart';
import '../data/repositories/voice_repository.dart';
import '../services/tts_service.dart';

enum CloneStep { validating, uploading, saving, done }

class VoicesController extends ChangeNotifier {
  VoicesController(this._repo, this._api, this._tts, this._files);

  final VoiceRepository _repo;
  final ApiClient _api;
  final TtsService _tts;
  final FileStorage _files;

  List<VoiceProfile> voices = [];
  bool loading = true;
  bool syncing = false;
  String? syncError;

  VoiceProfile? get defaultVoice {
    for (final v in voices) {
      if (v.isDefault) return v;
    }
    return null;
  }

  VoiceProfile? byId(String id) {
    for (final v in voices) {
      if (v.voiceId == id) return v;
    }
    return null;
  }

  Future<void> load() async {
    voices = await _repo.all();
    loading = false;
    notifyListeners();
  }

  /// Merges the backend voice list into the local library (requires internet).
  Future<void> sync() async {
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      final remote = await _api.listVoices();
      final remoteIds = <String>{};
      for (final j in remote) {
        final id = j['voice_id'] as String;
        remoteIds.add(id);
        final local = await _repo.byId(id);
        await _repo.upsert(VoiceProfile.fromApi(j, isDefault: local?.isDefault ?? false));
      }
      for (final v in await _repo.all()) {
        if (!remoteIds.contains(v.voiceId) && v.status != 'missing') {
          await _repo.upsert(VoiceProfile.fromMap({...v.toMap(), 'status': 'missing'}));
        }
      }
      await _ensureDefault();
    } catch (e) {
      syncError = errorMessage(e);
    } finally {
      syncing = false;
      await load();
    }
  }

  Future<void> _ensureDefault() async {
    final all = await _repo.all();
    if (all.isEmpty || all.any((v) => v.isDefault)) return;
    final ready = all.where((v) => v.isReady).toList();
    await _repo.setDefault((ready.isNotEmpty ? ready.first : all.first).voiceId);
  }

  /// Local validation before uploading (the backend validates again).
  static String? validateSamples(List<VoiceSample> samples, {bool forNewVoice = true}) {
    if (samples.isEmpty) return 'أضف تسجيلًا صوتيًا واحدًا على الأقل.';
    var knownMs = 0;
    var unknown = 0;
    for (final s in samples) {
      final f = File(s.filePath);
      if (!f.existsSync()) return 'أحد التسجيلات لم يعد موجودًا على الجهاز.';
      final ext = p.extension(s.filePath).replaceFirst('.', '').toLowerCase();
      if (!supportedAudioExtensions.contains(ext)) return 'صيغة الملف ${p.basename(s.filePath)} غير مدعومة.';
      if (f.lengthSync() > maxSampleBytes) return 'حجم الملف ${p.basename(s.filePath)} أكبر من 11 ميغابايت.';
      if (s.durationMs == null) {
        unknown++;
      } else {
        knownMs += s.durationMs!;
      }
    }
    if (forNewVoice && unknown == 0 && knownMs < minTotalSampleSeconds * 1000) {
      return 'مجموع مدة التسجيلات ${(knownMs / 1000).round()} ثانية فقط. '
          'الحد الأدنى $minTotalSampleSeconds ثانية، ويُنصح بدقيقة ونصف أو أكثر لنتيجة أفضل.';
    }
    return null;
  }

  Future<VoiceProfile> create({
    required String name,
    required String consentType,
    required bool consentConfirmed,
    String? consentPerson,
    required List<VoiceSample> samples,
    required void Function(CloneStep step) onStep,
  }) async {
    onStep(CloneStep.validating);
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 60) {
      throw const AppException('اسم الصوت مطلوب ويجب ألا يتجاوز 60 حرفًا.');
    }
    if (!consentConfirmed) {
      throw const AppException('يجب تأكيد الموافقة الصريحة لصاحب الصوت قبل الاستنساخ.');
    }
    final problem = validateSamples(samples);
    if (problem != null) throw AppException(problem, code: 'insufficient_audio');

    onStep(CloneStep.uploading);
    final json = await _api.createVoice(
      name: trimmed,
      consentType: consentType,
      consentConfirmed: consentConfirmed,
      consentPerson: consentPerson,
      samplePaths: samples.map((s) => s.filePath).toList(),
    );

    onStep(CloneStep.saving);
    final isFirst = (await _repo.all()).isEmpty;
    final profile = VoiceProfile.fromApi(json, isDefault: isFirst);
    await _repo.upsert(profile);
    for (final s in samples) {
      await _repo.addSample(VoiceSample(
        voiceId: profile.voiceId,
        filePath: s.filePath,
        durationMs: s.durationMs,
        source: s.source,
        createdAt: s.createdAt,
      ));
    }
    await load();
    onStep(CloneStep.done);
    return byId(profile.voiceId) ?? profile;
  }

  Future<void> addSamples(VoiceProfile voice, List<VoiceSample> samples) async {
    final problem = validateSamples(samples, forNewVoice: false);
    if (problem != null) throw AppException(problem);
    final json = await _api.addSamples(voice.voiceId, samples.map((s) => s.filePath).toList());
    await _repo.upsert(VoiceProfile.fromApi(json, isDefault: voice.isDefault));
    for (final s in samples) {
      await _repo.addSample(VoiceSample(
        voiceId: voice.voiceId,
        filePath: s.filePath,
        durationMs: s.durationMs,
        source: s.source,
        createdAt: s.createdAt,
      ));
    }
    // Improved voice: previously generated audio no longer matches it.
    await _tts.clear(voiceId: voice.voiceId);
    await load();
  }

  Future<VoiceProfile> importExisting({
    required String voiceId,
    required String name,
    required String consentType,
    String? consentPerson,
  }) async {
    final json = await _api.importVoice(
      voiceId: voiceId.trim(),
      name: name.trim(),
      consentType: consentType,
      consentPerson: consentPerson,
    );
    final isFirst = (await _repo.all()).isEmpty;
    final profile = VoiceProfile.fromApi(json, isDefault: isFirst);
    await _repo.upsert(profile);
    await load();
    return profile;
  }

  Future<void> rename(VoiceProfile voice, String name) async {
    final json = await _api.renameVoice(voice.voiceId, name.trim());
    await _repo.upsert(VoiceProfile.fromApi(json, isDefault: voice.isDefault));
    await load();
  }

  Future<void> refreshStatus(VoiceProfile voice) async {
    final json = await _api.getVoice(voice.voiceId);
    await _repo.upsert(VoiceProfile.fromApi(json, isDefault: voice.isDefault));
    await load();
  }

  Future<void> setDefault(VoiceProfile voice) async {
    await _repo.setDefault(voice.voiceId);
    await load();
  }

  /// Deletes the voice at the provider, then all local data for it (samples and cached audio).
  Future<void> delete(VoiceProfile voice, {bool localOnly = false}) async {
    if (!localOnly) await _api.deleteVoice(voice.voiceId);
    for (final s in await _repo.samples(voice.voiceId)) {
      await _files.deleteQuietly(s.filePath);
    }
    await _tts.clear(voiceId: voice.voiceId);
    await _repo.delete(voice.voiceId);
    await _ensureDefault();
    await load();
  }

  Future<List<VoiceSample>> samplesOf(String voiceId) => _repo.samples(voiceId);

  /// Removes a local copy of a recording (the provider keeps what it already received).
  Future<void> deleteLocalSample(VoiceSample sample) async {
    if (sample.id != null) await _repo.deleteSample(sample.id!);
    await _files.deleteQuietly(sample.filePath);
  }
}
