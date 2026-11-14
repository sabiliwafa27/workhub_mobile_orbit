import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:workhub_mobile/core/updater/app_updater_service.dart';

class _ReleaseAdapter implements HttpClientAdapter {
  final String tagName;

  _ReleaseAdapter(this.tagName);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final payload = {
      'tag_name': tagName,
      'body': 'Release $tagName',
      'assets': [
        {
          'name': 'app-release.apk',
          'browser_download_url': 'https://example.com/app-release.apk',
        }
      ],
    };
    return ResponseBody.fromString(jsonEncode(payload), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}

class _Shorebird implements ShorebirdUpdater {
  @override
  bool isAvailable;
  UpdateStatus status;
  Patch? current;
  Patch? next;
  int updates = 0;

  _Shorebird(
      {this.isAvailable = true,
      this.status = UpdateStatus.upToDate,
      this.current,
      this.next});

  @override
  Future<UpdateStatus> checkForUpdate({UpdateTrack? track}) async => status;
  @override
  Future<void> update({UpdateTrack? track}) async {
    updates++;
  }

  @override
  Future<Patch?> readCurrentPatch() async => current;
  @override
  Future<Patch?> readNextPatch() async => next;
}

void main() {
  test('returns unavailable for ordinary Flutter builds', () async {
    final shorebird = _Shorebird(isAvailable: false);
    expect(
        await AppUpdaterService(shorebirdUpdater: shorebird)
            .checkForShorebirdUpdate(),
        ShorebirdUpdateResult.unavailable);
    expect(shorebird.updates, 0);
  });

  test('reports patches that are downloaded for the next app launch', () async {
    final shorebird = _Shorebird(
        status: UpdateStatus.outdated,
        current: const Patch(number: 1),
        next: const Patch(number: 2));
    expect(
        await AppUpdaterService(shorebirdUpdater: shorebird)
            .checkForShorebirdUpdate(),
        ShorebirdUpdateResult.downloaded);
    expect(shorebird.updates, 1);
  });

  test('reports an already downloaded patch without downloading twice',
      () async {
    final shorebird = _Shorebird(
        status: UpdateStatus.restartRequired,
        current: const Patch(number: 1),
        next: const Patch(number: 2));
    expect(
        await AppUpdaterService(shorebirdUpdater: shorebird)
            .checkForShorebirdUpdate(),
        ShorebirdUpdateResult.restartRequired);
    expect(shorebird.updates, 0);
  });

  test('resolveInstalledVersion aligns legacy and tag-based builds', () {
    expect(AppUpdaterService.resolveInstalledVersion('1.0.44', '44'), '1.0.44');
    expect(AppUpdaterService.resolveInstalledVersion('1.0.0', '44'), '1.0.44');
    expect(AppUpdaterService.resolveInstalledVersion('1.0.0', '1'), '1.0.0');
  });

  test('checkForUpdate reports up-to-date for tag-aligned and legacy builds',
      () async {
    final dio = Dio()..httpClientAdapter = _ReleaseAdapter('v1.0.44');

    final tagAligned = await AppUpdaterService(
      dio: dio,
      versionLoader: () async => (version: '1.0.44', buildNumber: '44'),
    ).checkForUpdate();
    expect(tagAligned, isNotNull);
    expect(tagAligned!.hasUpdate, isFalse);
    expect(tagAligned.tagName, '1.0.44');

    final legacyBuild = await AppUpdaterService(
      dio: dio,
      versionLoader: () async => (version: '1.0.0', buildNumber: '44'),
    ).checkForUpdate();
    expect(legacyBuild, isNotNull);
    expect(legacyBuild!.hasUpdate, isFalse);
  });

  test('checkForUpdate reports update available when remote tag is newer',
      () async {
    final dio = Dio()..httpClientAdapter = _ReleaseAdapter('v1.0.45');
    final release = await AppUpdaterService(
      dio: dio,
      versionLoader: () async => (version: '1.0.44', buildNumber: '44'),
    ).checkForUpdate();

    expect(release, isNotNull);
    expect(release!.hasUpdate, isTrue);
    expect(release.tagName, '1.0.45');
  });
}
