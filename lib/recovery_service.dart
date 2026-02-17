import 'dart:developer' as developer;
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fedimintd_mobile/utils.dart';

/// Result of a recovery operation
class RecoveryResult {
  final bool success;
  final String? errorMessage;

  const RecoveryResult._({required this.success, this.errorMessage});

  factory RecoveryResult.success() => const RecoveryResult._(success: true);

  factory RecoveryResult.failure(String error) =>
      RecoveryResult._(success: false, errorMessage: error);
}

/// Service for handling guardian recovery from backup files
class RecoveryService {
  static String? _lastExtractedDir;

  /// Opens file picker to select a backup tar file
  /// Returns the file path or null if cancelled
  static Future<String?> pickBackupFile() async {
    try {
      developer.log(
        'Opening file picker for backup selection',
        name: 'RecoveryService',
      );

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['tar'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        developer.log('User cancelled file picker', name: 'RecoveryService');
        return null;
      }

      final path = result.files.single.path;
      developer.log('Selected backup file: $path', name: 'RecoveryService');
      return path;
    } catch (e) {
      developer.log(
        'Error picking file: $e',
        name: 'RecoveryService',
        error: e,
      );
      return null;
    }
  }

  /// Extracts backup files without creating password.private
  /// This allows password testing before finalizing recovery
  static Future<RecoveryResult> extractBackupFiles(String tarPath) async {
    try {
      developer.log(
        'Starting extraction from: $tarPath',
        name: 'RecoveryService',
      );

      // Check if local.json already exists (indicates an existing guardian)
      final dir = await getConfigDirectory();
      final fedimintdDir = Directory('${dir.path}/fedimintd_mobile');
      final localJsonFile = File('${fedimintdDir.path}/local.json');

      developer.log(
        'Checking if local.json exists: ${localJsonFile.path}',
        name: 'RecoveryService',
      );

      if (await localJsonFile.exists()) {
        developer.log(
          'local.json already exists, cannot recover',
          name: 'RecoveryService',
        );
        return RecoveryResult.failure(
          'A guardian already exists. Cannot recover over an existing guardian. '
          'Please clear app data first if you want to restore from backup.',
        );
      }

      // Read and validate tar file
      developer.log('Reading tar file', name: 'RecoveryService');
      final tarFile = File(tarPath);

      if (!await tarFile.exists()) {
        return RecoveryResult.failure('Backup file not found');
      }

      final tarBytes = await tarFile.readAsBytes();
      developer.log(
        'Tar file size: ${tarBytes.length} bytes',
        name: 'RecoveryService',
      );

      // Decode tar archive
      final archive = TarDecoder().decodeBytes(tarBytes);

      if (archive.isEmpty) {
        return RecoveryResult.failure('Backup file is empty or corrupted');
      }

      developer.log(
        'Found ${archive.length} files in archive',
        name: 'RecoveryService',
      );

      // Validate required files are present
      final requiredFiles = ['local.json', 'consensus.json'];
      final archiveFiles = archive.map((f) => f.name).toList();

      developer.log('Files in archive: $archiveFiles', name: 'RecoveryService');

      for (final required in requiredFiles) {
        if (!archiveFiles.any((f) => f.contains(required))) {
          return RecoveryResult.failure(
            'Invalid backup: missing required file "$required"',
          );
        }
      }

      // Create directory and extract files
      developer.log(
        'Creating directory: ${fedimintdDir.path}',
        name: 'RecoveryService',
      );
      await fedimintdDir.create(recursive: true);

      // Extract files
      for (final file in archive) {
        if (file.isFile) {
          final filePath = '${fedimintdDir.path}/${file.name}';
          final outputFile = File(filePath);

          // Create parent directory if needed
          await outputFile.parent.create(recursive: true);

          // Write file
          await outputFile.writeAsBytes(file.content as List<int>);
          developer.log('Extracted: ${file.name}', name: 'RecoveryService');
        }
      }

      // Store the directory path for potential cleanup
      _lastExtractedDir = fedimintdDir.path;

      developer.log(
        'Extraction completed successfully',
        name: 'RecoveryService',
      );
      return RecoveryResult.success();
    } catch (e, stackTrace) {
      developer.log(
        'Extraction failed: $e',
        name: 'RecoveryService',
        error: e,
        stackTrace: stackTrace,
      );
      return RecoveryResult.failure('Extraction failed: $e');
    }
  }

  /// Creates the password.private file after password verification
  static Future<RecoveryResult> createPasswordFile(String password) async {
    try {
      final dir = await getConfigDirectory();
      final fedimintdDir = Directory('${dir.path}/fedimintd_mobile');
      final passwordFile = File('${fedimintdDir.path}/password.private');

      await passwordFile.writeAsString(password);
      developer.log('Created password.private file', name: 'RecoveryService');

      // Clear the stored directory path since recovery is complete
      _lastExtractedDir = null;

      return RecoveryResult.success();
    } catch (e, stackTrace) {
      developer.log(
        'Failed to create password file: $e',
        name: 'RecoveryService',
        error: e,
        stackTrace: stackTrace,
      );
      return RecoveryResult.failure('Failed to create password file: $e');
    }
  }

  /// Cleans up extracted files if recovery is cancelled or fails
  static Future<void> cleanupExtractedFiles() async {
    try {
      if (_lastExtractedDir != null) {
        final dir = Directory(_lastExtractedDir!);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          developer.log(
            'Cleaned up extracted files: $_lastExtractedDir',
            name: 'RecoveryService',
          );
        }
        _lastExtractedDir = null;
      }
    } catch (e) {
      developer.log(
        'Error cleaning up files: $e',
        name: 'RecoveryService',
        error: e,
      );
    }
  }

  /// Legacy method - extracts files and creates password.private in one step
  /// Used for backward compatibility
  static Future<RecoveryResult> recoverFromBackup(
    String tarPath,
    String password,
  ) async {
    // First extract files
    final extractResult = await extractBackupFiles(tarPath);
    if (!extractResult.success) {
      return extractResult;
    }

    // Then create password file
    return createPasswordFile(password);
  }
}
