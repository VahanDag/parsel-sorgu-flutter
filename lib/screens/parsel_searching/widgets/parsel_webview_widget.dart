import 'dart:async';
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
  final Future<NavigationActionPolicy> Function(InAppWebViewController, NavigationAction) shouldOverrideUrlLoading;

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
    required this.shouldOverrideUrlLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isLoading) const LinearProgressIndicator(),
        Visibility(
          visible: showWebView,
          maintainState: true,
          child: Container(
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
            child: InAppWebView(
              key: const ValueKey('webview'),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                useShouldOverrideUrlLoading: true,
                supportZoom: true,
                builtInZoomControls: true,
                displayZoomControls: false,
                useWideViewPort: true,
                loadWithOverviewMode: true,
              ),
              onWebViewCreated: onWebViewCreated,
              onLoadStart: onLoadStart,
              onProgressChanged: onProgressChanged,
              onLoadStop: onLoadStop,
              onReceivedError: onReceivedError,
              onReceivedHttpError: onReceivedHttpError,
              shouldOverrideUrlLoading: shouldOverrideUrlLoading,
            ),
          ),
        ),
      ],
    );
  }
}