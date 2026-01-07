import 'dart:convert';
import 'dart:io';

import 'package:fedimintd_mobile/blockchain_config.dart';
import 'package:fedimintd_mobile/lib.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AppLogger {
  static late final File _logFile;
  static final AppLogger instance = AppLogger._internal();

  AppLogger._internal();

  static Future<void> init() async {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    _logFile = File('${dir!.path}/fedimintd_mobile/fedimintd.txt');

    if (!(await _logFile.exists())) {
      await _logFile.create(recursive: true);
    }

    instance.info("Logger initialized. Log file: ${_logFile.path}");
  }

  void _log(String level, String message) {
    final timestamp = DateTime.now().toIso8601String();
    final formatted = "[$timestamp] [$level] $message";

    // Print to console
    debugPrint(formatted);

    // Write to file
    _logFile.writeAsStringSync(
      "$formatted\n",
      mode: FileMode.append,
      flush: true,
    );
  }

  void info(String message) => _log("INFO", message);
  void warn(String message) => _log("WARN", message);
  void error(String message) => _log("ERROR", message);
  void debug(String message) => _log("DEBUG", message);
}

Future<bool> requestNotificationPermission() async {
  if (Platform.isAndroid) {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      final result = await Permission.notification.request();
      return result.isGranted;
    }

    return status.isGranted;
  }

  return true;
}

/// Extension for NetworkType display names
extension NetworkTypeExtension on NetworkType {
  String get displayName {
    switch (this) {
      case NetworkType.mutinynet:
        return "Mutinynet";
      case NetworkType.mainnet:
        return "Mainnet";
      case NetworkType.regtest:
        return "Regtest";
    }
  }
}

/// Get the appropriate config directory for the platform.
/// Throws [StateError] if the directory cannot be determined.
Future<Directory> getConfigDirectory() async {
  Directory? dir;
  if (Platform.isAndroid) {
    dir = await getExternalStorageDirectory();
  } else {
    dir = await getApplicationDocumentsDirectory();
  }
  if (dir == null) {
    throw StateError('Could not determine application directory');
  }
  return dir;
}

/// Write config to the standard config file location.
Future<void> writeConfigFile(BlockchainConfig config) async {
  final dir = await getConfigDirectory();
  final file = File('${dir.path}/fedimintd_mobile/fedimintd_config.json');
  await file.writeAsString(jsonEncode(config.toJson()), flush: true);
}

/// Read and parse the config file.
/// Returns null if not found or invalid.
Future<BlockchainConfig?> readConfigFile() async {
  try {
    final dir = await getConfigDirectory();
    final file = File('${dir.path}/fedimintd_mobile/fedimintd_config.json');

    if (!await file.exists()) {
      AppLogger.instance.info("No config file found");
      return null;
    }

    final contents = await file.readAsString();
    final json = jsonDecode(contents) as Map<String, dynamic>;
    return BlockchainConfig.fromJson(json);
  } catch (e) {
    AppLogger.instance.error("Error reading config file: $e");
    return null;
  }
}
