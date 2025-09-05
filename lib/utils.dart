import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

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
