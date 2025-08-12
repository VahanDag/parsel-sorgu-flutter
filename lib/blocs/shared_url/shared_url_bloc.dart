import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parsel_sorgu/blocs/shared_url/shared_url_event.dart';
import 'package:parsel_sorgu/blocs/shared_url/shared_url_state.dart';
import 'package:parsel_sorgu/core/url_expander.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class SharedUrlBloc extends Bloc<SharedUrlEvent, SharedUrlState> {
  late StreamSubscription _intentSubscription;
  Function()? onInvalidUrl;
  bool _modalShown = false;
  String? _lastProcessedUrl; // Son işlenen URL'i takip et

  SharedUrlBloc({this.onInvalidUrl}) : super(const SharedUrlInitial()) {
    on<InitializeSharedUrl>(_onInitializeSharedUrl);
    on<SharedMediaReceived>(_onSharedMediaReceived);
    on<ShowInvalidUrlModal>(_onShowInvalidUrlModal);
    on<DismissInvalidUrlModal>(_onDismissInvalidUrlModal);
    on<ClearSharedUrl>(_onClearSharedUrl);

    // Shared intent stream'ini dinle
    _initializeSharedIntentListening();
  }

  void _initializeSharedIntentListening() {
    print("SharedUrlBloc: Initializing shared intent listening");

    // Uygulama açıkken gelen yeni paylaşımları dinle
    _intentSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        print("SharedUrlBloc: Received media stream: ${value.length} items");
        if (value.isNotEmpty) {
          final path = value.first.path;
          print("SharedUrlBloc: Processing first media item: $path");

          // Duplicate kontrolü - aynı URL tekrar geliyorsa işleme
          if (_lastProcessedUrl != path) {
            _lastProcessedUrl = path;
            add(SharedMediaReceived(value.first));
          } else {
            print("SharedUrlBloc: Duplicate URL detected, skipping: $path");
          }
        }
      },
      onError: (error) {
        print("SharedUrlBloc: Error in media stream: $error");
        add(const ShowInvalidUrlModal());
      },
    );
  }

  Future<void> _onInitializeSharedUrl(
    InitializeSharedUrl event,
    Emitter<SharedUrlState> emit,
  ) async {
    try {
      print("SharedUrlBloc: Initializing shared URL");
      emit(const SharedUrlProcessing());

      // Uygulama kapalıyken gelen ilk paylaşımı yakala
      final List<SharedMediaFile> initialMedia = await ReceiveSharingIntent.instance.getInitialMedia();

      print("SharedUrlBloc: Initial media count: ${initialMedia.length}");
      if (initialMedia.isNotEmpty) {
        final path = initialMedia.first.path;
        print("SharedUrlBloc: Processing initial media: $path");
        _lastProcessedUrl = path; // URL'i kaydet
        await _processSharedMedia(initialMedia.first, emit);
        // Intent'i temizle
        ReceiveSharingIntent.instance.reset();
      } else {
        print("SharedUrlBloc: No initial media, staying in initial state");
        emit(const SharedUrlInitial());
      }
    } catch (e) {
      print("SharedUrlBloc: Error during initialization: $e");
      emit(SharedUrlError('Paylaşım verisi alınamadı: $e'));
    }
  }

  Future<void> _onSharedMediaReceived(
    SharedMediaReceived event,
    Emitter<SharedUrlState> emit,
  ) async {
    print("SharedUrlBloc: Shared media received: ${event.media.path}");

    // Processing state'i emit et
    emit(const SharedUrlProcessing());

    // Küçük bir gecikme ekle (UI'nin processing state'ini görmesi için)
    await Future.delayed(const Duration(milliseconds: 50));

    await _processSharedMedia(event.media, emit);
  }

  Future<void> _processSharedMedia(
    SharedMediaFile media,
    Emitter<SharedUrlState> emit,
  ) async {
    try {
      final content = media.path;
      print("SharedUrlBloc: Processing content: $content");

      if (content.contains('sahibinden.com') || content.contains('shbd.io')) {
        print("SharedUrlBloc: Valid URL domain detected");
        String finalUrl = content;

        // Kısaltılmış URL ise genişlet
        if (content.contains('shbd.io')) {
          print("SharedUrlBloc: Expanding short URL");
          final expandedUrl = await UrlExpander.expandUrl(content);
          if (expandedUrl != null) {
            finalUrl = expandedUrl;
            print("SharedUrlBloc: URL expanded to: $finalUrl");
          }
        }

        print("SharedUrlBloc: Emitting SharedUrlReceived with URL: $finalUrl");

        // Timestamp ekleyerek her zaman farklı bir state olmasını sağla
        emit(SharedUrlReceived(finalUrl, timestamp: DateTime.now()));

        // State'in başarıyla emit edildiğini kontrol et
        print("SharedUrlBloc: Current state after emit: ${state.runtimeType}");
      } else {
        print("SharedUrlBloc: Invalid URL - emitting SharedUrlInvalid");
        // Geçersiz URL - modal göster
        emit(const SharedUrlInvalid());

        // Callback varsa ve modal henüz gösterilmemişse çağır
        if (onInvalidUrl != null && !_modalShown) {
          print("SharedUrlBloc: Calling onInvalidUrl callback");
          _modalShown = true;
          onInvalidUrl!();
        }
      }
    } catch (e) {
      print("SharedUrlBloc: Error processing shared media: $e");
      emit(SharedUrlError('URL işlenirken hata oluştu: $e'));
    }
  }

  void _onShowInvalidUrlModal(
    ShowInvalidUrlModal event,
    Emitter<SharedUrlState> emit,
  ) {
    emit(const SharedUrlInvalid());
  }

  void _onDismissInvalidUrlModal(
    DismissInvalidUrlModal event,
    Emitter<SharedUrlState> emit,
  ) {
    _modalShown = false; // Modal kapandığında flag'i sıfırla
    emit(const SharedUrlModalDismissed());
  }

  void _onClearSharedUrl(
    ClearSharedUrl event,
    Emitter<SharedUrlState> emit,
  ) {
    _lastProcessedUrl = null; // URL'i temizle
    emit(const SharedUrlInitial());
  }

  @override
  Future<void> close() {
    _intentSubscription.cancel();
    return super.close();
  }
}
