import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String _lastYouTubeUrl = ''; // Store last entered YouTube URL

  @override
  void initState() {
    super.initState();
    _loadSavedYouTubeUrl(); // Load saved URL from local storage

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

  // 💾 Load saved YouTube URL from local storage
  Future<void> _loadSavedYouTubeUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('last_youtube_url') ?? '';
      if (savedUrl.isNotEmpty) {
        setState(() {
          _lastYouTubeUrl = savedUrl;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved YouTube URL: $e');
    }
  }

  // 💾 Save YouTube URL to local storage
  Future<void> _saveYouTubeUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_youtube_url', url);
      setState(() {
        _lastYouTubeUrl = url;
      });
    } catch (e) {
      debugPrint('Error saving YouTube URL: $e');
    }
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
      const platform = MethodChannel('com.example.webview_app/file_picker');

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

  // 🎥 Show YouTube link popup
  void _showYouTubePopup(BuildContext context) {
    final TextEditingController urlController = TextEditingController();
    // Pre-fill with last entered URL
    if (_lastYouTubeUrl.isNotEmpty) {
      urlController.text = _lastYouTubeUrl;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Open YouTube Video'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      hintText: 'Paste YouTube video link here',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  // Paste button
                  ElevatedButton.icon(
                    onPressed: () async {
                      final clipboardData = await Clipboard.getData(
                        Clipboard.kTextPlain,
                      );
                      if (clipboardData?.text != null) {
                        urlController.text = clipboardData!.text!;
                        setState(() {}); // Update UI
                      }
                    },
                    icon: const Icon(Icons.paste),
                    label: const Text('Paste from Clipboard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F00A7),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final url = urlController.text.trim();
                    if (url.isNotEmpty) {
                      // Save the URL to local storage
                      _saveYouTubeUrl(url);
                      Navigator.of(context).pop();
                      _openYouTubeVideo(url, context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a YouTube link'),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Open in YouTube'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 🎥 Open YouTube URL directly in YouTube app or WebView
  Future<void> _openYouTubeVideo(String url, BuildContext context) async {
    try {
      String trimmedUrl = url.trim();

      // Ensure URL is valid
      if (trimmedUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a YouTube link')),
        );
        return;
      }

      // Add https:// if URL doesn't have a scheme
      if (!trimmedUrl.startsWith('http://') &&
          !trimmedUrl.startsWith('https://')) {
        trimmedUrl = 'https://$trimmedUrl';
      }

      final youtubeUri = Uri.parse(trimmedUrl);

      // Try multiple methods to open YouTube app on Android
      if (Platform.isAndroid) {
        // Method 1: Try YouTube app intent (Android specific) - use original URL
        try {
          final intentUri = Uri.parse(
            'intent://${youtubeUri.host}${youtubeUri.path}${youtubeUri.hasQuery ? '?${youtubeUri.query}' : ''}#Intent;package=com.google.android.youtube;scheme=https;end',
          );
          if (await canLaunchUrl(intentUri)) {
            await launchUrl(intentUri, mode: LaunchMode.externalApplication);
            return;
          }
        } catch (e) {
          debugPrint("Intent method failed: $e");
        }

        // Method 2: Try vnd.youtube scheme (only if we can extract video ID)
        try {
          String videoId = '';
          if (trimmedUrl.contains('youtu.be/')) {
            videoId =
                trimmedUrl
                    .split('youtu.be/')[1]
                    .split('?')[0]
                    .split('&')[0]
                    .split('#')[0];
          } else if (trimmedUrl.contains('watch?v=')) {
            videoId =
                trimmedUrl.split('watch?v=')[1].split('&')[0].split('#')[0];
          } else if (trimmedUrl.contains('shorts/')) {
            videoId =
                trimmedUrl
                    .split('shorts/')[1]
                    .split('?')[0]
                    .split('&')[0]
                    .split('#')[0];
          }

          if (videoId.isNotEmpty && videoId.length == 11) {
            final vndYoutubeUri = Uri.parse('vnd.youtube:$videoId');
            if (await canLaunchUrl(vndYoutubeUri)) {
              await launchUrl(
                vndYoutubeUri,
                mode: LaunchMode.externalApplication,
              );
              return;
            }
          }
        } catch (e) {
          debugPrint("vnd.youtube scheme failed: $e");
        }

        // Method 3: Try youtube:// scheme (only if we can extract video ID)
        try {
          String videoId = '';
          if (trimmedUrl.contains('youtu.be/')) {
            videoId =
                trimmedUrl
                    .split('youtu.be/')[1]
                    .split('?')[0]
                    .split('&')[0]
                    .split('#')[0];
          } else if (trimmedUrl.contains('watch?v=')) {
            videoId =
                trimmedUrl.split('watch?v=')[1].split('&')[0].split('#')[0];
          } else if (trimmedUrl.contains('shorts/')) {
            videoId =
                trimmedUrl
                    .split('shorts/')[1]
                    .split('?')[0]
                    .split('&')[0]
                    .split('#')[0];
          }

          if (videoId.isNotEmpty && videoId.length == 11) {
            final youtubeAppUri = Uri.parse('youtube://watch?v=$videoId');
            if (await canLaunchUrl(youtubeAppUri)) {
              await launchUrl(
                youtubeAppUri,
                mode: LaunchMode.externalApplication,
              );
              return;
            }
          }
        } catch (e) {
          debugPrint("youtube:// scheme failed: $e");
        }
      } else {
        // For iOS, try youtube:// scheme (only if we can extract video ID)
        try {
          String videoId = '';
          if (trimmedUrl.contains('youtu.be/')) {
            videoId =
                trimmedUrl
                    .split('youtu.be/')[1]
                    .split('?')[0]
                    .split('&')[0]
                    .split('#')[0];
          } else if (trimmedUrl.contains('watch?v=')) {
            videoId =
                trimmedUrl.split('watch?v=')[1].split('&')[0].split('#')[0];
          } else if (trimmedUrl.contains('shorts/')) {
            videoId =
                trimmedUrl
                    .split('shorts/')[1]
                    .split('?')[0]
                    .split('&')[0]
                    .split('#')[0];
          }

          if (videoId.isNotEmpty && videoId.length == 11) {
            final youtubeAppUri = Uri.parse('youtube://watch?v=$videoId');
            if (await canLaunchUrl(youtubeAppUri)) {
              await launchUrl(
                youtubeAppUri,
                mode: LaunchMode.externalApplication,
              );
              return;
            }
          }
        } catch (e) {
          debugPrint("YouTube app scheme failed: $e");
        }
      }

      // Fallback: Open in built-in WebView browser using the original URL
      await _controller.loadRequest(youtubeUri);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening YouTube in browser'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error opening YouTube: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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
