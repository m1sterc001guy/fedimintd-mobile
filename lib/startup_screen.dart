import 'package:fedimintd_mobile/battery_disclaimer_screen.dart';
import 'package:fedimintd_mobile/foreground_service.dart';
import 'package:fedimintd_mobile/main.dart';
import 'package:fedimintd_mobile/onboarding.dart';
import 'package:fedimintd_mobile/setup_choice_screen.dart';
import 'package:fedimintd_mobile/utils.dart';
import 'package:fedimintd_mobile/webview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

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
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Check battery optimization exemption first
      final isIgnoring =
          await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (!isIgnoring) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (ctx) => BatteryDisclaimerScreen(
                  onAcknowledged: () {
                    Navigator.of(ctx).pushReplacement(
                      MaterialPageRoute(builder: (_) => const StartupScreen()),
                    );
                  },
                ),
          ),
        );
        return;
      }

      final config = await readConfigFile();

      if (!mounted) return;

      if (config == null) {
        // No config found, go to setup choice screen (create new or recover)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SetupChoiceScreen()),
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
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FedimintLogo(size: 64),
                const SizedBox(height: 32),
                const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Startup Error',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Loading state
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FedimintLogo(size: 80),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Loading...',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
