import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/read_aloud_controller.dart';
import '../screens/audio_player_screen.dart';

/// Compact player shown above the navigation bar and in the reader while a document is being read.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, this.showTitle = true});

  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ReadAloudController>();
    if (!c.hasSession) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final doc = c.doc!;
    final subtitle = c.error != null
        ? c.error!
        : c.loading
            ? 'جارٍ تجهيز الصوت…'
            : 'صفحة ${c.page} من ${doc.pageCount} • جملة ${c.index + 1} من ${c.units.length}';
    return Material(
      color: scheme.primaryContainer,
      elevation: 2,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AudioPlayerScreen())),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(
              children: [
                const SizedBox(width: 4),
                Icon(Icons.graphic_eq, color: scheme.onPrimaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showTitle)
                        Text(
                          doc.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer),
                        ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: c.error != null ? scheme.error : scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'الجملة السابقة',
                  onPressed: c.previousSentence,
                  icon: const Icon(Icons.skip_next), // RTL: "previous" points right
                ),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: c.loading
                      ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2.5))
                      : IconButton.filled(
                          tooltip: c.isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
                          onPressed: c.togglePlay,
                          icon: Icon(c.error != null ? Icons.refresh : (c.isPlaying ? Icons.pause : Icons.play_arrow)),
                        ),
                ),
                IconButton(
                  tooltip: 'الجملة التالية',
                  onPressed: c.nextSentence,
                  icon: const Icon(Icons.skip_previous),
                ),
                IconButton(tooltip: 'إيقاف', onPressed: c.stop, icon: const Icon(Icons.close)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
