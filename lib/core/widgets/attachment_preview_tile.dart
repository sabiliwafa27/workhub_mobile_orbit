import 'package:flutter/material.dart';
import '../constants/api_constants.dart';
import '../theme/orbit_theme.dart';

/// Reusable helper to resolve attachment URLs with the current host origin.
String resolveAttachmentUrl(String? url, {String? baseUrl}) {
  if (url == null || url.trim().isEmpty) return '';
  final trimmed = url.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  final base = (baseUrl != null && baseUrl.isNotEmpty)
      ? baseUrl.replaceAll(RegExp(r'/+$'), '')
      : ApiConstants.defaultBaseUrl;
  final relative = trimmed.startsWith('/') ? trimmed : '/$trimmed';
  return '$base$relative';
}

/// Checks if a file name or URL represents an image.
bool isImageFile(String? nameOrUrl, {String? mimeType}) {
  if (mimeType != null && mimeType.toLowerCase().startsWith('image/')) {
    return true;
  }
  if (nameOrUrl == null || nameOrUrl.isEmpty) return false;
  final clean = nameOrUrl.split('?').first.split('#').first.toLowerCase();
  return clean.endsWith('.png') ||
      clean.endsWith('.jpg') ||
      clean.endsWith('.jpeg') ||
      clean.endsWith('.gif') ||
      clean.endsWith('.webp') ||
      clean.endsWith('.bmp') ||
      clean.endsWith('.heic') ||
      clean.endsWith('.svg');
}

/// Formats byte sizes into human-readable strings.
String formatFileSize(dynamic size) {
  if (size == null) return '';
  final num? bytes = size is num ? size : num.tryParse(size.toString());
  if (bytes == null || bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// A full-featured interactive popup dialog for viewing an image attachment with pinch-to-zoom.
void showImagePreviewDialog(
  BuildContext context, {
  required String imageUrl,
  String? title,
  String? subtitle,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.88),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Zoomable / Pannable Image
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    final expected = loadingProgress.expectedTotalBytes;
                    final loaded = loadingProgress.cumulativeBytesLoaded;
                    final progress = (expected != null && expected > 0)
                        ? loaded / expected
                        : null;
                    return Center(
                      child: CircularProgressIndicator(
                        value: progress,
                        color: Colors.white,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.broken_image_rounded,
                            size: 48, color: Colors.white70),
                        SizedBox(height: 12),
                        Text(
                          'Unable to load image',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Header with Title / Subtitle & Close button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (title != null && title.isNotEmpty)
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (subtitle != null && subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 26),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Attachment preview card widget that renders thumbnail for images or file-type badge for other documents.
/// Clicking an image opens the image popup dialog.
class AttachmentPreviewTile extends StatelessWidget {
  final String fileName;
  final String? url;
  final dynamic size;
  final String? mimeType;
  final VoidCallback? onTap;

  const AttachmentPreviewTile({
    super.key,
    required this.fileName,
    this.url,
    this.size,
    this.mimeType,
    this.onTap,
  });

  factory AttachmentPreviewTile.fromMap(
    Map<dynamic, dynamic> map, {
    VoidCallback? onTap,
  }) {
    final name = (map['original_name'] ??
            map['file_name'] ??
            map['name'] ??
            map['filename'] ??
            'Attachment')
        .toString();
    final url = (map['url'] ??
            map['file_url'] ??
            map['path'] ??
            map['download_url'] ??
            map['link'])
        ?.toString();
    final size = map['size'] ?? map['file_size'];
    final mime = (map['mime_type'] ?? map['content_type'])?.toString();

    return AttachmentPreviewTile(
      fileName: name,
      url: url,
      size: size,
      mimeType: mime,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isImg = isImageFile(fileName, mimeType: mimeType) ||
        (url != null && isImageFile(url, mimeType: mimeType));
    final resolvedUrl = resolveAttachmentUrl(url);
    final formattedSize = formatFileSize(size);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (onTap != null) {
            onTap!();
            return;
          }
          if (isImg && resolvedUrl.isNotEmpty) {
            showImagePreviewDialog(
              context,
              imageUrl: resolvedUrl,
              title: fileName,
              subtitle: formattedSize.isNotEmpty ? formattedSize : null,
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: OrbitColors.scaffoldBackground.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: OrbitColors.cardBorder),
          ),
          child: Row(
            children: [
              // Preview Thumbnail or Icon
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 44,
                  height: 44,
                  color: OrbitColors.bubbleBlue,
                  child: isImg && resolvedUrl.isNotEmpty
                      ? Image.network(
                          resolvedUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(
                              Icons.image_outlined,
                              color: OrbitColors.primaryNavy,
                              size: 22,
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            _fileIcon(fileName),
                            color: OrbitColors.primaryNavy,
                            size: 22,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // File Name and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: OrbitColors.textNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (isImg) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: OrbitColors.primaryNavy.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'IMAGE',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: OrbitColors.primaryNavy,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (formattedSize.isNotEmpty)
                          Text(
                            formattedSize,
                            style: const TextStyle(
                              fontSize: 11,
                              color: OrbitColors.textSecondary,
                            ),
                          )
                        else if (!isImg)
                          Text(
                            _fileExtensionLabel(fileName),
                            style: const TextStyle(
                              fontSize: 11,
                              color: OrbitColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action indicator
              if (isImg)
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: OrbitColors.bubbleBlue.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: OrbitColors.primaryNavy,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _fileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return Icons.description_outlined;
    }
    if (lower.endsWith('.xls') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.csv')) {
      return Icons.table_chart_outlined;
    }
    if (lower.endsWith('.zip') || lower.endsWith('.rar') || lower.endsWith('.7z')) {
      return Icons.folder_zip_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  static String _fileExtensionLabel(String name) {
    final dot = name.lastIndexOf('.');
    if (dot != -1 && dot < name.length - 1) {
      return name.substring(dot + 1).toUpperCase();
    }
    return 'DOCUMENT';
  }
}
