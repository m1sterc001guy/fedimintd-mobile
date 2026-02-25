import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fedimintd_mobile/backup_service.dart';
import 'package:fedimintd_mobile/main.dart';
import 'package:fedimintd_mobile/onboarding.dart';
import 'package:fedimintd_mobile/utils.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// WebView screen that displays the Fedimintd dashboard.
///
/// Polls the server until it's ready before showing the WebView.
/// Shows a loading indicator while waiting for the server.
/// Shows a critical error if the server doesn't respond within the timeout.
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen>
    with WidgetsBindingObserver {
  static const _serverUrl = 'http://localhost:8175';
  static const _maxAttempts = 60; // 60 seconds timeout
  static const _pollInterval = Duration(seconds: 1);
  static const _requestTimeout = Duration(seconds: 2);

  late final WebViewController _controller;
  bool _isServerReady = false;
  bool _hasCriticalError = false;
  bool _isPageLoading = false;
  bool _refreshTriggered = false;
  bool _cancelled = false;
  bool _isCreatingBackup = false;
  bool _backupReminderShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupWebViewController();
    _pollForServer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelled = true;
    super.dispose();
  }

  Future<void> _startQrScanner() async {
    // Request camera permission first
    final cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      final result = await Permission.camera.request();
      if (!result.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required to scan QR codes'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => const QRScannerScreen(),
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      _controller.runJavaScript(
        'window.fedimintQrScannerResult && window.fedimintQrScannerResult("$result")',
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Reset the flag so we can show the reminder again
      _backupReminderShown = false;
      // Check after a short delay to let the UI settle
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_backupReminderShown && _isServerReady) {
          _checkAndShowBackupReminder();
        }
      });
    }
  }

  void _setupWebViewController() {
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..addJavaScriptChannel(
            'FedimintQrScanner',
            onMessageReceived: (message) {
              if (message.message == 'startQrScanner') {
                if (mounted) {
                  _startQrScanner();
                }
              }
            },
          )
          ..addJavaScriptChannel(
            'FedimintBackup',
            onMessageReceived: (message) {
              if (message.message == 'requestBackup') {
                _showBackupPasswordDialog();
              }
            },
          )
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (_) {
                if (mounted) {
                  setState(() => _isPageLoading = true);
                }
              },
              onPageFinished: (_) {
                if (mounted) {
                  setState(() => _isPageLoading = false);
                  if (_refreshTriggered) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Refreshed dashboard'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    _refreshTriggered = false;
                  }
                }
                _injectJavaScriptOverrides();

                // Check for backup reminder after a delay
                Future.delayed(const Duration(seconds: 6), () {
                  if (mounted && !_backupReminderShown) {
                    _checkAndShowBackupReminder();
                  }
                });
              },
            ),
          );
  }

  void _injectJavaScriptOverrides() {
    _controller.runJavaScript('''
      // Override QR scanner
      window.fedimintQrScannerOverride = function(callback) {
        FedimintQrScanner.postMessage('startQrScanner');
        window.fedimintQrScannerResult = callback;
      };
      
      // Override backup button click using MutationObserver
      (function() {
        // Track which elements we've already processed to avoid duplicate listeners
        const processedElements = new WeakSet();
        
        function isBackupButton(el) {
          // Check by data-testid attributes
          const testId = el.getAttribute('data-testid');
          if (testId && (testId.includes('backup') || testId.includes('download'))) {
            return true;
          }
          
          // Check by text content
          const text = (el.textContent || el.innerText || '').toLowerCase();
          if (text.includes('backup') || text.includes('download')) {
            return true;
          }
          
          return false;
        }
        
        function attachBackupListener(el) {
          if (processedElements.has(el)) {
            return;
          }
          processedElements.add(el);
          
          el.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            FedimintBackup.postMessage('requestBackup');
          });
          console.log('Backup button override attached');
        }
        
        function processElement(el) {
          if (el.matches && (el.matches('button, a, [role="button"]')) && isBackupButton(el)) {
            attachBackupListener(el);
          }
          
          // Also check children
          if (el.querySelectorAll) {
            const elements = el.querySelectorAll('button, a, [role="button"]');
            for (const child of elements) {
              if (isBackupButton(child)) {
                attachBackupListener(child);
              }
            }
          }
        }
        
        // Process existing elements immediately
        processElement(document.body);
        
        // Set up MutationObserver to watch for new elements
        const observer = new MutationObserver(function(mutations) {
          for (const mutation of mutations) {
            for (const node of mutation.addedNodes) {
              if (node.nodeType === Node.ELEMENT_NODE) {
                processElement(node);
              }
            }
          }
        });
        
        // Start observing the entire document
        observer.observe(document.body, {
          childList: true,
          subtree: true
        });
        
        console.log('MutationObserver initialized for backup button');
      })();
    ''');
  }

  // ---- Backup Reminder Methods ----

  /// Returns the path to the backup acknowledgment file.
  Future<File> _getBackupAcknowledgedFile() async {
    final dir = await getConfigDirectory();
    return File('${dir.path}/fedimintd_mobile/backup_acknowledged.json');
  }

  /// Checks if the user has completed a backup (not just dismissed).
  /// Returns true only if the file exists and reason is "backed_up".
  Future<bool> _hasCompletedBackup() async {
    try {
      final file = await _getBackupAcknowledgedFile();
      if (!await file.exists()) {
        return false;
      }
      final contents = await file.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      return json['reason'] == 'backed_up';
    } catch (e) {
      return false;
    }
  }

  /// Writes the backup acknowledgment file with the given reason.
  /// [reason] should be either "backed_up" or "dismissed".
  Future<void> _writeBackupAcknowledged(String reason) async {
    try {
      final file = await _getBackupAcknowledgedFile();
      final json = {
        'reason': reason,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(json), flush: true);
    } catch (e) {
      // Log error but don't fail - this is not critical
      AppLogger.instance.error('Failed to write backup acknowledgment: $e');
    }
  }

  /// Checks if backup reminder should be shown and shows it if needed.
  /// Called ~6 seconds after page load.
  Future<void> _checkAndShowBackupReminder() async {
    if (_backupReminderShown || !mounted) return;

    // Check if user has already completed a backup
    final hasBackup = await _hasCompletedBackup();
    if (hasBackup) return;

    // Check if invite code is available (federation ready)
    final inviteCode = await _extractInviteCodeFromDom();
    if (inviteCode == null) return;

    if (!mounted) return;

    _backupReminderShown = true;
    _showBackupReminderModal(inviteCode);
  }

  /// Shows the backup reminder bottom sheet modal.
  void _showBackupReminderModal(String inviteCode) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(36),
                ),
                child: const Icon(
                  Icons.backup,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              // Title
              const Text(
                'Backup Your Guardian',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Body text
              const Text(
                'Your guardian is running but you haven\'t created a backup yet.\n\n'
                'Creating a backup is strongly encouraged. It ensures you can '
                'recover your guardian if your device is lost, damaged, or reset.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              // Backup Now button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(bottomSheetContext).pop();
                    _showBackupPasswordDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Backup Now',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // I know what I'm doing button
              TextButton(
                onPressed: () {
                  _writeBackupAcknowledged('dismissed');
                  Navigator.of(bottomSheetContext).pop();
                },
                child: const Text(
                  'I know what I\'m doing',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _extractInviteCodeFromDom() async {
    // Extract invite code from the copyInviteCodeBtn onclick attribute
    // The onclick looks like: navigator.clipboard.writeText('fed1...').then(...)
    const js = '''
      (function() {
        const btn = document.getElementById('copyInviteCodeBtn');
        if (!btn) return null;
        const onclick = btn.getAttribute('onclick');
        if (!onclick) return null;
        const match = onclick.match(/writeText\\('([^']+)'\\)/);
        return match ? match[1] : null;
      })();
    ''';

    final result = await _controller.runJavaScriptReturningResult(js);

    // Result comes back as a quoted string like '"fed1..."' or 'null'
    if (result == null || result == 'null') {
      return null;
    }

    // Remove surrounding quotes if present
    String inviteCode = result.toString();
    if (inviteCode.startsWith('"') && inviteCode.endsWith('"')) {
      inviteCode = inviteCode.substring(1, inviteCode.length - 1);
    }

    return inviteCode.isNotEmpty ? inviteCode : null;
  }

  Future<void> _showBackupPasswordDialog() async {
    // First, extract the invite code from the DOM
    final inviteCode = await _extractInviteCodeFromDom();

    if (!mounted) return;

    if (inviteCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invite code not available - federation must complete its first consensus session',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final passwordController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create Backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your guardian password to create an encrypted backup. '
                'This backup can be used to restore your guardian node.',
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
                if (password.isNotEmpty) {
                  Navigator.of(dialogContext).pop();
                  _createBackup(inviteCode, password);
                }
              },
              child: const Text('Create Backup'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createBackup(String inviteCode, String password) async {
    if (_isCreatingBackup) return;

    setState(() => _isCreatingBackup = true);

    try {
      final result = await BackupService.downloadAndShareBackup(
        inviteCode,
        password,
      );

      if (mounted) {
        if (result.success) {
          // Mark backup as completed
          await _writeBackupAcknowledged('backed_up');

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup created successfully!'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to create backup: ${result.errorMessage ?? "Unknown error"}',
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating backup: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingBackup = false);
      }
    }
  }

  Future<void> _pollForServer() async {
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (_cancelled || !mounted) return;

      try {
        final response = await http
            .get(Uri.parse(_serverUrl))
            .timeout(_requestTimeout);

        if (response.statusCode == 200) {
          if (mounted && !_cancelled) {
            setState(() => _isServerReady = true);
            _controller.loadRequest(Uri.parse(_serverUrl));
          }
          return;
        }
      } catch (_) {
        // Server not ready yet, continue polling
      }

      await Future.delayed(_pollInterval);
    }

    // Timeout reached - critical error
    if (mounted && !_cancelled) {
      setState(() => _hasCriticalError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasCriticalError) {
      return _buildCriticalErrorScreen();
    }

    if (!_isServerReady) {
      return _buildLoadingScreen();
    }

    return _buildWebViewScreen();
  }

  Widget _buildCriticalErrorScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FedimintLogo(size: 64),
              const SizedBox(height: 32),
              const Icon(Icons.error_outline, color: AppColors.error, size: 64),
              const SizedBox(height: 24),
              const Text(
                'A critical failure has occurred',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Fedimintd failed to start within the expected time. '
                'Please close the app and try again.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FedimintLogo(size: 80),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text(
              'Starting Fedimintd...',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebViewScreen() {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _refreshTriggered = true);
              _controller.reload();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isPageLoading)
              const LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
              ),
            if (_isCreatingBackup)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Creating backup...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen QR code scanner that returns the scanned code.
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _controller;
  bool _hasScanned = false;

  // Required for hot reload to work properly
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      _controller?.pauseCamera();
    }
    _controller?.resumeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    _controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (!_hasScanned && scanData.code != null && scanData.code!.isNotEmpty) {
        _hasScanned = true;
        controller.pauseCamera();
        Navigator.of(context).pop(scanData.code);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan QR Code'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: AppColors.primary,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: 280,
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Point camera at QR code',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
