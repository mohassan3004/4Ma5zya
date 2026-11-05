import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../data/models.dart';

class DocumentTile extends StatelessWidget {
  const DocumentTile({super.key, required this.doc, required this.onTap, this.onMore});

  final DocumentEntity doc;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onMore,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.picture_as_pdf_outlined, color: scheme.primary, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            doc.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                          ),
                        ),
                        if (doc.isFavorite) Icon(Icons.star_rounded, color: scheme.secondary, size: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${doc.pageCount} صفحة • ${formatBytes(doc.fileSize)}'
                      '${doc.category != null ? ' • ${doc.category}' : ''}',
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(value: doc.progress, minHeight: 5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(formatPercent(doc.progress), style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              if (onMore != null)
                IconButton(onPressed: onMore, icon: const Icon(Icons.more_vert), tooltip: 'خيارات'),
            ],
          ),
        ),
      ),
    );
  }
}
