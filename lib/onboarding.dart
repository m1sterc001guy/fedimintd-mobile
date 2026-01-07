import 'package:fedimintd_mobile/bitcoind.dart';
import 'package:fedimintd_mobile/esplora.dart';
import 'package:fedimintd_mobile/lib.dart';
import 'package:flutter/material.dart';

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

// --------------------- Network Selection ---------------------
class NetworkSelectionScreen extends StatefulWidget {
  const NetworkSelectionScreen({super.key});

  @override
  State<NetworkSelectionScreen> createState() => _NetworkSelectionScreenState();
}

class _NetworkSelectionScreenState extends State<NetworkSelectionScreen> {
  NetworkType? _selectedNetwork;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
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
    return SafeArea(
      child: Scaffold(
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
                                    (_) =>
                                        EsploraScreen(network: widget.network),
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
      ),
    );
  }
}
