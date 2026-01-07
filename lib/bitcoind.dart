import 'package:fedimintd_mobile/blockchain_config_base.dart';
import 'package:fedimintd_mobile/fedimintd.dart';
import 'package:fedimintd_mobile/lib.dart';
import 'package:fedimintd_mobile/utils.dart';
import 'package:flutter/material.dart';

class BitcoindScreen extends BlockchainConfigScreen {
  const BitcoindScreen({super.key, required super.network});

  @override
  State<BitcoindScreen> createState() => _BitcoindScreenState();
}

class _BitcoindScreenState extends BlockchainConfigScreenState<BitcoindScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _urlController;

  @override
  String get appBarTitle => "Bitcoind Configuration";

  @override
  BlockchainSource get blockchainSource => BlockchainSource.Bitcoind;

  @override
  String get sourceName => "bitcoind";

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: "bitcoin");
    _passwordController = TextEditingController(text: "bitcoin");
    _urlController = TextEditingController(text: _getDefaultUrl());
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  String _getDefaultUrl() {
    switch (widget.network) {
      case NetworkType.mutinynet:
        return "https://replaceme.com:38332";
      case NetworkType.mainnet:
        return "https://replaceme.com:8332";
      case NetworkType.regtest:
        return "http://localhost:18443";
    }
  }

  @override
  Future<void> testConnection() async {
    await testBitcoind(
      username: _usernameController.text,
      password: _passwordController.text,
      url: _urlController.text,
      network: widget.network,
    );
  }

  @override
  Map<String, dynamic> buildConfigData() {
    return {
      "network": widget.network.displayName,
      "username": _usernameController.text,
      "password": _passwordController.text,
      "url": _urlController.text,
      "source": "bitcoind",
    };
  }

  @override
  PlatformAwareHome buildPlatformAwareHome() {
    return PlatformAwareHome(
      source: BlockchainSource.Bitcoind,
      network: widget.network,
      bitcoindUsername: _usernameController.text,
      bitcoindPassword: _passwordController.text,
      bitcoindUrl: _urlController.text,
    );
  }

  @override
  Widget buildFormFields() {
    return Column(
      children: [
        TextField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: "Username",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          decoration: const InputDecoration(
            labelText: "Password",
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: "Bitcoind URL",
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
