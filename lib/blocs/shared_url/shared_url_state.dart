import 'package:equatable/equatable.dart';

abstract class SharedUrlState extends Equatable {
  const SharedUrlState();

  @override
  List<Object?> get props => [];
}

// Başlangıç durumu
class SharedUrlInitial extends SharedUrlState {
  const SharedUrlInitial();
}

// URL işleniyor
class SharedUrlProcessing extends SharedUrlState {
  const SharedUrlProcessing();
}

// Geçerli URL alındı
class SharedUrlReceived extends SharedUrlState {
  final String url;

  const SharedUrlReceived(this.url);

  @override
  List<Object?> get props => [url];
}

// Geçersiz URL - modal gösterilmeli
class SharedUrlInvalid extends SharedUrlState {
  const SharedUrlInvalid();
}

// Modal kapatıldı, normal akışa dön
class SharedUrlModalDismissed extends SharedUrlState {
  const SharedUrlModalDismissed();
}

// Hata durumu
class SharedUrlError extends SharedUrlState {
  final String message;

  const SharedUrlError(this.message);

  @override
  List<Object?> get props => [message];
}