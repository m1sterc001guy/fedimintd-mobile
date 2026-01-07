import 'package:fedimintd_mobile/blockchain_config.dart';
import 'package:fedimintd_mobile/foreground_service.dart';
import 'package:fedimintd_mobile/lib.dart';
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
              : "Connection failed. Check the URL.",
        ),
        backgroundColor: success ? Colors.green : Colors.red,
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

  /// Builds the test connection button with loading indicator.
  Widget buildTestConnectionButton() {
    return ElevatedButton(
      onPressed: isTesting ? null : handleTestConnection,
      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      child:
          isTesting
              ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
              : const Text("Test Connection"),
    );
  }

  /// Builds the save/start button.
  Widget buildSaveButton() {
    return ElevatedButton(
      onPressed: connectionSuccessful ? startFedimintd : null,
      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      child: const Text("Save Connection Info"),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: Text(appBarTitle)),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              buildFormFields(),
              const Spacer(),
              buildTestConnectionButton(),
              const SizedBox(height: 16),
              buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }
}
