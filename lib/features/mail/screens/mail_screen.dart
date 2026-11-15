import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import '../../../core/theme/orbit_theme.dart';
import '../../../core/theme/whatsapp_colors.dart';

class MailScreen extends StatefulWidget {
  const MailScreen({super.key});

  @override
  State<MailScreen> createState() => _MailScreenState();
}

class _MailScreenState extends State<MailScreen> {
  WebViewController? _controller;
  int _loadingProgress = 0;
  bool _hasError = false;
  String _errorMessage = '';

  static const String mailUrl = 'https://mail.kecapsawi.net/';

  @override
  void initState() {
    super.initState();
    if (WebViewPlatform.instance != null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              if (mounted) {
                setState(() {
                  _loadingProgress = progress;
                });
              }
            },
            onPageStarted: (String url) {
              if (mounted) {
                setState(() {
                  _hasError = false;
                  _errorMessage = '';
                });
              }
            },
            onPageFinished: (String url) {
              _controller?.runJavaScript('''
                (function () {
                  if (!document.querySelector('#login_user')) return;
                  if (document.getElementById('workhub-mail-mobile-login-layout')) return;
                  var style = document.createElement('style');
                  style.id = 'workhub-mail-mobile-login-layout';
                  style.textContent = `
                    @media (max-width: 767px) {
                      html, body {
                        width: 100% !important;
                        max-width: 100% !important;
                        overflow-x: hidden !important;
                      }
                      body:has(#login_user) {
                        min-height: 100svh !important;
                        overflow-y: auto !important;
                      }
                      body:has(#login_user) > .container.flex-grow-1.my-4 {
                        box-sizing: border-box !important;
                        width: 100% !important;
                        max-width: 100% !important;
                        min-height: 0 !important;
                        padding-left: 16px !important;
                        padding-right: 16px !important;
                        padding-top: 8px !important;
                        padding-bottom: 16px !important;
                        margin-left: auto !important;
                        margin-right: auto !important;
                      }
                      body:has(#login_user) > .container.flex-grow-1.my-4 > .row.mb-4 {
                        box-sizing: border-box !important;
                        width: 100% !important;
                        margin-left: 0 !important;
                        margin-right: 0 !important;
                        margin-top: 0 !important;
                      }
                      body:has(#login_user) > .container.flex-grow-1.my-4 > .row.mb-4 > [class*="col-"] {
                        flex: 0 0 100% !important;
                        width: 100% !important;
                        max-width: 100% !important;
                        padding-left: 0 !important;
                        padding-right: 0 !important;
                        margin-left: auto !important;
                        margin-right: auto !important;
                      }
                      body:has(#login_user) .card,
                      body:has(#login_user) .card-body,
                      body:has(#login_user) form {
                        min-height: 0 !important;
                        height: auto !important;
                      }
                      body:has(#login_user) > .container.flex-grow-1.my-4 > .row.mb-4 > [class*="col-"] > .card {
                        box-sizing: border-box !important;
                        width: 100% !important;
                        max-width: 440px !important;
                        margin-left: auto !important;
                        margin-right: auto !important;
                      }
                      body:has(#login_user) .mailcow-logo {
                        margin-bottom: 12px !important;
                      }
                      body:has(#login_user) .mailcow-logo img {
                        width: auto !important;
                        max-width: min(180px, 58vw) !important;
                        max-height: 132px !important;
                        object-fit: contain !important;
                      }
                    }
                  `;
                  document.head.appendChild(style);
                })();
              ''');
              if (mounted) {
                setState(() {
                  _loadingProgress = 100;
                });
              }
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _errorMessage = error.description;
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(mailUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Mail',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: OrbitColors.primaryNavy,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Reload',
            onPressed: () {
              setState(() {
                _hasError = false;
              });
              _controller?.reload();
            },
          ),
        ],
        bottom: _loadingProgress < 100 && !_hasError
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _loadingProgress / 100.0,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    WhatsAppColors.tealGreen,
                  ),
                  minHeight: 2,
                ),
              )
            : null,
      ),
      body: SafeArea(
        child: _controller == null
            ? const Center(
                child: Text(
                  'Mail Webview (Platform not initialized)',
                  style: TextStyle(color: OrbitColors.textNavy),
                ),
              )
            : _hasError
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 56,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Unable to load Mail',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: OrbitColors.textNavy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage.isNotEmpty
                                ? _errorMessage
                                : 'Check your internet connection and try again.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: OrbitColors.primaryNavy,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _hasError = false;
                              });
                              _controller?.reload();
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : WebViewWidget(controller: _controller!),
      ),
    );
  }
}
