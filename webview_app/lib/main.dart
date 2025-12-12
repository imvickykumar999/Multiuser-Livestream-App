import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: WebViewExample(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WebViewExample extends StatefulWidget {
  const WebViewExample({super.key});

  @override
  State<WebViewExample> createState() => _WebViewExampleState();
}

class _WebViewExampleState extends State<WebViewExample> {
  late final WebViewController _controller;
  String _currentUrl = "Loading...";
  String _pageTitle = "Loading...";

  @override
  void initState() {
    super.initState();

    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (NavigationRequest request) async {
                Uri uri = Uri.parse(request.url);

                // Allow internal domain to load in WebView
                if (uri.host.contains('24x7live.imvickykumar999.dpdns.org')) {
                  return NavigationDecision.navigate;
                }

                // Handle external links robustly
                await _launchExternalUrl(request.url, context);
                return NavigationDecision.prevent;
              },
              onPageStarted: (String url) {
                setState(() {
                  _currentUrl = url;
                  _pageTitle = "Loading...";
                });
              },
              onPageFinished: (String url) async {
                final updatedUrl = await _controller.currentUrl();
                final title = await _controller.getTitle();
                setState(() {
                  _currentUrl = updatedUrl ?? 'Unknown URL';
                  _pageTitle = title ?? 'No Title';
                });
              },
              onWebResourceError: (WebResourceError error) {
                debugPrint("WebView Error: ${error.description}");
              },
            ),
          )
          ..loadRequest(
            Uri.parse("https://24x7live.imvickykumar999.dpdns.org/"),
          );

    // Setup file upload support for Android
    _setupFileUpload();
  }

  // 📁 Setup file upload support
  void _setupFileUpload() {
    if (Platform.isAndroid) {
      final androidController =
          _controller.platform as AndroidWebViewController;
      androidController.setOnShowFileSelector(_androidFilePicker);
    }
  }

  // 📁 Android file picker handler
  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    try {
      // Use method channel to get content URIs directly from native file picker
      const platform = MethodChannel('com.imvickykumar999.x24live/file_picker');

      // Determine MIME type from accept types
      String? mimeType;
      if (params.acceptTypes.isNotEmpty) {
        final acceptTypes = params.acceptTypes;
        if (acceptTypes.any(
          (type) =>
              type.contains('image') ||
              type == 'image/*' ||
              type.startsWith('image/'),
        )) {
          mimeType = 'image/*';
        } else if (acceptTypes.any(
          (type) =>
              type.contains('video') ||
              type == 'video/*' ||
              type.startsWith('video/'),
        )) {
          mimeType = 'video/*';
        } else if (acceptTypes.any(
          (type) =>
              type.contains('audio') ||
              type == 'audio/*' ||
              type.startsWith('audio/'),
        )) {
          mimeType = 'audio/*';
        } else {
          mimeType = '*/*';
        }
      } else {
        mimeType = '*/*';
      }

      final List<dynamic>? result = await platform.invokeMethod('pickFile', {
        'mimeType': mimeType,
      });

      if (result != null && result.isNotEmpty) {
        return result.cast<String>();
      }
    } catch (e) {
      debugPrint("File picker error: $e");
    }
    return [];
  }

  // 🔗 External URL handler
  Future<void> _launchExternalUrl(String url, BuildContext context) async {
    try {
      final uri = Uri.parse(url);
      debugPrint("Trying to launch external URL: $url");

      // Attempt external app launch
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
        if (!launched) {
          // Fallback to platform default
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      } else {
        // Fallback if no app found
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error opening URL: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          if (await _controller.canGoBack()) {
            _controller.goBack();
          } else {
            Navigator.of(context).maybePop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF4F00A7),
          iconTheme: const IconThemeData(color: Colors.white),
          title: GestureDetector(
            onTap: () {
              _controller.reload(); // Refresh WebView
            },
            child: Text(
              _pageTitle,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: "Refresh",
              onPressed: () => _controller.reload(),
            ),
          ],
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
