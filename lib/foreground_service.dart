import 'package:fedimintd_mobile/blockchain_config.dart';
import 'package:fedimintd_mobile/frb_generated.dart';
import 'package:fedimintd_mobile/lib.dart';
import 'package:fedimintd_mobile/utils.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Task handler for running fedimintd in the foreground service.
class FedimintdTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await AppLogger.init();
    await RustLib.init();

    AppLogger.instance.info("FedimintdTaskHandler onStart (starter: $starter)");

    final source = await FlutterForegroundTask.getData<String>(key: 'source');
    final networkName = await FlutterForegroundTask.getData<String>(
      key: 'network',
    );
    final dirPath = await FlutterForegroundTask.getData<String>(key: 'dirPath');

    if (source == null || networkName == null || dirPath == null) {
      AppLogger.instance.warn(
        'Missing required foreground task data: source=$source, network=$networkName, dirPath=$dirPath',
      );
      return;
    }

    AppLogger.instance.info(
      "source: $source, network: $networkName, dirPath: $dirPath",
    );

    final network = NetworkType.values.byName(networkName);

    switch (source) {
      case 'esplora':
        final url = await FlutterForegroundTask.getData<String>(key: 'url');
        if (url == null) {
          AppLogger.instance.warn(
            'Missing esplora url in foreground task data',
          );
          return;
        }
        AppLogger.instance.info("Starting fedimintd with Esplora: $url");
        await startFedimintdEsplora(
          dbPath: dirPath,
          networkType: network,
          esploraUrl: url,
        );
        break;
      case 'bitcoind':
        final username = await FlutterForegroundTask.getData<String>(
          key: 'username',
        );
        final password = await FlutterForegroundTask.getData<String>(
          key: 'password',
        );
        final url = await FlutterForegroundTask.getData<String>(key: 'url');
        if (username == null || password == null || url == null) {
          AppLogger.instance.warn(
            'Missing bitcoind credentials in foreground task data: username=$username, password=${password != null ? "[set]" : "null"}, url=$url',
          );
          return;
        }
        AppLogger.instance.info("Starting fedimintd with Bitcoind: $url");
        await startFedimintdBitcoind(
          dbPath: dirPath,
          networkType: network,
          username: username,
          password: password,
          url: url,
        );
        break;
      default:
        AppLogger.instance.warn('Unknown blockchain source: $source');
        return;
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    AppLogger.instance.warn(
      'FedimintdTaskHandler onDestroy called at $timestamp - service is being destroyed',
    );
  }
}

/// Top-level callback function for foreground task.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
void startFedimintdCallback() {
  FlutterForegroundTask.setTaskHandler(FedimintdTaskHandler());
}

/// Initialize and start the foreground service with the given config.
Future<void> startForegroundService(BlockchainConfig config) async {
  final dir = await getConfigDirectory();

  AppLogger.instance.info('Starting Fedimintd Foreground Service...');

  // Request battery optimization exemption if not already granted
  final isIgnoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
  if (!isIgnoring) {
    AppLogger.instance.info('Requesting battery optimization exemption...');
    final granted =
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    AppLogger.instance.info('Battery optimization exemption granted: $granted');
  }

  // Save config data to foreground task storage
  await config.saveToForegroundTask(dir.path);

  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'fedimintd_foreground_service',
      channelName: 'Fedimintd Foreground Service',
      channelDescription: 'Keeps Fedimintd alive in the background',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      autoRunOnBoot: true,
      autoRunOnMyPackageReplaced: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  final result = await FlutterForegroundTask.startService(
    serviceId: 256,
    notificationTitle: 'Fedimintd Active',
    notificationText: 'Running federated ecash mint',
    callback: startFedimintdCallback,
  );

  AppLogger.instance.info('Foreground service start result: $result');
}

/// Stop the foreground service.
Future<void> stopForegroundService() async {
  await FlutterForegroundTask.stopService();
}
