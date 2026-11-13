import 'package:flutter_test/flutter_test.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:workhub_mobile/core/updater/app_updater_service.dart';

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
}
