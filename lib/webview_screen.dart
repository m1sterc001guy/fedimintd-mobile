import 'dart:async';

import 'package:fedimintd_mobile/backup_service.dart';
import 'package:fedimintd_mobile/main.dart';
import 'package:fedimintd_mobile/onboarding.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
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

class _WebViewScreenState extends State<WebViewScreen> {
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
  bool _isScanningQr = false;
  bool _isCreatingBackup = false;

  @override
  void initState() {
    super.initState();
    _setupWebViewController();
    _pollForServer();
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
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
                  setState(() => _isScanningQr = true);
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
            if (_isScanningQr)
              Container(
                color: Colors.black87,
                child: Stack(
                  children: [
                    MobileScanner(
                      onDetect: (capture) {
                        final barcode = capture.barcodes.first;
                        if (barcode.rawValue != null) {
                          setState(() => _isScanningQr = false);
                          _controller.runJavaScript(
                            'window.fedimintQrScannerResult && window.fedimintQrScannerResult("${barcode.rawValue}")',
                          );
                        }
                      },
                    ),
                    Positioned(
                      top: 60,
                      right: 16,
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() => _isScanningQr = false),
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
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
