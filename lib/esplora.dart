import 'dart:convert';
import 'dart:io';

import 'package:fedimintd_mobile/fedimintd.dart';
import 'package:fedimintd_mobile/lib.dart';
import 'package:fedimintd_mobile/utils.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:path_provider/path_provider.dart';

// --------------------- Esplora Screen ---------------------
class EsploraScreen extends StatefulWidget {
  final NetworkType network;

  const EsploraScreen({super.key, required this.network});

  @override
  State<EsploraScreen> createState() => _EsploraScreenState();
}

class _EsploraScreenState extends State<EsploraScreen> {
  late TextEditingController _controller;
  bool _isTesting = false;
  bool _connectionSuccessful = false;

  @override
  void initState() {
    super.initState();
    String defaultText = "";
    switch (widget.network) {
      case NetworkType.mutinynet:
        defaultText = "https://mutinynet.com/api";
        break;
      case NetworkType.mainnet:
        defaultText = "https://mempool.space/api";
        break;
      case NetworkType.regtest:
        defaultText = "http://localhost:3000";
        break;
    }
    _controller = TextEditingController(text: defaultText);
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
    });

    bool success = false;
    try {
      String esploraUrl = _controller.text;
      await testEsplora(esploraUrl: esploraUrl, network: widget.network);
      success = true;
    } catch (e) {
      AppLogger.instance.error("Failed to connect to esplora: $e");
    }

    setState(() {
      _isTesting = false;
      _connectionSuccessful = success;
    });

    // Show feedback
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

  void _startFedimintd() async {
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

    String network;
    switch (widget.network) {
      case NetworkType.mutinynet:
        network = "Mutinynet";
        break;
      case NetworkType.mainnet:
        network = "Mainnet";
        break;
      case NetworkType.regtest:
        network = "Regtest";
        break;
    }

    // Prepare JSON data
    final data = {
      "network": network,
      "url": _controller.text,
      "source": "esplora",
    };

    // Get the app documents directory
    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    final file = File('${dir!.path}/fedimintd_mobile/fedimintd_config.json');

    // Write JSON to file
    await file.writeAsString(jsonEncode(data), flush: true);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder:
            (_) => PlatformAwareHome(
              source: BlockchainSource.Esplora,
              network: widget.network,
              esploraUrl: _controller.text,
            ),
      ),
      (route) => false, // removes everything behind
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text("Esplora Configuration")),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: "Esplora API URL",
                  border: OutlineInputBorder(),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _isTesting ? null : _testConnection,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child:
                    _isTesting
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text("Test Connection"),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _connectionSuccessful ? _startFedimintd : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text("Save Connection Info"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
