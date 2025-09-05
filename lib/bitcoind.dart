import 'dart:convert';
import 'dart:io';

import 'package:fedimintd_mobile/fedimintd.dart';
import 'package:fedimintd_mobile/lib.dart';
import 'package:fedimintd_mobile/utils.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class BitcoindScreen extends StatefulWidget {
  final NetworkType network;

  const BitcoindScreen({super.key, required this.network});

  @override
  State<BitcoindScreen> createState() => _BitcoindScreenState();
}

class _BitcoindScreenState extends State<BitcoindScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _urlController;
  bool _isTesting = false;
  bool _connectionSuccessful = false;

  @override
  void initState() {
    super.initState();
    String defaultUrl;
    switch (widget.network) {
      case NetworkType.mutinynet:
        defaultUrl = "https://replaceme.com:38332";
        break;
      case NetworkType.mainnet:
        defaultUrl = "https://replaceme.com:8332";
        break;
      case NetworkType.regtest:
        defaultUrl = "http://localhost:18443";
        break;
    }

    _usernameController = TextEditingController(text: "bitcoin");
    _passwordController = TextEditingController(text: "bitcoin");
    _urlController = TextEditingController(text: defaultUrl);
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
    });

    bool success = false;
    try {
      String username = _usernameController.text;
      String password = _passwordController.text;
      String url = _urlController.text;
      await testBitcoind(
        username: username,
        password: password,
        url: url,
        network: widget.network,
      );
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
      "username": _usernameController.text,
      "password": _passwordController.text,
      "url": _urlController.text,
      "source": "bitcoind",
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
              source: BlockchainSource.Bitcoind,
              network: widget.network,
              bitcoindUsername: _usernameController.text,
              bitcoindPassword: _passwordController.text,
              bitcoindUrl: _urlController.text,
            ),
      ),
      (route) => false, // removes everything behind
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bitcoind Configuration")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
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
    );
  }
}
