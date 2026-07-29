import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppConfig.backgroundColor,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppConfig.backgroundColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const WebViewApp());
}

bool shouldNavigateInWebView(Uri uri) {
  return const <String>{
    '',
    'about',
    'blob',
    'data',
    'http',
    'https',
  }.contains(uri.scheme.toLowerCase());
}

bool isConfiguredWebsiteUri(Uri uri) => AppConfig.isFirstPartyUri(uri);

bool get isWebViewSupported {
  if (kIsWeb) {
    return false;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS => true,
    _ => false,
  };
}

class WebViewApp extends StatelessWidget {
  const WebViewApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConfig.primaryColor,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: AppConfig.backgroundColor,
      ),
      home: home ?? const _PlatformAwareHome(),
    );
  }
}

class _PlatformAwareHome extends StatelessWidget {
  const _PlatformAwareHome();

  @override
  Widget build(BuildContext context) {
    if (isWebViewSupported) {
      return const WebsiteWebView();
    }

    return const UnsupportedPlatformScreen();
  }
}

class WebsiteWebView extends StatefulWidget {
  const WebsiteWebView({super.key});

  @override
  State<WebsiteWebView> createState() => _WebsiteWebViewState();
}

class _WebsiteWebViewState extends State<WebsiteWebView> {
  static const String _performanceModeScript = r'''
(() => {
  const styleId = 'webview-app-performance-mode';
  if (document.getElementById(styleId)) return;

  const style = document.createElement('style');
  style.id = styleId;
  style.textContent = `
    html {
      scroll-behavior: auto !important;
    }

    *,
    *::before,
    *::after {
      animation-delay: 0ms !important;
      animation-duration: 0.01ms !important;
      animation-iteration-count: 1 !important;
      scroll-behavior: auto !important;
      transition-delay: 0ms !important;
      transition-duration: 0.01ms !important;
    }
  `;
  (document.head || document.documentElement).appendChild(style);

  document.querySelectorAll('video[autoplay]').forEach((video) => {
    video.autoplay = false;
    video.preload = 'metadata';
    video.pause();
  });
})();
''';

