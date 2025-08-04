import 'package:equatable/equatable.dart';

abstract class ParselSearchingEvent extends Equatable {
  const ParselSearchingEvent();

  @override
  List<Object?> get props => [];
}

class UrlChangedEvent extends ParselSearchingEvent {
  final String url;

  const UrlChangedEvent(this.url);

  @override
  List<Object?> get props => [url];
}

class ClearUrlEvent extends ParselSearchingEvent {
  const ClearUrlEvent();
}

class LoadUrlEvent extends ParselSearchingEvent {
  final String url;

  const LoadUrlEvent(this.url);

  @override
  List<Object?> get props => [url];
}

class ExtractDataEvent extends ParselSearchingEvent {
  const ExtractDataEvent();
}

class WebViewReadyEvent extends ParselSearchingEvent {
  const WebViewReadyEvent();
}

class WebViewLoadStartEvent extends ParselSearchingEvent {
  final String url;

  const WebViewLoadStartEvent(this.url);

  @override
  List<Object?> get props => [url];
}

class WebViewLoadStopEvent extends ParselSearchingEvent {
  final String url;

  const WebViewLoadStopEvent(this.url);

  @override
  List<Object?> get props => [url];
}

class WebViewLoadErrorEvent extends ParselSearchingEvent {
  final String error;

  const WebViewLoadErrorEvent(this.error);

  @override
  List<Object?> get props => [error];
}

class ToggleWebViewVisibilityEvent extends ParselSearchingEvent {
  const ToggleWebViewVisibilityEvent();
}

class SetInitialUrlEvent extends ParselSearchingEvent {
  final String? url;

  const SetInitialUrlEvent(this.url);

  @override
  List<Object?> get props => [url];
}