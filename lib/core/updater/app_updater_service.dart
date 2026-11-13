import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

enum ShorebirdUpdateResult { unavailable, upToDate, downloaded, restartRequired, failed }

class ReleaseInfo {
  final String tagName;
  final String apkDownloadUrl;
  final String releaseNotes;
  final bool hasUpdate;

  ReleaseInfo({
    required this.tagName,
    required this.apkDownloadUrl,
    required this.releaseNotes,
    required this.hasUpdate,
  });
}

class AppUpdaterService {
  static const String repoOwner = 'sabiliwafa27';
  static const String repoName = 'workhub_mobile_orbit';

  final Dio _dio = Dio();
  final ShorebirdUpdater _shorebird;

  AppUpdaterService({ShorebirdUpdater? shorebirdUpdater}) : _shorebird = shorebirdUpdater ?? ShorebirdUpdater();

  Future<ShorebirdUpdateResult> checkForShorebirdUpdate() async {
    if (!_shorebird.isAvailable) return ShorebirdUpdateResult.unavailable;
    try {
      final status = await _shorebird.checkForUpdate();
      if (status == UpdateStatus.restartRequired) return ShorebirdUpdateResult.restartRequired;
      if (status != UpdateStatus.outdated) return ShorebirdUpdateResult.upToDate;
      await _shorebird.update();
      final nextPatch = await _shorebird.readNextPatch();
      final currentPatch = await _shorebird.readCurrentPatch();
      return nextPatch?.number != currentPatch?.number ? ShorebirdUpdateResult.downloaded : ShorebirdUpdateResult.upToDate;
    } on UpdateException {
      return ShorebirdUpdateResult.failed;
    } catch (_) {
      return ShorebirdUpdateResult.failed;
    }
  }

  Future<ReleaseInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. 1.0.0

      final response = await _dio.get(
        'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
        options: Options(
          headers: {'Accept': 'application/vnd.github.v3+json'},
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        return null;
      }

      final data = response.data;
      final tagName = (data['tag_name'] as String? ?? '').replaceAll('v', '');
      final body = data['body'] as String? ?? '';
      final assets = (data['assets'] as List<dynamic>?) ?? [];

      String? apkUrl;
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk') && name.contains('release')) {
          apkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      if (apkUrl == null && assets.isNotEmpty) {
        apkUrl = assets.first['browser_download_url'] as String?;
      }

      if (apkUrl == null) return null;

      final hasUpdate = _isNewerVersion(currentVersion, tagName);

      return ReleaseInfo(
        tagName: tagName,
        apkDownloadUrl: apkUrl,
        releaseNotes: body,
        hasUpdate: hasUpdate,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isNewerVersion(String current, String remote) {
    try {
      final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final rParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final c = i < cParts.length ? cParts[i] : 0;
        final r = i < rParts.length ? rParts[i] : 0;
        if (r > c) return true;
        if (r < c) return false;
      }
      return false;
    } catch (_) {
      return current != remote;
    }
  }

  Future<void> downloadAndInstall({
    required String downloadUrl,
    required void Function(double progress) onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final savePath = '${tempDir.path}/workhub_update.apk';

    final file = File(savePath);
    if (await file.exists()) {
      await file.delete();
    }

    await _dio.download(
      downloadUrl,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress(received / total);
        }
      },
    );

    // Launch Android native package installer
    await OpenFilex.open(
      savePath,
      type: 'application/vnd.android.package-archive',
    );
  }
}