  late final WebViewController _controller;
  late final Widget _webViewWidget;
  bool _isInitialLoading = true;
  bool _canGoBack = false;
  String? _mainFrameError;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _webViewWidget = RepaintBoundary(child: _createWebViewWidget());
    unawaited(_initializeWebView());
  }

  Widget _createWebViewWidget() {
    PlatformWebViewWidgetCreationParams params =
        PlatformWebViewWidgetCreationParams(
          controller: _controller.platform,
          layoutDirection: TextDirection.ltr,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
          },
        );

    if (_controller.platform is AndroidWebViewController) {
      params =
          AndroidWebViewWidgetCreationParams.fromPlatformWebViewWidgetCreationParams(
            params,
            displayWithHybridComposition: false,
          );
    }

    return WebViewWidget.fromPlatformCreationParams(params: params);
  }

  Future<void> _initializeWebView() async {
    try {
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _controller.setBackgroundColor(AppConfig.backgroundColor);
      await _controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: _handlePageStarted,
          onPageFinished: _handlePageFinished,
          onWebResourceError: _handleWebResourceError,
          onNavigationRequest: _handleNavigationRequest,
        ),
      );
      await _configureAndroidPerformance();
      await _controller.loadRequest(AppConfig.websiteUri);
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInitialLoading = false;
        _mainFrameError = error.toString();
      });
    }
  }

  Future<void> _configureAndroidPerformance() async {
    final platformController = _controller.platform;
    if (platformController is! AndroidWebViewController) {
      return;
    }

    try {
      await platformController.setMediaPlaybackRequiresUserGesture(true);
      await platformController.setOverScrollMode(WebViewOverScrollMode.never);
    } on Exception {
      // Optional performance settings must not prevent the website from loading.
    }
  }

  void _handlePageStarted(String _) {
    if (!mounted) {
      return;
    }

    setState(() {
      _mainFrameError = null;
    });
  }

  void _handlePageFinished(String url) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isInitialLoading = false;
    });
    _applyPagePerformanceMode(url);
    _refreshBackAvailability();
  }

  void _applyPagePerformanceMode(String url) {
    final Uri? uri = Uri.tryParse(url);
    if (!AppConfig.enablePerformanceMode ||
        uri == null ||
        !isConfiguredWebsiteUri(uri)) {
      return;
    }

    unawaited(_runPerformanceModeScript());
  }

  Future<void> _runPerformanceModeScript() async {
    try {
      await _controller.runJavaScript(_performanceModeScript);
    } on Exception {
      // The app remains usable if a page blocks JavaScript injection.
    }
  }

  void _handleWebResourceError(WebResourceError error) {
    if (error.isForMainFrame != true || !mounted) {
      return;
    }

    setState(() {
      _isInitialLoading = false;
      _mainFrameError = error.description;
    });
  }

  Future<NavigationDecision> _handleNavigationRequest(
    NavigationRequest request,
  ) async {
    final Uri? uri = Uri.tryParse(request.url);
    if (uri == null) {
      return NavigationDecision.prevent;
    }

    if (shouldNavigateInWebView(uri)) {
      return NavigationDecision.navigate;
    }

    final bool didLaunch = await _launchExternally(uri);
    if (!didLaunch && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tautan tidak dapat dibuka di perangkat ini.'),
        ),
      );
    }
    return NavigationDecision.prevent;
  }

  Future<bool> _launchExternally(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }

  Future<void> _refreshBackAvailability() async {
    final bool canGoBack = await _controller.canGoBack();
    if (!mounted || canGoBack == _canGoBack) {
      return;
    }

    setState(() {
      _canGoBack = canGoBack;
    });
  }

  Future<void> _handlePop(bool didPop, Object? result) async {
    if (didPop) {
      return;
    }

    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _canGoBack = false;
    });
    await Navigator.of(context).maybePop(result);
  }

  Future<void> _retry() async {
    setState(() {
      _isInitialLoading = true;
      _mainFrameError = null;
    });
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_canGoBack,
      onPopInvokedWithResult: _handlePop,
      child: Scaffold(
        body: SafeArea(
          bottom: true,
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: _webViewWidget),
              if (_isInitialLoading && _mainFrameError == null)
                const Positioned.fill(child: _InitialLoadingView()),
              if (_mainFrameError case final String error)
                Positioned.fill(
                  child: _LoadErrorView(error: error, onRetry: _retry),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitialLoadingView extends StatelessWidget {
  const _InitialLoadingView();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppConfig.backgroundColor,
      child: Center(
        child: CircularProgressIndicator(color: AppConfig.primaryColor),
      ),
    );
  }
}

class _LoadErrorView extends StatelessWidget {
  const _LoadErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppConfig.backgroundColor,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: AppConfig.primaryColor,
              ),
              const SizedBox(height: 20),
              Text(
                'Website tidak dapat dimuat',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Periksa koneksi internet Anda lalu coba lagi.\n$error',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UnsupportedPlatformScreen extends StatelessWidget {
  const UnsupportedPlatformScreen({super.key});

  Future<void> _openWebsite(BuildContext context) async {
    try {
      if (await launchUrl(AppConfig.websiteUri)) {
        return;
      }
    } on Exception {
      // The error message below is enough for users on unsupported platforms.
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Browser tidak dapat dibuka.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.open_in_browser_rounded,
                size: 56,
                color: AppConfig.primaryColor,
              ),
              const SizedBox(height: 20),
              Text(
                'WebView tidak tersedia',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Gunakan aplikasi ini di Android, iOS, atau macOS.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _openWebsite(context),
                icon: const Icon(Icons.language_rounded),
                label: const Text('Buka website'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
