import 'package:carbine/frb_generated.dart';
import 'package:carbine/lib.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  await _fedimintd();
  runApp(const MyApp());
}

Future<void> _fedimintd() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    await startFedimintd(path: dir.path);
  } catch (e) {
    print("Could not start fedimintd: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: WebViewScreen());
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
    // Enable hybrid composition for Android (optional, improves WebView stability)
    // WebView.platform = SurfaceAndroidWebView(); // Uncomment if needed and import

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
