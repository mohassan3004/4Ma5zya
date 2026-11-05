import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Bridges the reading player to the OS media session: background playback, notification
/// and lock-screen controls (play / pause / previous sentence / next sentence / stop).
class ReaderAudioHandler extends BaseAudioHandler with SeekHandler {
  ReaderAudioHandler() {
    player.playbackEventStream.map(_transform).pipe(playbackState);
  }

  final AudioPlayer player = AudioPlayer();

  Future<void> Function()? onPlay;
  Future<void> Function()? onPause;
  Future<void> Function()? onStop;
  Future<void> Function()? onNext;
  Future<void> Function()? onPrevious;

  @override
  Future<void> play() async {
    final cb = onPlay;
    if (cb != null) {
      await cb();
    } else {
      await player.play();
    }
  }

  @override
  Future<void> pause() async {
    final cb = onPause;
    if (cb != null) {
      await cb();
    } else {
      await player.pause();
    }
  }

  @override
  Future<void> stop() async {
    final cb = onStop;
    if (cb != null) {
      await cb();
    } else {
      await player.stop();
    }
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() async {
    await onNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    await onPrevious?.call();
  }

  PlaybackState _transform(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek, MediaAction.skipToNext, MediaAction.skipToPrevious},
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      playing: player.playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
    );
  }
}
