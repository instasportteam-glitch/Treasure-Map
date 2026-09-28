import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

part 'webview_event.dart';
part 'webview_state.dart';

/// Page loading state for an [InAppWebView].
///
/// The widget forwards the web view callbacks as events; the bloc decides
/// what to show and drives (re)loading through the controller.
///
/// Resilience:
/// * a watchdog fails the load if nothing happens for [loadTimeout];
/// * failed loads are retried automatically up to [maxAutoRetries] times;
/// * harmless errors (cancelled redirects, sub-resources) are ignored.
class WebViewBloc extends Bloc<WebViewEvent, WebViewState> {
  WebViewBloc({
    this.loadTimeout = const Duration(seconds: 15),
    this.maxAutoRetries = 5,
  }) : super(const WebViewState()) {
    on<WebViewStarted>(_onStarted);
    on<WebViewCreated>(_onCreated);
    on<WebViewPageStarted>(_onPageStarted);
    on<WebViewProgressChanged>(_onProgress);
    on<WebViewPageFinished>(_onPageFinished);
    on<WebViewFailed>(_onFailed);
    on<WebViewReloadRequested>(_onReload);
    on<_WebViewAutoRetry>(_onAutoRetry);
  }

  final Duration loadTimeout;
  final int maxAutoRetries;

  InAppWebViewController? controller;
  String? _url;
  int _retries = 0;
  Timer? _watchdog;
  Timer? _retryTimer;

  /// Set when the current attempt failed. The native view may still report
  /// progress 100 / load stop for the failed attempt; those must not count
  /// as a successful load.
  bool _attemptFailed = false;

  Future<void> _load(Emitter<WebViewState> emit) async {
    final url = _url;
    final c = controller;
    if (url == null || c == null) return;
    _retryTimer?.cancel();
    _attemptFailed = false;
    emit(const WebViewState(status: WebViewStatus.loading));
    _armWatchdog();
    final uri = WebUri(url);
    if (!uri.hasScheme) {
      add(const WebViewFailed('Invalid page address.'));
      return;
    }
    await c.loadUrl(urlRequest: URLRequest(url: uri));
  }

  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(loadTimeout, () {
      if (!isClosed && state.isLoading) {
        add(const WebViewFailed('The connection timed out.'));
      }
    });
  }

  Future<void> _onStarted(
    WebViewStarted event,
    Emitter<WebViewState> emit,
  ) async {
    _url = event.url;
    _retries = 0;
    await _load(emit);
  }

  Future<void> _onCreated(
    WebViewCreated event,
    Emitter<WebViewState> emit,
  ) async {
    controller = event.controller;
    await _load(emit);
  }

  void _onPageStarted(WebViewPageStarted event, Emitter<WebViewState> emit) {
    if (state.status == WebViewStatus.loaded) return;
    _armWatchdog();
    emit(state.copyWith(status: WebViewStatus.loading));
  }

  void _onProgress(WebViewProgressChanged event, Emitter<WebViewState> emit) {
    if (state.status != WebViewStatus.loading || _attemptFailed) return;
    _armWatchdog();
    if (event.progress >= 100) {
      _markLoaded(emit);
    } else {
      emit(state.copyWith(progress: event.progress));
    }
  }

  void _onPageFinished(WebViewPageFinished event, Emitter<WebViewState> emit) {
    if (state.status == WebViewStatus.failure || _attemptFailed) return;
    _markLoaded(emit);
  }

  void _markLoaded(Emitter<WebViewState> emit) {
    _watchdog?.cancel();
    _retries = 0;
    emit(state.copyWith(status: WebViewStatus.loaded, progress: 100));
  }

  void _onFailed(WebViewFailed event, Emitter<WebViewState> emit) {
    // Once the page is on screen, a late error shouldn't hide it.
    if (state.status == WebViewStatus.loaded) return;
    // One failure per attempt (the view can report the same error twice).
    if (_attemptFailed) return;
    _attemptFailed = true;
    _watchdog?.cancel();

    if (_retries < maxAutoRetries) {
      _retries++;
      // 1s, 2s, 4s, 8s, 8s... Keep the loader on screen meanwhile.
      final delay = Duration(seconds: 1 << (_retries - 1).clamp(0, 3).toInt());
      _retryTimer?.cancel();
      _retryTimer = Timer(delay, () {
        if (!isClosed) add(const _WebViewAutoRetry());
      });
      emit(state.copyWith(status: WebViewStatus.loading, progress: 0));
      return;
    }

    emit(state.copyWith(
      status: WebViewStatus.failure,
      errorMessage: event.message,
    ));
  }

  Future<void> _onAutoRetry(
    _WebViewAutoRetry event,
    Emitter<WebViewState> emit,
  ) =>
      _load(emit);

  Future<void> _onReload(
    WebViewReloadRequested event,
    Emitter<WebViewState> emit,
  ) async {
    _retries = 0;
    await _load(emit);
  }

  @override
  Future<void> close() {
    _watchdog?.cancel();
    _retryTimer?.cancel();
    return super.close();
  }

  /// Returns an English message for a main-frame error, or `null` if the
  /// error is harmless and should be ignored.
  static String? messageFor(WebResourceRequest request, WebResourceError error) {
    // Sub-resource errors (images, scripts, iframes) don't break the page.
    if (request.isForMainFrame == false) return null;

    final t = error.type;
    // Redirects / superseded navigations.
    // 102 = WebKitErrorFrameLoadInterruptedByPolicyChange (iOS), e.g. when a
    // link is handed off to another app. No named constant for it in 6.1.x.
    if (t == WebResourceErrorType.CANCELLED || t.toNativeValue() == 102) {
      return null;
    }

    if (t == WebResourceErrorType.NOT_CONNECTED_TO_INTERNET) {
      return 'No internet connection.';
    }
    if (t == WebResourceErrorType.HOST_LOOKUP) {
      return 'Server not found. Check the address and your connection.';
    }
    if (t == WebResourceErrorType.CANNOT_CONNECT_TO_HOST ||
        t == WebResourceErrorType.SERVER_UNREACHABLE ||
        t == WebResourceErrorType.NETWORK_CONNECTION_LOST) {
      return 'Could not connect to the server.';
    }
    if (t == WebResourceErrorType.TIMEOUT) {
      return 'The connection timed out.';
    }
    if (t == WebResourceErrorType.FAILED_SSL_HANDSHAKE ||
        t == WebResourceErrorType.SECURE_CONNECTION_FAILED) {
      return 'Secure connection failed.';
    }
    if (t == WebResourceErrorType.BAD_URL ||
        t == WebResourceErrorType.UNSUPPORTED_SCHEME) {
      return 'Invalid page address.';
    }
    if (t == WebResourceErrorType.FILE_NOT_FOUND) return 'Page not found.';
    return 'Failed to load the page.';
  }
}
