import 'package:fedimintd_mobile/bitcoind.dart';
import 'package:fedimintd_mobile/esplora.dart';
import 'package:fedimintd_mobile/lib.dart';
import 'package:fedimintd_mobile/main.dart';
import 'package:flutter/material.dart';

/// Reusable Fedimint logo widget
class FedimintLogo extends StatelessWidget {
  final double size;

  const FedimintLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/fedimint-icon.png',
      width: size,
      height: size,
    );
  }
}

/// Selection card widget for choosing options (network, backend, etc.)
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color:
              isSelected ? AppColors.primary.withAlpha(25) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? AppColors.primary.withAlpha(25)
                        : AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
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
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 24,
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
    return Scaffold(
      appBar: AppBar(title: const Text("Setup Guardian")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Logo
              const FedimintLogo(size: 64),
              const SizedBox(height: 24),
              // Title
              const Text(
                "Select Network",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Choose which Bitcoin network to connect to",
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Selection cards in a card container
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      SelectionCard(
                        icon: Icons.science,
                        title: "Mutinynet",
                        description: "Test network for experimenting safely.",
                        isSelected: _selectedNetwork == NetworkType.mutinynet,
                        onTap: () {
                          setState(
                            () => _selectedNetwork = NetworkType.mutinynet,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      SelectionCard(
                        icon: Icons.developer_mode,
                        title: "Regtest",
                        description: "Local network for development testing.",
                        isSelected: _selectedNetwork == NetworkType.regtest,
                        onTap: () {
                          setState(
                            () => _selectedNetwork = NetworkType.regtest,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      SelectionCard(
                        icon: Icons.currency_bitcoin,
                        title: "Mainnet",
                        description: "Live Bitcoin network. Use with caution.",
                        isSelected: _selectedNetwork == NetworkType.mainnet,
                        onTap: () {
                          setState(
                            () => _selectedNetwork = NetworkType.mainnet,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Next button
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
                child: const Text("Next"),
              ),
              const SizedBox(height: 24),
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
    return Scaffold(
      appBar: AppBar(title: const Text("Setup Guardian")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Logo
              const FedimintLogo(size: 64),
              const SizedBox(height: 24),
              // Title
              const Text(
                "Select Backend",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Choose your blockchain data source",
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Selection cards in a card container
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      SelectionCard(
                        icon: Icons.cloud,
                        title: "Esplora",
                        description: "Use an Esplora API for blockchain data.",
                        isSelected: _selectedBackend == "Esplora",
                        onTap: () {
                          setState(() => _selectedBackend = "Esplora");
                        },
                      ),
                      const SizedBox(height: 12),
                      SelectionCard(
                        icon: Icons.dns,
                        title: "Bitcoind",
                        description: "Connect to your own Bitcoin full node.",
                        isSelected: _selectedBackend == "Bitcoind",
                        onTap: () {
                          setState(() => _selectedBackend = "Bitcoind");
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Next button
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
                child: const Text("Next"),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
