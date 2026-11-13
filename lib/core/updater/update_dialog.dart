import 'package:flutter/material.dart';
import '../theme/erp_colors.dart';
import 'app_updater_service.dart';

class UpdateDialog extends StatefulWidget {
  final ReleaseInfo releaseInfo;

  const UpdateDialog({super.key, required this.releaseInfo});

  static Future<void> showIfAvailable(BuildContext context) async {
    final updater = AppUpdaterService();
    final release = await updater.checkForUpdate();
    if (release != null && release.hasUpdate && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => UpdateDialog(releaseInfo: release),
      );
    }
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final AppUpdaterService _updater = AppUpdaterService();
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _errorMessage;

  void _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
    });

    try {
      await _updater.downloadAndInstall(
        downloadUrl: widget.releaseInfo.apkDownloadUrl,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Download failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ErpColors.lightBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.system_update_rounded,
              color: ErpColors.primaryNavy,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Update Available',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: ErpColors.primaryNavy,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Version ${widget.releaseInfo.tagName} is now available.',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          if (widget.releaseInfo.releaseNotes.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ErpColors.scaffoldBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ErpColors.border),
              ),
              child: Text(
                widget.releaseInfo.releaseNotes,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: ErpColors.textSecondary),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (_isDownloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 8,
                backgroundColor: ErpColors.lightBlue,
                valueColor: const AlwaysStoppedAnimation(ErpColors.primaryNavy),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${(_progress * 100).toInt()}% Downloading...',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ErpColors.primaryNavy),
              ),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 12, color: ErpColors.danger),
            ),
          ],
        ],
      ),
      actions: [
        if (!_isDownloading) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later', style: TextStyle(color: ErpColors.textSecondary)),
          ),
          FilledButton(
            onPressed: _startUpdate,
            style: FilledButton.styleFrom(
              backgroundColor: ErpColors.primaryNavy,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update Now'),
          ),
        ],
      ],
    );
  }
}
