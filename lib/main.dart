import 'dart:io';

import 'package:fedimintd_mobile/frb_generated.dart';
import 'package:fedimintd_mobile/lib.dart';
import 'package:fedimintd_mobile/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.init();
  await RustLib.init();
  _fedimintd();
  runApp(const MyApp());
}

const platform = MethodChannel('io.fedimintd/settings');

Future<void> openBatterySettings() async {
  try {
    await platform.invokeMethod('openBatterySettings');
  } on PlatformException catch (e) {
    print("Failed to open battery settings: ${e.message}");
  }
}

Future<void> enableBackgroundExecution(BuildContext context) async {
  final androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: "Fedimint",
    notificationText: "fedimintd is running in the background",
    notificationImportance: AndroidNotificationImportance.normal,
    enableWifiLock: true,
  );

  final hasPermissions = await FlutterBackground.hasPermissions;

  if (!hasPermissions) {
    if (context.mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text("Permission Required"),
              content: const Text(
                "This app needs background execution permissions to keep fedimintd running when minimized. "
                "Please check your system settings or battery optimization.",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    openBatterySettings(); // 👈 open system settings
                  },
                  child: const Text("Open Settings"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
              ],
            ),
      );
    }
    return;
  }

  final success = await FlutterBackground.initialize(
    androidConfig: androidConfig,
  );
  if (success) {
    await FlutterBackground.enableBackgroundExecution();
  }
}

Future<void> _fedimintd() async {
  try {
    final dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }

    AppLogger.instance.info("Starting fedimintd with directory: ${dir!.path}");
    await startFedimintd(path: dir.path);
  } catch (e) {
    print("Could not start fedimintd: $e");
    AppLogger.instance.error("Could not start fedimintd: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: PlatformAwareHome());
  }
}

class PlatformAwareHome extends StatefulWidget {
  const PlatformAwareHome({super.key});

  @override
  State<PlatformAwareHome> createState() => _PlatformAwareHomeState();
}

class _PlatformAwareHomeState extends State<PlatformAwareHome> {
  final Uri _url = Uri.parse('http://localhost:8175');

  @override
  void initState() {
    super.initState();

    if (Platform.isLinux) {
      // On Linux, open default browser immediately and show instructions
      _launchInBrowser();
    } else {
      enableBackgroundExecution(context);
    }
  }

  Future<void> _launchInBrowser() async {
    print("Launching $_url in browser...");
    if (!await launchUrl(_url, mode: LaunchMode.externalApplication)) {
      print('Could not launch $_url');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isLinux) {
      return Scaffold(
        appBar: AppBar(title: const Text('Open in Browser')),
        body: Center(
          child: Text(
            'Please open your web browser and visit:\n\n$_url',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
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
    return Scaffold(
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
    );
  }
}
