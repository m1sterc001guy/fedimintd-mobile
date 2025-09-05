import 'dart:io';

import 'package:fedimintd_mobile/lib.dart';
import 'package:fedimintd_mobile/utils.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum BlockchainSource { Esplora, Bitcoind }

class PlatformAwareHome extends StatefulWidget {
  final BlockchainSource source;
  final NetworkType network;
  final String? esploraUrl;
  const PlatformAwareHome({
    super.key,
    required this.source,
    required this.network,
    this.esploraUrl,
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
      print("Could not start fedimintd: $e");
      AppLogger.instance.error("Could not start fedimintd: $e");
    }
  }

  @override
  void initState() {
    super.initState();

    switch (widget.source) {
      case BlockchainSource.Esplora:
        _fedimintdEsplora(widget.network, widget.esploraUrl!);
        break;
      case BlockchainSource.Bitcoind:
        AppLogger.instance.info("Bitcoind not supported yet");
        break;
    }

    if (Platform.isLinux) {
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
