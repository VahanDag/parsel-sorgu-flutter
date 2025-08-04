import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'parsel_searching_event.dart';
import 'parsel_searching_state.dart';

class ParselSearchingBloc extends Bloc<ParselSearchingEvent, ParselSearchingState> {
  InAppWebViewController? _webViewController;
  Timer? _loadingTimer;

  ParselSearchingBloc() : super(const ParselSearchingState()) {
    on<UrlChangedEvent>(_onUrlChanged);
    on<ClearUrlEvent>(_onClearUrl);
    on<LoadUrlEvent>(_onLoadUrl);
    on<ExtractDataEvent>(_onExtractData);
    on<WebViewReadyEvent>(_onWebViewReady);
    on<WebViewLoadStartEvent>(_onWebViewLoadStart);
    on<WebViewLoadStopEvent>(_onWebViewLoadStop);
    on<WebViewLoadErrorEvent>(_onWebViewLoadError);
    on<ToggleWebViewVisibilityEvent>(_onToggleWebViewVisibility);
    on<SetInitialUrlEvent>(_onSetInitialUrl);
  }

  @override
  Future<void> close() {
    _loadingTimer?.cancel();
    return super.close();
  }

  void setWebViewController(InAppWebViewController controller) {
    _webViewController = controller;
    add(const WebViewReadyEvent());
  }

  void _onUrlChanged(UrlChangedEvent event, Emitter<ParselSearchingState> emit) {
    emit(state.copyWith(
      url: event.url,
      currentStep: 0,
      parselData: null,
      statusMessage: '',
      status: ParselSearchingStatus.initial,
    ));
  }

  void _onClearUrl(ClearUrlEvent event, Emitter<ParselSearchingState> emit) {
    emit(state.copyWith(
      url: '',
      currentStep: 0,
      parselData: null,
      statusMessage: '',
      status: ParselSearchingStatus.initial,
    ));
  }

  void _onLoadUrl(LoadUrlEvent event, Emitter<ParselSearchingState> emit) async {
    if (!state.isValidUrl || _webViewController == null) {
      emit(state.copyWith(
        status: ParselSearchingStatus.error,
        errorMessage: 'Geçerli URL girin veya WebView hazır olmasını bekleyin',
      ));
      return;
    }

    emit(state.copyWith(
      status: ParselSearchingStatus.loading,
      statusMessage: 'Sayfa yükleniyor...',
      currentStep: 0,
      parselData: null,
    ));

    _loadingTimer?.cancel();
    _loadingTimer = Timer(const Duration(seconds: 30), () {
      if (state.status == ParselSearchingStatus.loading) {
        add(const WebViewLoadErrorEvent('Sayfa yükleme zaman aşımına uğradı'));
      }
    });

    try {
      await _webViewController!.loadUrl(
        urlRequest: URLRequest(url: WebUri(event.url)),
      );
    } catch (e) {
      _loadingTimer?.cancel();
      emit(state.copyWith(
        status: ParselSearchingStatus.error,
        statusMessage: 'URL yükleme hatası: $e',
        errorMessage: e.toString(),
      ));
    }
  }

