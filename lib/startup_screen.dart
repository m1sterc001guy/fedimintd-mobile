import 'package:fedimintd_mobile/foreground_service.dart';
import 'package:fedimintd_mobile/onboarding.dart';
import 'package:fedimintd_mobile/utils.dart';
import 'package:fedimintd_mobile/webview_screen.dart';
import 'package:flutter/material.dart';

/// Startup screen that handles config loading and service initialization.
///
/// If a valid config exists, starts the foreground service and navigates
/// to the WebView. Otherwise, navigates to the onboarding flow.
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final config = await readConfigFile();

      if (!mounted) return;

      if (config == null) {
        // No config found, go to onboarding
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const NetworkSelectionScreen()),
        );
        return;
      }

      // Start foreground service and navigate to webview
      await startForegroundService(config);

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WebViewScreen()),
      );
    } catch (e) {
      AppLogger.instance.error('Startup failed: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to start: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Fallback (should not reach here)
    return const Scaffold(body: Center(child: Text('Initializing...')));
  }
}
