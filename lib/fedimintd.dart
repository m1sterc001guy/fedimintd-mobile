import 'dart:io';

import 'package:fedimintd_mobile/frb_generated.dart';
import 'package:fedimintd_mobile/lib.dart';
import 'package:fedimintd_mobile/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum BlockchainSource { Esplora, Bitcoind }

class FedimintdTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await AppLogger.init();
    await RustLib.init();

    AppLogger.instance.info("TaskHandler onStart");
    String? network = await FlutterForegroundTask.getData<String>(
      key: 'network',
    );
    String? esploraUrl = await FlutterForegroundTask.getData<String>(
      key: 'esploraUrl',
    );
    String? dirPath = await FlutterForegroundTask.getData<String>(
      key: 'dirPath',
    );
    AppLogger.instance.info("network: $network");
    AppLogger.instance.info("esploraUrl: $esploraUrl");
    AppLogger.instance.info("dirPath: $dirPath");
    NetworkType networkType = NetworkType.values.byName(network!);
    AppLogger.instance.info("parsed network type: $networkType");

    AppLogger.instance.info(
      "TaskHandler retrieved data. Starting fedimintd in esplora mode...",
    );
    await startFedimintdEsplora(
      dbPath: dirPath!,
      networkType: networkType,
      esploraUrl: esploraUrl!,
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

// Top-level callback function for foreground task
@pragma('vm:entry-point')
void startFedimintdCallback() {
  FlutterForegroundTask.setTaskHandler(FedimintdTaskHandler());
}

class PlatformAwareHome extends StatefulWidget {
  final BlockchainSource source;
  final NetworkType network;
  final String? esploraUrl;
  final String? bitcoindUsername;
  final String? bitcoindPassword;
  final String? bitcoindUrl;
  const PlatformAwareHome({
    super.key,
    required this.source,
    required this.network,
    this.esploraUrl,
    this.bitcoindUsername,
    this.bitcoindPassword,
    this.bitcoindUrl,
  });

  @override
  State<PlatformAwareHome> createState() => _PlatformAwareHomeState();
}

class _PlatformAwareHomeState extends State<PlatformAwareHome> {
  final Uri _url = Uri.parse('http://localhost:8175');

  Future<void> _fedimintdEsplora(NetworkType network, String esploraUrl) async {
    try {
      final Directory? dir;
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      AppLogger.instance.info(
        "Starting fedimintd with directory: ${dir!.path} Esplora URL: $esploraUrl",
      );
      await startFedimintdEsplora(
        dbPath: dir.path,
        networkType: network,
        esploraUrl: esploraUrl,
      );
    } catch (e) {
      AppLogger.instance.error("Could not start fedimintd using esplora: $e");
    }
  }

  Future<void> _fedimintdBitcoind(
    NetworkType network,
    String username,
    String password,
    String url,
  ) async {
    try {
      final Directory? dir;
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      AppLogger.instance.info(
        "Starting fedimintd with directory: ${dir!.path} Bitcoind URL: $url",
      );
      await startFedimintdBitcoind(
        dbPath: dir.path,
        networkType: network,
        username: username,
        password: password,
        url: url,
      );
    } catch (e) {
      AppLogger.instance.error("Could not start fedimintd using bitcoind: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _startForegroundService(
    NetworkType network,
    String esploraUrl,
    String dirPath,
  ) async {
    AppLogger.instance.info('Starting Fedimintd Foreground Service...');

    await FlutterForegroundTask.saveData(key: 'network', value: network.name);
    await FlutterForegroundTask.saveData(key: 'esploraUrl', value: esploraUrl);
    await FlutterForegroundTask.saveData(key: 'dirPath', value: dirPath);

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
      ),
    );

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Fedimintd Active',
      notificationText: 'Running federated ecash mint',
      callback: startFedimintdCallback,
    );
  }

  Future<void> _stopForegroundService() async {
    await FlutterForegroundTask.stopService();
  }

  Future<void> _initialize() async {
    final Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }

    switch (widget.source) {
      case BlockchainSource.Esplora:
        //AppLogger.instance.info("PlatformHomeAware started with ESPLORA");
        //_fedimintdEsplora(widget.network, widget.esploraUrl!);
        await _startForegroundService(
          widget.network,
          widget.esploraUrl!,
          dir!.path,
        );
        break;
      case BlockchainSource.Bitcoind:
        AppLogger.instance.info("PlatformHomeAware started with BITCOIND");
        _fedimintdBitcoind(
          widget.network,
          widget.bitcoindUsername!,
          widget.bitcoindPassword!,
          widget.bitcoindUrl!,
        );
        break;
    }

    if (Platform.isLinux) {
      _launchInBrowser();
    }
  }

  Future<void> _launchInBrowser() async {
    await Future.delayed(const Duration(seconds: 1));
    AppLogger.instance.info("Launching $_url in browser...");
    if (!await launchUrl(_url, mode: LaunchMode.externalApplication)) {
      AppLogger.instance.error('Could not launch $_url');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isLinux) {
      return SafeArea(
        child: Scaffold(
          appBar: AppBar(title: const Text('Open in Browser')),
          body: Center(
            child: Text(
              'Please open your web browser and visit:\n\n$_url',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
      );
    } else {
      // On non-Linux, show WebView
      return const WebViewScreen();
    }
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = false;
  bool _refreshTriggered = false;

  @override
  void initState() {
    super.initState();

    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (_) {
                setState(() => _isLoading = true);
              },
              onPageFinished: (_) {
                setState(() => _isLoading = false);
                if (_refreshTriggered) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Refreshed dashboard')),
                  );
                  _refreshTriggered = false;
                }
              },
            ),
          )
          ..loadRequest(Uri.parse('http://localhost:8175'));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(""),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _refreshTriggered = true;
                _controller.reload();
              },
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
              ),
          ],
        ),
      ),
    );
  }
}