  void _onExtractData(ExtractDataEvent event, Emitter<ParselSearchingState> emit) async {
    if (_webViewController == null) {
      emit(state.copyWith(
        status: ParselSearchingStatus.error,
        errorMessage: 'WebView hazır değil',
      ));
      return;
    }

    emit(state.copyWith(
      status: ParselSearchingStatus.extracting,
      statusMessage: 'Parsel bilgileri alınıyor...',
    ));

    try {
      final result = await _webViewController!.evaluateJavascript(
        source: '''
        (function() {
          if (typeof pageTrackData !== 'undefined') {
            var data = {
              il: '',
              ilce: '',
              mahalle: '',
              adaNo: '',
              parselNo: ''
            };
            
            if (pageTrackData.customVars) {
              pageTrackData.customVars.forEach(function(item) {
                if (item.name === 'loc2') data.il = item.value;
                if (item.name === 'loc3') data.ilce = item.value;
                if (item.name === 'loc5') data.mahalle = item.value;
                if (item.name === 'Ada No') data.adaNo = item.value;
                if (item.name === 'Parsel No') data.parselNo = item.value;
              });
            }
            
            return JSON.stringify(data);
          }
          return null;
        })();
      ''',
      );

      if (result != null) {
        final data = json.decode(result);
        emit(state.copyWith(
          parselData: data,
          status: ParselSearchingStatus.extracted,
          statusMessage: 'Parsel bilgileri alındı, TKGM\'ye yönlendiriliyor...',
          currentStep: 2,
        ));

        // TKGM ID'lerini bul ve yönlendir
        await _findMahalleIdAndRedirect(data, emit);
      } else {
        emit(state.copyWith(
          status: ParselSearchingStatus.error,
          errorMessage: 'Sayfa verileri bulunamadı',
          statusMessage: 'Veri alınamadı',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: ParselSearchingStatus.error,
        errorMessage: 'Veri alınamadı: ${e.toString()}',
        statusMessage: 'Veri çıkarma hatası',
      ));
    }
  }

  Future<void> _findMahalleIdAndRedirect(
    Map<String, dynamic> data,
    Emitter<ParselSearchingState> emit,
  ) async {
    try {
      emit(state.copyWith(statusMessage: 'TKGM sorgusu hazırlanıyor...'));

      // İl ID'sini bul
      final ilResponse = await http.get(
        Uri.parse('https://parselsorgu.tkgm.gov.tr/app/modules/administrativeQuery/data/ilListe.json'),
      );

      final ilData = json.decode(ilResponse.body);
      int? ilId;

      for (var feature in ilData['features']) {
        if (feature['properties']['text'].toString().toLowerCase() ==
            data['il'].toString().toLowerCase()) {
          ilId = feature['properties']['id'];
          break;
        }
      }

      if (ilId == null) throw Exception('İl bulunamadı');

      // İlçe ID'sini bul
      final ilceResponse = await http.get(
        Uri.parse('https://cbsapi.tkgm.gov.tr/megsiswebapi.v3.1/api/idariYapi/ilceListe/$ilId'),
        headers: {
          'Accept': 'application/json',
          'Origin': 'https://parselsorgu.tkgm.gov.tr',
          'Referer': 'https://parselsorgu.tkgm.gov.tr/',
        },
      );

      final ilceData = json.decode(ilceResponse.body);
      int? ilceId;

      for (var feature in ilceData['features']) {
        if (feature['properties']['text'].toString().toLowerCase() ==
            data['ilce'].toString().toLowerCase()) {
          ilceId = feature['properties']['id'];
          break;
        }
      }

      if (ilceId == null) throw Exception('İlçe bulunamadı');

      // Mahalle ID'sini bul
      final mahalleResponse = await http.get(
        Uri.parse('https://cbsapi.tkgm.gov.tr/megsiswebapi.v3.1/api/idariYapi/mahalleListe/$ilceId'),
        headers: {
          'Accept': 'application/json',
          'Origin': 'https://parselsorgu.tkgm.gov.tr',
          'Referer': 'https://parselsorgu.tkgm.gov.tr/',
        },
      );

      final mahalleData = json.decode(mahalleResponse.body);
      String? mahalleId;

      final cleanMahalleName = data['mahalle']
          .toString()
          .replaceAll(' Mh.', '')
          .replaceAll(' Mah.', '')
          .toLowerCase();

      for (var feature in mahalleData['features']) {
        final mahalleName = feature['properties']['text'].toString().toLowerCase();
        if (mahalleName == cleanMahalleName || mahalleName.contains(cleanMahalleName)) {
          mahalleId = feature['properties']['id'].toString();
          break;
        }
      }

      if (mahalleId == null) throw Exception('Mahalle bulunamadı');

      // Ada ve Parsel numaralarını temizle
      final adaNo = data['adaNo'].toString().replaceAll('.', '').replaceAll(',', '');
      final parselNo = data['parselNo'].toString().replaceAll('.', '').replaceAll(',', '');

      // TKGM URL'ini oluştur
      final tkgmUrl = 'https://parselsorgu.tkgm.gov.tr/#ara/idari/$mahalleId/$adaNo/$parselNo';

      emit(state.copyWith(
        statusMessage: 'TKGM sayfasına yönlendiriliyor...',
        parselData: {...data, 'tkgmUrl': tkgmUrl},
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ParselSearchingStatus.error,
        errorMessage: 'Konum bilgileri alınamadı: ${e.toString()}',
        statusMessage: 'TKGM sorgu hatası',
      ));
    }
  }

  void _onWebViewReady(WebViewReadyEvent event, Emitter<ParselSearchingState> emit) {
    emit(state.copyWith(isWebViewReady: true));
  }

  void _onWebViewLoadStart(WebViewLoadStartEvent event, Emitter<ParselSearchingState> emit) {
    emit(state.copyWith(
      status: ParselSearchingStatus.loading,
      statusMessage: 'Sayfa yükleniyor...',
    ));
  }

  void _onWebViewLoadStop(WebViewLoadStopEvent event, Emitter<ParselSearchingState> emit) {
    _loadingTimer?.cancel();
    emit(state.copyWith(
      status: ParselSearchingStatus.loaded,
      statusMessage: 'Sayfa yüklendi! Parseli sorgulamak için butona tıklayın.',
      currentStep: 1,
    ));
  }

  void _onWebViewLoadError(WebViewLoadErrorEvent event, Emitter<ParselSearchingState> emit) {
    _loadingTimer?.cancel();
    emit(state.copyWith(
      status: ParselSearchingStatus.error,
      statusMessage: 'Sayfa yükleme hatası: ${event.error}',
      errorMessage: event.error,
    ));
  }

  void _onToggleWebViewVisibility(ToggleWebViewVisibilityEvent event, Emitter<ParselSearchingState> emit) {
    emit(state.copyWith(showWebView: !state.showWebView));
  }

  void _onSetInitialUrl(SetInitialUrlEvent event, Emitter<ParselSearchingState> emit) {
    if (event.url != null && event.url!.isNotEmpty) {
      emit(state.copyWith(url: event.url!));
    }
  }
}