import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ParselWebViewWidget extends StatelessWidget {
  final bool showWebView;
  final bool isLoading;
  final Function(InAppWebViewController) onWebViewCreated;
  final Function(InAppWebViewController, WebUri?) onLoadStart;
  final Function(InAppWebViewController, int) onProgressChanged;
  final Function(InAppWebViewController, WebUri?) onLoadStop;
  final Function(InAppWebViewController, WebResourceRequest, WebResourceError) onReceivedError;
  final Function(InAppWebViewController, WebResourceRequest, WebResourceResponse) onReceivedHttpError;

  const ParselWebViewWidget({
    super.key,
    required this.showWebView,
    required this.isLoading,
    required this.onWebViewCreated,
    required this.onLoadStart,
    required this.onProgressChanged,
    required this.onLoadStop,
    required this.onReceivedError,
    required this.onReceivedHttpError,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('ParselWebViewWidget build - showWebView: $showWebView, isLoading: $isLoading');
    return Column(
      children: [
        if (isLoading) const LinearProgressIndicator(),
        if (showWebView)
          Container(
            height: 500,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Builder(
              builder: (context) {
                debugPrint('Creating InAppWebView widget');
                return InAppWebView(
                  initialSettings: InAppWebViewSettings(
                    // CRITICAL: JavaScript must be enabled
                    javaScriptEnabled: true,

                    // CRITICAL FOR iOS: Disable App-Bound Domains restriction
                    limitsNavigationsToAppBoundDomains: false,

                    // iOS specific settings
                    allowsInlineMediaPlayback: true,
                    allowsBackForwardNavigationGestures: true,
                    allowsAirPlayForMediaPlayback: false,
                    allowsPictureInPictureMediaPlayback: false,
                    iframeAllowFullscreen: true,
                    applePayAPIEnabled: false,

                    // iOS WKWebView settings for JavaScript
                    javaScriptCanOpenWindowsAutomatically: true,

                    // Android specific settings
                    domStorageEnabled: Platform.isAndroid,
                    databaseEnabled: Platform.isAndroid,

                    // Common settings - CloudFlare bypass için
                    useShouldOverrideUrlLoading: false,
                    mediaPlaybackRequiresUserGesture: false,
                    supportZoom: true,
                    builtInZoomControls: false,
                    displayZoomControls: false,
                    useWideViewPort: true,
                    loadWithOverviewMode: true,

                    // Cache ve cookie ayarları - CloudFlare bypass için
                    cacheEnabled: true,
                    clearCache: false,
                    thirdPartyCookiesEnabled: true,
                    hardwareAcceleration: true,

                    // Security settings
                    mixedContentMode: Platform.isAndroid ? MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW : null,

                    // CloudFlare bypass için kritik ayarlar
                    disableVerticalScroll: false,
                    disableHorizontalScroll: false,
                    disableContextMenu: false,
                    verticalScrollBarEnabled: true,
                    horizontalScrollBarEnabled: true,

                    // User Agent - CloudFlare tarafından mobile cihaz olarak algılanması için
                    // userAgent: Platform.isIOS
                    //   ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1'
                    //   : 'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36',
                  ),
                  onWebViewCreated: (controller) {
                    debugPrint('InAppWebView onWebViewCreated called');
                    onWebViewCreated(controller);
                  },
                  onLoadStart: onLoadStart,
                  onProgressChanged: onProgressChanged,
                  onLoadStop: onLoadStop,
                  onReceivedError: onReceivedError,
                  onReceivedHttpError: onReceivedHttpError,
                  onConsoleMessage: (controller, consoleMessage) {
                    debugPrint('Console: ${consoleMessage.message}');
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
