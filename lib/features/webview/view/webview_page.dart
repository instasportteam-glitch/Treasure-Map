import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bloc/webview_bloc.dart';
import '../widgets/shiny_loader.dart';

const kDarkPurple = Color(0xFF1A0B2E);
const _kDeepPurple = Color(0xFF2E1250);

/// Schemes the web view opens itself. Anything else (tel:, mailto:,
/// intent:, whatsapp:, app store links...) is handed to the OS.
const _webSchemes = {'http', 'https', 'about', 'data', 'blob', 'javascript', 'file'};

/// Minimal settings that make ordinary sites behave like in a browser.
final _settings = InAppWebViewSettings(
  // Content
  javaScriptEnabled: true,
  javaScriptCanOpenWindowsAutomatically: true,
  domStorageEnabled: true, // localStorage/sessionStorage (Android)
  databaseEnabled: true, // IndexedDB/WebSQL (Android)
  thirdPartyCookiesEnabled: true, // logins via OAuth/SSO (Android)
  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
  // Media
  mediaPlaybackRequiresUserGesture: false,
  allowsInlineMediaPlayback: true, // otherwise iOS forces fullscreen video
  // Navigation
  useShouldOverrideUrlLoading: true, // to hand tel:/mailto: to the OS
  supportMultipleWindows: true, // to catch target="_blank" links
  allowsBackForwardNavigationGestures: true, // iOS swipe back
  // Rendering
  useHybridComposition: true, // correct keyboard/input on Android
  transparentBackground: true, // no white flash before the page paints
  isInspectable: kDebugMode, // Safari / Chrome devtools in debug
);

class WebViewPage extends StatelessWidget {
  const WebViewPage({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => WebViewBloc()..add(WebViewStarted(url)),
      child: const WebViewView(),
    );
  }
}

class WebViewView extends StatelessWidget {
  const WebViewView({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<WebViewBloc>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final c = bloc.controller;
        if (c != null && await c.canGoBack()) {
          await c.goBack();
        } else {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: kDarkPurple,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InAppWebView(
                  initialSettings: _settings,
                  onWebViewCreated: (c) => bloc.add(WebViewCreated(c)),
                  onLoadStart: (_, __) => bloc.add(const WebViewPageStarted()),
                  onProgressChanged: (_, p) =>
                      bloc.add(WebViewProgressChanged(p)),
                  onLoadStop: (_, __) => bloc.add(const WebViewPageFinished()),
                  onReceivedError: (_, request, error) {
                    final message = WebViewBloc.messageFor(request, error);
                    if (message != null) bloc.add(WebViewFailed(message));
                  },
                  shouldOverrideUrlLoading: (_, action) async {
                    final uri = action.request.url;
                    if (uri == null || _webSchemes.contains(uri.scheme)) {
                      return NavigationActionPolicy.ALLOW;
                    }
                    try {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (_) {}
                    return NavigationActionPolicy.CANCEL;
                  },
                  // target="_blank" / window.open: open in the same view.
                  onCreateWindow: (c, action) async {
                    final uri = action.request.url;
                    if (uri != null) {
                      await c.loadUrl(urlRequest: URLRequest(url: uri));
                    }
                    return false;
                  },
                  // Camera/microphone for sites that ask (video calls, QR).
                  onPermissionRequest: (_, request) async =>
                      PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.GRANT,
                  ),
                ),
              ),
              BlocBuilder<WebViewBloc, WebViewState>(
                buildWhen: (p, c) => p.status != c.status,
                builder: (context, state) {
                  final showOverlay = state.status != WebViewStatus.loaded;
                  return Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !showOverlay,
                      child: AnimatedOpacity(
                        opacity: showOverlay ? 1 : 0,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        child: state.status == WebViewStatus.failure
                            ? _ErrorOverlay(message: state.errorMessage)
                            : const _LoadingOverlay(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.1),
          radius: 1.1,
          colors: [_kDeepPurple, kDarkPurple, Color(0xFF0E0519)],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: Center(child: child),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return _Background(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ShinyLoader(),
          const SizedBox(height: 28),
          BlocSelector<WebViewBloc, WebViewState, int>(
            selector: (s) => s.progress,
            builder: (context, progress) => Text(
              '$progress%',
              style: const TextStyle(
                color: Color(0xFFD1B3FF),
                fontSize: 14,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return _Background(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: Color(0xFFB388FF), size: 56),
            const SizedBox(height: 16),
            Text(
              message ?? 'Failed to load the page',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF),
              ),
              onPressed: () => context
                  .read<WebViewBloc>()
                  .add(const WebViewReloadRequested()),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
