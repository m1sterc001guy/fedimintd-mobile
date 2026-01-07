import 'package:fedimintd_mobile/lib.dart';
import 'package:fedimintd_mobile/utils.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Sealed class representing blockchain backend configuration.
///
/// Each subclass encapsulates its own data, JSON serialization,
/// and foreground task data storage.
sealed class BlockchainConfig {
  final NetworkType network;

  const BlockchainConfig({required this.network});

  /// The source identifier used in JSON config (e.g., 'esplora', 'bitcoind').
  String get sourceId;

  /// Convert to JSON for persistence.
  Map<String, dynamic> toJson();

  /// Save config data to foreground task storage.
  Future<void> saveToForegroundTask(String dirPath);

  /// Parse from JSON. Returns null if invalid.
  static BlockchainConfig? fromJson(Map<String, dynamic> json) {
    final networkStr = json['network'] as String?;
    final source = json['source'] as String?;

    if (networkStr == null || source == null) return null;

    final network = _parseNetworkType(networkStr);
    if (network == null) return null;

    switch (source) {
      case 'esplora':
        final url = json['url'] as String?;
        if (url == null) return null;
        return EsploraConfig(network: network, url: url);
      case 'bitcoind':
        final username = json['username'] as String?;
        final password = json['password'] as String?;
        final url = json['url'] as String?;
        if (username == null || password == null || url == null) return null;
        return BitcoindConfig(
          network: network,
          username: username,
          password: password,
          url: url,
        );
      default:
        return null;
    }
  }

  static NetworkType? _parseNetworkType(String value) {
    switch (value) {
      case 'Mutinynet':
        return NetworkType.mutinynet;
      case 'Mainnet':
        return NetworkType.mainnet;
      case 'Regtest':
        return NetworkType.regtest;
      default:
        return null;
    }
  }
}

/// Configuration for Esplora blockchain backend.
class EsploraConfig extends BlockchainConfig {
  final String url;

  const EsploraConfig({required super.network, required this.url});

  @override
  String get sourceId => 'esplora';

  @override
  Map<String, dynamic> toJson() => {
    'network': network.displayName,
    'source': sourceId,
    'url': url,
  };

  @override
  Future<void> saveToForegroundTask(String dirPath) async {
    await FlutterForegroundTask.saveData(key: 'source', value: sourceId);
    await FlutterForegroundTask.saveData(key: 'network', value: network.name);
    await FlutterForegroundTask.saveData(key: 'url', value: url);
    await FlutterForegroundTask.saveData(key: 'dirPath', value: dirPath);
  }
}

/// Configuration for Bitcoind blockchain backend.
class BitcoindConfig extends BlockchainConfig {
  final String username;
  final String password;
  final String url;

  const BitcoindConfig({
    required super.network,
    required this.username,
    required this.password,
    required this.url,
  });

  @override
  String get sourceId => 'bitcoind';

  @override
  Map<String, dynamic> toJson() => {
    'network': network.displayName,
    'source': sourceId,
    'username': username,
    'password': password,
    'url': url,
  };

  @override
  Future<void> saveToForegroundTask(String dirPath) async {
    await FlutterForegroundTask.saveData(key: 'source', value: sourceId);
    await FlutterForegroundTask.saveData(key: 'network', value: network.name);
    await FlutterForegroundTask.saveData(key: 'username', value: username);
    await FlutterForegroundTask.saveData(key: 'password', value: password);
    await FlutterForegroundTask.saveData(key: 'url', value: url);
    await FlutterForegroundTask.saveData(key: 'dirPath', value: dirPath);
  }
}
