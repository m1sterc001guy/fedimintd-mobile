import 'dart:developer' as developer;
import 'dart:io';

import 'package:fedimintd_mobile/lib.dart';
import 'package:fedimintd_mobile/utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Result of a backup operation.
class BackupResult {
  final bool success;
  final String? errorMessage;

  const BackupResult._({required this.success, this.errorMessage});

  factory BackupResult.success() => const BackupResult._(success: true);

  factory BackupResult.failure(String error) =>
      BackupResult._(success: false, errorMessage: error);
}

/// Service for downloading and sharing guardian config backups.
class BackupService {
  /// Downloads the guardian backup via Rust FFI and opens the share sheet.
  /// Returns a BackupResult with success status and optional error message.
  static Future<BackupResult> downloadAndShareBackup(String password) async {
    try {
      developer.log(
        'Starting backup download via Rust FFI...',
        name: 'BackupService',
      );

      // Get the database path
      final dir = await getConfigDirectory();
      final dbPath = dir.path;
      developer.log('Database path: $dbPath', name: 'BackupService');

      // Call the Rust function via Flutter Rust Bridge
      developer.log(
        'Calling downloadBackup Rust function...',
        name: 'BackupService',
      );
      final backupBytes = await downloadBackup(
        dbPath: dbPath,
        password: password,
      );

      developer.log(
        'Received backup bytes: ${backupBytes.length}',
        name: 'BackupService',
      );

      if (backupBytes.isEmpty) {
        return BackupResult.failure('Received empty backup data');
      }

      // Save to temp file with timestamp
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      final fileName = 'fedimint-backup-$timestamp.tar';
      final filePath = '${tempDir.path}/$fileName';

      developer.log('Saving backup to: $filePath', name: 'BackupService');

      final file = File(filePath);
      await file.writeAsBytes(backupBytes);

      developer.log('Backup file saved successfully', name: 'BackupService');

      // Share the file
      developer.log('Opening share sheet...', name: 'BackupService');
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Fedimint Guardian Backup',
        text:
            'Here is your encrypted Fedimint guardian backup. '
            'Store it securely - you will need your password to restore.',
      );

      developer.log('Backup shared successfully', name: 'BackupService');
      return BackupResult.success();
    } catch (e, stackTrace) {
      developer.log(
        'Backup failed: $e',
        name: 'BackupService',
        error: e,
        stackTrace: stackTrace,
      );
      return BackupResult.failure('Error: $e');
    }
  }
}
