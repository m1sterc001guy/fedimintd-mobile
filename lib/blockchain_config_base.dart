import 'package:fedimintd_mobile/blockchain_config.dart';
import 'package:fedimintd_mobile/foreground_service.dart';
import 'package:fedimintd_mobile/lib.dart';
import 'package:fedimintd_mobile/main.dart';
import 'package:fedimintd_mobile/onboarding.dart';
import 'package:fedimintd_mobile/utils.dart';
import 'package:fedimintd_mobile/webview_screen.dart';
import 'package:flutter/material.dart';

/// Abstract base class for blockchain configuration screens (Esplora, Bitcoind).
///
/// Provides common functionality for testing connections, saving config,
/// and navigating to the main app screen.
abstract class BlockchainConfigScreen extends StatefulWidget {
  final NetworkType network;

  const BlockchainConfigScreen({super.key, required this.network});
}

/// Abstract state class for blockchain configuration screens.
///
/// Subclasses must implement the abstract members to provide
/// source-specific behavior (e.g., Esplora vs Bitcoind).
abstract class BlockchainConfigScreenState<T extends BlockchainConfigScreen>
    extends State<T> {
  bool isTesting = false;
  bool connectionSuccessful = false;

  // ---- Abstract members that subclasses must implement ----

  /// The title shown in the app bar.
  String get appBarTitle;

  /// The name used in log messages (e.g., "esplora", "bitcoind").
  String get sourceName;

  /// Performs the actual connection test. Should throw on failure.
  Future<void> testConnection();

  /// Builds the form fields specific to this blockchain source.
  Widget buildFormFields();

  /// Builds the BlockchainConfig with the current form values.
  BlockchainConfig buildConfig();

  // ---- Shared implementation ----

  /// Handles the test connection flow with loading state and user feedback.
  Future<void> handleTestConnection() async {
    setState(() {
      isTesting = true;
    });

    bool success = false;
    try {
      await testConnection();
      success = true;
    } catch (e) {
      AppLogger.instance.error("Failed to connect to $sourceName: $e");
    }

    setState(() {
      isTesting = false;
      connectionSuccessful = success;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? "Connection successful!"
              : "Connection failed. Please check your settings.",
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      ),
    );
  }

  /// Handles saving config and starting fedimintd.
  Future<void> startFedimintd() async {
    final hasPermission = await requestNotificationPermission();

    if (!hasPermission) {
      AppLogger.instance.warn('Notification permission denied');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification permission required for Fedimintd'),
            margin: EdgeInsets.fromLTRB(16, 0, 16, 80),
          ),
        );
      }
      return;
    }

    final config = buildConfig();

    // Write config to file
    await writeConfigFile(config);

    // Start foreground service
    await startForegroundService(config);

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WebViewScreen()),
      (route) => false,
    );
  }

  /// Builds the test connection button (outlined style).
  Widget buildTestConnectionButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isTesting ? null : handleTestConnection,
        child:
            isTesting
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Text("Test Connection"),
      ),
    );
  }

  /// Builds the save/continue button (filled style).
  Widget buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: connectionSuccessful ? startFedimintd : null,
        child: const Text("Save & Continue"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Logo
              const FedimintLogo(size: 48),
              const SizedBox(height: 24),
              // Title
              Text(
                appBarTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Configure your $sourceName connection",
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Form card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buildFormFields(),
                      const SizedBox(height: 24),
                      buildTestConnectionButton(),
                      const SizedBox(height: 12),
                      buildSaveButton(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
