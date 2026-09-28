part of 'webview_bloc.dart';

enum WebViewStatus { initial, loading, loaded, failure }

final class WebViewState extends Equatable {
  const WebViewState({
    this.status = WebViewStatus.initial,
    this.progress = 0,
    this.errorMessage,
  });

  final WebViewStatus status;

  /// Loading progress, 0..100.
  final int progress;
  final String? errorMessage;

  bool get isLoading =>
      status == WebViewStatus.initial || status == WebViewStatus.loading;

  WebViewState copyWith({
    WebViewStatus? status,
    int? progress,
    String? errorMessage,
  }) {
    return WebViewState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, progress, errorMessage];
}
