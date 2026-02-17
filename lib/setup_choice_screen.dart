import 'package:fedimintd_mobile/lib.dart';
import 'package:fedimintd_mobile/main.dart';
import 'package:fedimintd_mobile/onboarding.dart';
import 'package:fedimintd_mobile/recovery_service.dart';
import 'package:fedimintd_mobile/utils.dart';
import 'package:flutter/material.dart';

/// Screen for choosing between creating a new guardian or recovering an existing one
class SetupChoiceScreen extends StatefulWidget {
  const SetupChoiceScreen({super.key});

  @override
  State<SetupChoiceScreen> createState() => _SetupChoiceScreenState();
}

class _SetupChoiceScreenState extends State<SetupChoiceScreen> {
  bool _isRecovering = false;

  Future<void> _onCreateNew() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NetworkSelectionScreen()),
    );
  }

  Future<void> _onRecover() async {
    // Step 1: Pick backup file first
    final backupPath = await RecoveryService.pickBackupFile();

    if (backupPath == null) {
      // User cancelled file picker
      return;
    }

    setState(() => _isRecovering = true);

    try {
      // Step 2: Extract files from backup (without password.private)
      final extractResult = await RecoveryService.extractBackupFiles(
        backupPath,
      );

      if (!mounted) {
        setState(() => _isRecovering = false);
        return;
      }

      if (!extractResult.success) {
        // Extraction failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to extract backup: ${extractResult.errorMessage}',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isRecovering = false);
        return;
      }

      // Step 3: Ask for password
      final password = await _showPasswordDialog();
      if (password == null || password.isEmpty) {
        // User cancelled password dialog - clean up extracted files
        await RecoveryService.cleanupExtractedFiles();
        setState(() => _isRecovering = false);
        return;
      }

      // Step 4: Test password with Rust function
      setState(() => _isRecovering = true);

      try {
        final dir = await getConfigDirectory();
        await testDecryption(dbPath: dir.path, password: password);

        // Password is correct - create password.private and proceed
        if (!mounted) {
          setState(() => _isRecovering = false);
          return;
        }

        final createPasswordResult = await RecoveryService.createPasswordFile(
          password,
        );

        if (!createPasswordResult.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to save password: ${createPasswordResult.errorMessage}',
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.error,
            ),
          );
          setState(() => _isRecovering = false);
          return;
        }

        // Recovery successful, continue to network selection
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup restored successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
          ),
        );

        // Navigate to network selection
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NetworkSelectionScreen()),
        );
      } catch (e) {
        // Password is incorrect - clean up and stay on current screen
        if (!mounted) {
          setState(() => _isRecovering = false);
          return;
        }

        await RecoveryService.cleanupExtractedFiles();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Decryption failed: The password is incorrect'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        setState(() => _isRecovering = false);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during recovery: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRecovering = false);
      }
    }
  }

  Future<String?> _showPasswordDialog() async {
    final passwordController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Enter Guardian Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the password for your guardian backup. '
                'This will be used to decrypt your private keys.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your guardian password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final password = passwordController.text;
                Navigator.of(dialogContext).pop(password);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Guardian')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const FedimintLogo(size: 64),
              const SizedBox(height: 24),
              const Text(
                'Welcome to Fedimint',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose how you want to set up your guardian',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      SelectionCard(
                        icon: Icons.add_circle,
                        title: 'Create New Guardian',
                        description:
                            'Set up a new guardian from scratch. You will need an invite code from the federation.',
                        onTap: _isRecovering ? null : _onCreateNew,
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      SelectionCard(
                        icon: Icons.restore,
                        title: 'Recover Existing Guardian',
                        description:
                            'Restore a guardian from a backup file. You will need your backup tar file.',
                        onTap: _isRecovering ? null : _onRecover,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (_isRecovering) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Restoring from backup...',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
