import 'package:fedimintd_mobile/main.dart';
import 'package:fedimintd_mobile/onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Screen explaining battery and data requirements before the app starts.
///
/// Shown when the app has not yet been granted battery optimization exemption.
/// The user must acknowledge the disclaimer and grant the exemption to proceed.
class BatteryDisclaimerScreen extends StatelessWidget {
  final VoidCallback onAcknowledged;

  const BatteryDisclaimerScreen({super.key, required this.onAcknowledged});

  Future<void> _onAcknowledge(BuildContext context) async {
    final granted =
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    if (!granted) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Battery optimization exemption is required for this app to function properly.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    onAcknowledged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Guardian')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const FedimintLogo(size: 64),
              const SizedBox(height: 24),
              const Text(
                'Before You Begin',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please review the following requirements',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRequirement(
                        icon: Icons.battery_charging_full,
                        title: 'Battery Intensive',
                        description:
                            'This app runs a background service that must stay active at all times. It is recommended to keep your device plugged into a charger. You will be prompted to grant unrestricted battery usage.',
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      _buildRequirement(
                        icon: Icons.wifi,
                        title: 'Data Intensive',
                        description:
                            'The app continuously communicates with the network. It is recommended to always be connected to WiFi.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _onAcknowledge(context),
                  child: const Text('I Understand'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequirement({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 24, color: AppColors.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
