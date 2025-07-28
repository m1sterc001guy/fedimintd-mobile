import 'dart:io';

import 'package:fedimintd_mobile/frb_generated.dart';
import 'package:fedimintd_mobile/lib.dart';
import 'package:fedimintd_mobile/utils.dart';
import 'package:flutter/material.dart';
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
    //if (Platform.isLinux) {
    if (true) {
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

  @override
  void initState() {
    super.initState();

    _controller =
        WebViewController()
          ..loadRequest(Uri.parse('http://localhost:8175'))
          ..setJavaScriptMode(JavaScriptMode.unrestricted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: WebViewWidget(controller: _controller));
  }
}
