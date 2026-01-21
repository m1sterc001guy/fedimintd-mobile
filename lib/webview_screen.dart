import 'dart:async';

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
                _controller.runJavaScript('''
                  window.fedimintQrScannerOverride = function(callback) {
                    FedimintQrScanner.postMessage('startQrScanner');
                    window.fedimintQrScannerResult = callback;
                  };
                ''');
              },
            ),
          );
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
          ],
        ),
      ),
    );
  }
}
