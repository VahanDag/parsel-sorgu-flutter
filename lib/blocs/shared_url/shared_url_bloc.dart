import 'dart:async';

import 'package:flutter/material.dart';
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
    on<ReemitLastUrl>(_onReemitLastUrl);

    // Shared intent stream'ini dinle
    _initializeSharedIntentListening();
  }

  void _initializeSharedIntentListening() {
    debugPrint("SharedUrlBloc: Initializing shared intent listening");

    // Uygulama açıkken gelen yeni paylaşımları dinle
    _intentSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        debugPrint("SharedUrlBloc: Received media stream: ${value.length} items");
        if (value.isNotEmpty) {
          final path = value.first.path;
          debugPrint("SharedUrlBloc: Processing first media item: $path");

          // Duplicate kontrolü - aynı URL tekrar geliyorsa işleme
          if (_lastProcessedUrl != path) {
            _lastProcessedUrl = path;
            add(SharedMediaReceived(value.first));
          } else {
            debugPrint("SharedUrlBloc: Duplicate URL detected, skipping: $path");
          }
        }
      },
      onError: (error) {
        debugPrint("SharedUrlBloc: Error in media stream: $error");
        add(const ShowInvalidUrlModal());
      },
    );
  }

  Future<void> _onInitializeSharedUrl(
    InitializeSharedUrl event,
    Emitter<SharedUrlState> emit,
  ) async {
    try {
      debugPrint("SharedUrlBloc: Initializing shared URL");
      emit(const SharedUrlProcessing());

      // Uygulama kapalıyken gelen ilk paylaşımı yakala
      final List<SharedMediaFile> initialMedia = await ReceiveSharingIntent.instance.getInitialMedia();

      debugPrint("SharedUrlBloc: Initial media count: ${initialMedia.length}");
      if (initialMedia.isNotEmpty) {
        final path = initialMedia.first.path;
        debugPrint("SharedUrlBloc: Processing initial media: $path");
        _lastProcessedUrl = path; // URL'i kaydet
        await _processSharedMedia(initialMedia.first, emit);
        // Intent'i temizle
        ReceiveSharingIntent.instance.reset();
      } else {
        debugPrint("SharedUrlBloc: No initial media, staying in initial state");
        emit(const SharedUrlInitial());
      }
    } catch (e) {
      debugPrint("SharedUrlBloc: Error during initialization: $e");
      emit(SharedUrlError('Paylaşım verisi alınamadı: $e'));
    }
  }

  Future<void> _onSharedMediaReceived(
    SharedMediaReceived event,
    Emitter<SharedUrlState> emit,
  ) async {
    debugPrint("SharedUrlBloc: Shared media received: ${event.media.path}");

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
      debugPrint("SharedUrlBloc: Processing content: $content");

      if (content.contains('sahibinden.com') || content.contains('shbd.io')) {
        debugPrint("SharedUrlBloc: Valid URL domain detected");
        String finalUrl = content;

        // Kısaltılmış URL ise genişlet
        if (content.contains('shbd.io')) {
          debugPrint("SharedUrlBloc: Expanding short URL");
          final expandedUrl = await UrlExpander.expandUrl(content);
          if (expandedUrl != null && expandedUrl != content) {
            finalUrl = expandedUrl;
            debugPrint("SharedUrlBloc: URL expanded to: $finalUrl");
          } else {
            debugPrint("SharedUrlBloc: URL expansion failed or returned same URL, using original: $content");
            finalUrl = content; // Genişletme başarısız olsa bile orijinal URL'i kullan
          }
        }

        debugPrint("SharedUrlBloc: Emitting SharedUrlReceived with URL: $finalUrl");

        // Timestamp ekleyerek her zaman farklı bir state olmasını sağla
        emit(SharedUrlReceived(finalUrl, timestamp: DateTime.now()));

        // State'in başarıyla emit edildiğini kontrol et
        debugPrint("SharedUrlBloc: Current state after emit: ${state.runtimeType}");
      } else {
        debugPrint("SharedUrlBloc: Invalid URL - emitting SharedUrlInvalid");
        // Geçersiz URL - modal göster
        emit(const SharedUrlInvalid());

        // Callback varsa ve modal henüz gösterilmemişse çağır
        if (onInvalidUrl != null && !_modalShown) {
          debugPrint("SharedUrlBloc: Calling onInvalidUrl callback");
          _modalShown = true;
          onInvalidUrl!();
        }
      }
    } catch (e) {
      debugPrint("SharedUrlBloc: Error processing shared media: $e");
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

  void _onReemitLastUrl(
    ReemitLastUrl event,
    Emitter<SharedUrlState> emit,
  ) {
    if (state is SharedUrlReceived) {
      final currentState = state as SharedUrlReceived;
      debugPrint("SharedUrlBloc: Re-emitting last URL: ${currentState.url}");
      // Yeni timestamp ile emit et
      emit(SharedUrlReceived(currentState.url, timestamp: DateTime.now()));
    }
  }

  @override
  Future<void> close() {
    _intentSubscription.cancel();
    return super.close();
  }
}
