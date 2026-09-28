part of 'webview_bloc.dart';

sealed class WebViewEvent extends Equatable {
  const WebViewEvent();

  @override
  List<Object?> get props => [];
}

/// Sets the URL to open. Loading begins once the web view is created.
final class WebViewStarted extends WebViewEvent {
  const WebViewStarted(this.url);

  final String url;

  @override
  List<Object?> get props => [url];
}

/// The native web view is ready.
final class WebViewCreated extends WebViewEvent {
  const WebViewCreated(this.controller);

  final InAppWebViewController controller;

  @override
  List<Object?> get props => [controller];
}

final class WebViewPageStarted extends WebViewEvent {
  const WebViewPageStarted();
}

final class WebViewProgressChanged extends WebViewEvent {
  const WebViewProgressChanged(this.progress);

  final int progress;

  @override
  List<Object?> get props => [progress];
}

final class WebViewPageFinished extends WebViewEvent {
  const WebViewPageFinished();
}

final class WebViewFailed extends WebViewEvent {
  const WebViewFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class WebViewReloadRequested extends WebViewEvent {
  const WebViewReloadRequested();
}

/// Internal: scheduled automatic retry.
final class _WebViewAutoRetry extends WebViewEvent {
  const _WebViewAutoRetry();
}
