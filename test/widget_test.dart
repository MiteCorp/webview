import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:webview/app_config.dart';
import 'package:webview/main.dart';

void main() {
  testWidgets('app uses configured branding', (WidgetTester tester) async {
    await tester.pumpWidget(
      const WebViewApp(home: Scaffold(body: Text('WebView test content'))),
    );

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.title, AppConfig.appName);
    expect(find.text('WebView test content'), findsOneWidget);
  });

  test('web URLs stay inside the WebView', () {
    expect(shouldNavigateInWebView(AppConfig.websiteUri), isTrue);
    expect(
      shouldNavigateInWebView(Uri.parse('http://example.com/payment')),
      isTrue,
    );
    expect(shouldNavigateInWebView(Uri.parse('about:blank')), isTrue);
  });

  test('app-specific URLs are delegated to the operating system', () {
    expect(
      shouldNavigateInWebView(Uri.parse('mailto:support@example.com')),
      isFalse,
    );
    expect(shouldNavigateInWebView(Uri.parse('tel:+62123456789')), isFalse);
    expect(
      shouldNavigateInWebView(Uri.parse('whatsapp://send?phone=62123456789')),
      isFalse,
    );
  });

  test('performance mode is restricted to the configured website', () {
    final String configuredHost = AppConfig.websiteUri.host.replaceFirst(
      RegExp(r'^www\.'),
      '',
    );

    expect(isConfiguredWebsiteUri(AppConfig.websiteUri), isTrue);
    expect(
      isConfiguredWebsiteUri(
        Uri(scheme: 'https', host: 'checkout.$configuredHost', path: '/order'),
      ),
      isTrue,
    );
    expect(
      isConfiguredWebsiteUri(
        Uri(
          scheme: 'https',
          host: 'unrelated.invalid',
          path: '/$configuredHost',
        ),
      ),
      isFalse,
    );
    expect(
      isConfiguredWebsiteUri(
        Uri(scheme: 'https', host: '$configuredHost.evil.test'),
      ),
      isFalse,
    );
  });
}
