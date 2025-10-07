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

  // yes - this is super ugly
  Future<(BlockchainSource, NetworkType, String?, String?, String?, String?)?>
  _connectionInfo() async {
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

        switch (json["source"] as String) {
          case "esplora":
            BlockchainSource source = BlockchainSource.Esplora;
            String esploraUrl = json["url"] as String;
            return (source, network, esploraUrl, null, null, null);
          case "bitcoind":
            BlockchainSource source = BlockchainSource.Bitcoind;
            String username = json["username"] as String;
            String password = json["password"] as String;
            String url = json["url"] as String;
            return (source, network, null, username, password, url);
          default:
            return null;
        }
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
      home: SafeArea(
        child: FutureBuilder<
          (BlockchainSource, NetworkType, String?, String?, String?, String?)?
        >(
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
              BlockchainSource source = snapshot.data!.$1;
              switch (source) {
                case BlockchainSource.Esplora:
                  return PlatformAwareHome(
                    source: snapshot.data!.$1,
                    network: snapshot.data!.$2,
                    esploraUrl: snapshot.data!.$3,
                  );
                case BlockchainSource.Bitcoind:
                  return PlatformAwareHome(
                    source: snapshot.data!.$1,
                    network: snapshot.data!.$2,
                    bitcoindUsername: snapshot.data!.$4,
                    bitcoindPassword: snapshot.data!.$5,
                    bitcoindUrl: snapshot.data!.$6,
                  );
              }
            } else {
              return const NetworkSelectionScreen();
            }
          },
        ),
      ),
    );
  }
}
