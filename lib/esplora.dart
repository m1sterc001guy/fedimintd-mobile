import 'package:fedimintd_mobile/blockchain_config_base.dart';
import 'package:fedimintd_mobile/fedimintd.dart';
import 'package:fedimintd_mobile/lib.dart';
import 'package:fedimintd_mobile/utils.dart';
import 'package:flutter/material.dart';

class EsploraScreen extends BlockchainConfigScreen {
  const EsploraScreen({super.key, required super.network});

  @override
  State<EsploraScreen> createState() => _EsploraScreenState();
}

class _EsploraScreenState extends BlockchainConfigScreenState<EsploraScreen> {
  late TextEditingController _controller;

  @override
  String get appBarTitle => "Esplora Configuration";

  @override
  BlockchainSource get blockchainSource => BlockchainSource.Esplora;

  @override
  String get sourceName => "esplora";

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _getDefaultUrl());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getDefaultUrl() {
    switch (widget.network) {
      case NetworkType.mutinynet:
        return "https://mutinynet.com/api";
      case NetworkType.mainnet:
        return "https://mempool.space/api";
      case NetworkType.regtest:
        return "http://localhost:3000";
    }
  }

  @override
  Future<void> testConnection() async {
    await testEsplora(esploraUrl: _controller.text, network: widget.network);
  }

  @override
  Map<String, dynamic> buildConfigData() {
    return {
      "network": widget.network.displayName,
      "url": _controller.text,
      "source": "esplora",
    };
  }

  @override
  PlatformAwareHome buildPlatformAwareHome() {
    return PlatformAwareHome(
      source: BlockchainSource.Esplora,
      network: widget.network,
      esploraUrl: _controller.text,
    );
  }

  @override
  Widget buildFormFields() {
    return TextField(
      controller: _controller,
      decoration: const InputDecoration(
        labelText: "Esplora API URL",
        border: OutlineInputBorder(),
      ),
    );
  }
}
