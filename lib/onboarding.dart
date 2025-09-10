import 'dart:io';

import 'package:fedimintd_mobile/bitcoind.dart';
import 'package:fedimintd_mobile/esplora.dart';
import 'package:fedimintd_mobile/lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background/flutter_background.dart';

class Onboarding extends StatelessWidget {
  const Onboarding({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fedimint Setup',
      theme: ThemeData.dark(),
      home: const NetworkSelectionScreen(),
    );
  }
}

// --------------------- Selection Card ---------------------
class SelectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool isSelected;

  const SelectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color:
              isSelected
                  ? theme.colorScheme.primary.withOpacity(0.1)
                  : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 32, color: theme.colorScheme.secondary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}

const platform = MethodChannel('org.fedimint.mobile/settings');

Future<void> openBatterySettings() async {
  try {
    await platform.invokeMethod('openBatterySettings');
  } on PlatformException catch (e) {
    print("Failed to open battery settings: ${e.message}");
  }
}

Future<bool> enableBackgroundExecution(BuildContext context) async {
  final androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: "Fedimint",
    notificationText: "fedimintd is running in the background",
    notificationImportance: AndroidNotificationImportance.normal,
    enableWifiLock: true,
  );

  final hasPermissions = await FlutterBackground.hasPermissions;

  if (!hasPermissions) {
    if (context.mounted) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              title: const Text("Background Permission Required"),
              content: const Text(
                "This app needs permission to run in the background in order to function. "
                "Please enable background execution or exit.",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: const Text("Exit"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                    openBatterySettings();
                  },
                  child: const Text("Open Settings"),
                ),
              ],
            ),
      );

      if (result != true) {
        // Exit the app if the user chooses "Exit" or dismisses
        exit(0);
      }
    }
    return false;
  }

  final initialized = await FlutterBackground.initialize(
    androidConfig: androidConfig,
  );
  if (initialized) {
    await FlutterBackground.enableBackgroundExecution();
    return true;
  }

  return false;
}

// --------------------- Network Selection ---------------------
class NetworkSelectionScreen extends StatefulWidget {
  const NetworkSelectionScreen({super.key});

  @override
  State<NetworkSelectionScreen> createState() => _NetworkSelectionScreenState();
}

class _NetworkSelectionScreenState extends State<NetworkSelectionScreen> {
  NetworkType? _selectedNetwork;

  @override
  void initState() {
    super.initState();

    if (!Platform.isLinux) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        enableBackgroundExecution(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Network")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SelectionCard(
              icon: Icons.public,
              title: "Mutinynet",
              description: "Test network for experimenting.",
              isSelected: _selectedNetwork == NetworkType.mutinynet,
              onTap: () {
                setState(() => _selectedNetwork = NetworkType.mutinynet);
              },
            ),
            const SizedBox(height: 12),
            SelectionCard(
              icon: Icons.link,
              title: "Regtest",
              description: "Local network used for testing.",
              isSelected: _selectedNetwork == NetworkType.regtest,
              onTap: () {
                setState(() => _selectedNetwork = NetworkType.regtest);
              },
            ),
            const SizedBox(height: 12),
            SelectionCard(
              icon: Icons.link,
              title: "Mainnet",
              description: "Setup a guardian on the Bitcoin network.",
              isSelected: _selectedNetwork == NetworkType.mainnet,
              onTap: () {
                setState(() => _selectedNetwork = NetworkType.mainnet);
              },
            ),
            const Spacer(),
            ElevatedButton(
              onPressed:
                  _selectedNetwork == null
                      ? null
                      : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => BackendSelectionScreen(
                                  network: _selectedNetwork!,
                                ),
                          ),
                        );
                      },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text("Next"),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------- Backend Selection ---------------------
class BackendSelectionScreen extends StatefulWidget {
  final NetworkType network;
  const BackendSelectionScreen({super.key, required this.network});

  @override
  State<BackendSelectionScreen> createState() => _BackendSelectionScreenState();
}

class _BackendSelectionScreenState extends State<BackendSelectionScreen> {
  String? _selectedBackend;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Backend")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SelectionCard(
              icon: Icons.cloud,
              title: "Esplora",
              description: "Use Esplora API for blockchain data.",
              isSelected: _selectedBackend == "Esplora",
              onTap: () {
                setState(() => _selectedBackend = "Esplora");
              },
            ),
            const SizedBox(height: 12),
            SelectionCard(
              icon: Icons.storage,
              title: "Bitcoind",
              description: "Use your own full Bitcoin node backend.",
              isSelected: _selectedBackend == "Bitcoind",
              onTap: () {
                setState(() => _selectedBackend = "Bitcoind");
              },
            ),
            const Spacer(),
            ElevatedButton(
              onPressed:
                  _selectedBackend == null
                      ? null
                      : () {
                        if (_selectedBackend == "Esplora") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => EsploraScreen(network: widget.network),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) =>
                                      BitcoindScreen(network: widget.network),
                            ),
                          );
                        }
                      },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text("Next"),
            ),
          ],
        ),
      ),
    );
  }
}
