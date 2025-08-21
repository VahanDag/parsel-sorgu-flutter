import 'package:equatable/equatable.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

abstract class SharedUrlEvent extends Equatable {
  const SharedUrlEvent();

  @override
  List<Object?> get props => [];
}

// Uygulama başlatıldığında ilk shared URL'yi kontrol et
class InitializeSharedUrl extends SharedUrlEvent {
  const InitializeSharedUrl();
}

// Yeni shared media geldiğinde
class SharedMediaReceived extends SharedUrlEvent {
  final SharedMediaFile media;

  const SharedMediaReceived(this.media);

  @override
  List<Object?> get props => [media];
}

// Invalid URL modal'ını göster
class ShowInvalidUrlModal extends SharedUrlEvent {
  const ShowInvalidUrlModal();
}

// Invalid URL modal'ını kapat
class DismissInvalidUrlModal extends SharedUrlEvent {
  const DismissInvalidUrlModal();
}

// Shared URL'yi temizle
class ClearSharedUrl extends SharedUrlEvent {
  const ClearSharedUrl();
}

// Son URL'i yeniden emit et
class ReemitLastUrl extends SharedUrlEvent {
  const ReemitLastUrl();
}