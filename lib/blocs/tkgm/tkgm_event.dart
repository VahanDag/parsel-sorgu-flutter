import 'package:equatable/equatable.dart';

abstract class TkgmEvent extends Equatable {
  const TkgmEvent();

  @override
  List<Object?> get props => [];
}

class InitializeTkgmEvent extends TkgmEvent {
  final String url;

  const InitializeTkgmEvent(this.url);

  @override
  List<Object?> get props => [url];
}

class LoadLocationEvent extends TkgmEvent {
  const LoadLocationEvent();
}

class FetchParselDataEvent extends TkgmEvent {
  const FetchParselDataEvent();
}

class ToggleDetailsVisibilityEvent extends TkgmEvent {
  const ToggleDetailsVisibilityEvent();
}

class WebViewProgressChangedEvent extends TkgmEvent {
  final double progress;

  const WebViewProgressChangedEvent(this.progress);

  @override
  List<Object?> get props => [progress];
}

class RefreshPageEvent extends TkgmEvent {
  const RefreshPageEvent();
}

class CheckLocationStatusEvent extends TkgmEvent {
  const CheckLocationStatusEvent();
}