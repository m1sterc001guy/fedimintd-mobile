import 'dart:convert';
import 'dart:io';

import 'package:fedimintd_mobile/fedimintd.dart';
import 'package:fedimintd_mobile/frb_generated.dart';
import 'package:fedimintd_mobile/lib.dart';
import 'package:fedimintd_mobile/onboarding.dart';
import 'package:fedimintd_mobile/utils.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.init();
  await RustLib.init();
  runApp(const Start());
}

class Start extends StatelessWidget {
  const Start({super.key});

  Future<(BlockchainSource, NetworkType, String)?> _connectionInfo() async {
    try {
      Directory? dir;
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      final file = File('${dir!.path}/fedimintd_mobile/fedimintd_config.json');

      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents);

        NetworkType network;
        switch (json["network"] as String) {
          case "Mutinynet":
            network = NetworkType.mutinynet;
            break;
          case "Regtest":
            network = NetworkType.regtest;
            break;
          case "Mainnet":
            network = NetworkType.mainnet;
            break;
          default:
            return null;
        }

        BlockchainSource source;
        String esploraUrl;
        switch (json["source"] as String) {
          case "esplora":
            source = BlockchainSource.Esplora;
            esploraUrl = json["url"] as String;
            break;
          default:
            return null;
        }

        return (source, network, esploraUrl);
      } else {
        AppLogger.instance.info("No connection info found, starting UI...");
        return null; // file not found
      }
    } catch (e) {
      AppLogger.instance.error("Error getting connection info $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fedimint Setup',
      theme: ThemeData.dark(),
      home: FutureBuilder<(BlockchainSource, NetworkType, String)?>(
        future: _connectionInfo(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(child: Text("Error checking folder")),
            );
          }

          if (snapshot.data != null) {
            return PlatformAwareHome(
              source: snapshot.data!.$1,
              network: snapshot.data!.$2,
              esploraUrl: snapshot.data!.$3,
            );
          } else {
            return const NetworkSelectionScreen();
          }
        },
      ),
    );
  }
}
