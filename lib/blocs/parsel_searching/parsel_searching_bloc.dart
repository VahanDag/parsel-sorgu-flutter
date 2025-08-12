import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
    on<ToggleSearchModeEvent>(_onToggleSearchMode);
    on<ManualSearchEvent>(_onManualSearch);
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

    await _debugWebViewContent(emit);

    try {
      // First, wait a bit to ensure page is fully loaded on iOS
      if (Platform.isIOS) {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Try multiple extraction methods for better compatibility
      dynamic result;

      // Method 1: Direct pageTrackData access
      result = await _webViewController!.evaluateJavascript(
        source: '''
        (function() {
          try {
            // Check if pageTrackData exists
            if (typeof pageTrackData !== 'undefined' && pageTrackData) {
              var data = {
                il: '',
                ilce: '',
                mahalle: '',
                adaNo: '',
                parselNo: ''
              };
              
              if (pageTrackData.customVars && Array.isArray(pageTrackData.customVars)) {
                pageTrackData.customVars.forEach(function(item) {
                  if (item && item.name && item.value) {
                    if (item.name === 'loc2') data.il = item.value;
                    if (item.name === 'loc3') data.ilce = item.value;
                    if (item.name === 'loc5') data.mahalle = item.value;
                    if (item.name === 'Ada No') data.adaNo = item.value;
                    if (item.name === 'Parsel No') data.parselNo = item.value;
                  }
                });
              }
              
              return JSON.stringify(data);
            }
            return null;
          } catch(e) {
            return JSON.stringify({error: e.toString()});
          }
        })();
      ''',
      );

      // If first method fails, try alternative extraction
      if (result == null || result == 'null') {
        print('Method 1 failed, trying alternative extraction...');

        // Method 2: Try with window.pageTrackData
        result = await _webViewController!.evaluateJavascript(
          source: '''
          (function() {
            try {
              // Try window.pageTrackData
              if (window.pageTrackData && window.pageTrackData.customVars) {
                var data = {
                  il: '',
                  ilce: '',
                  mahalle: '',
                  adaNo: '',
                  parselNo: ''
                };
                
                window.pageTrackData.customVars.forEach(function(item) {
                  if (item && item.name && item.value) {
                    switch(item.name) {
                      case 'loc2': data.il = item.value; break;
                      case 'loc3': data.ilce = item.value; break;
                      case 'loc5': data.mahalle = item.value; break;
                      case 'Ada No': data.adaNo = item.value; break;
                      case 'Parsel No': data.parselNo = item.value; break;
                    }
                  }
                });
                
                return JSON.stringify(data);
              }
              
              // Try to find the data in the page's script tags
              var scripts = document.getElementsByTagName('script');
              for (var i = 0; i < scripts.length; i++) {
                var content = scripts[i].innerHTML;
                if (content.includes('pageTrackData')) {
                  // Extract data from script content
                  var match = content.match(/pageTrackData\\s*=\\s*({[^}]+})/);
                  if (match) {
                    return JSON.stringify({found: 'in script', content: match[1]});
                  }
                }
              }
              
              return null;
            } catch(e) {
              return JSON.stringify({error: 'Method 2: ' + e.toString()});
            }
          })();
        ''',
        );
      }

      // Method 3: iOS-specific approach - inject and wait
      if ((result == null || result == 'null') && Platform.isIOS) {
        print('Trying iOS-specific extraction method...');

        // First inject a global function
        await _webViewController!.evaluateJavascript(
          source: '''
          window.extractParselData = function() {
            if (typeof pageTrackData === 'undefined') {
              return null;
            }
            var data = {
              il: '',
              ilce: '',
              mahalle: '',
              adaNo: '',
              parselNo: ''
            };
            
            if (pageTrackData.customVars) {
              for (var i = 0; i < pageTrackData.customVars.length; i++) {
                var item = pageTrackData.customVars[i];
                if (item.name === 'loc2') data.il = item.value;
                if (item.name === 'loc3') data.ilce = item.value;
                if (item.name === 'loc5') data.mahalle = item.value;
                if (item.name === 'Ada No') data.adaNo = item.value;
                if (item.name === 'Parsel No') data.parselNo = item.value;
              }
            }
            
            return JSON.stringify(data);
          };
        ''',
        );

        // Wait a moment for the function to register
        await Future.delayed(const Duration(milliseconds: 300));

        // Now call the function
        result = await _webViewController!.evaluateJavascript(
          source: 'window.extractParselData();',
        );
      }

      print('Extraction result: $result');

      if (result != null && result != 'null') {
        try {
          final data = json.decode(result);

          // Check if we got an error
          if (data['error'] != null) {
            print('JavaScript error: ${data['error']}');
            emit(state.copyWith(
              status: ParselSearchingStatus.error,
              errorMessage: 'Veri çıkarma hatası: ${data['error']}',
              statusMessage: 'JavaScript hatası',
            ));
            return;
          }

          // Check if we have valid data
          if (data['il'] != null || data['ilce'] != null) {
            emit(state.copyWith(
              parselData: data,
              status: ParselSearchingStatus.extracted,
              statusMessage: 'Parsel bilgileri alındı, TKGM\'ye yönlendiriliyor...',
              currentStep: 2,
            ));

            // TKGM ID'lerini bul ve yönlendir
            await _findMahalleIdAndRedirect(data, emit);
          } else {
            // Data structure exists but is empty
            emit(state.copyWith(
              status: ParselSearchingStatus.error,
              errorMessage: 'Parsel verileri boş. Lütfen doğru bir ilan sayfası açtığınızdan emin olun.',
              statusMessage: 'Veri bulunamadı',
            ));
          }
        } catch (e) {
          print('JSON parse error: $e');
          emit(state.copyWith(
            status: ParselSearchingStatus.error,
            errorMessage: 'Veri işleme hatası: ${e.toString()}',
            statusMessage: 'Parse hatası',
          ));
        }
      } else {
        // No data found at all
        emit(state.copyWith(
          status: ParselSearchingStatus.error,
          errorMessage: 'Sayfa verileri bulunamadı. Sayfanın tamamen yüklenmesini bekleyip tekrar deneyin.',
          statusMessage: 'Veri alınamadı',
        ));
      }
    } catch (e) {
      print('General extraction error: $e');
      emit(state.copyWith(
        status: ParselSearchingStatus.error,
        errorMessage: 'Veri alınamadı: ${e.toString()}',
        statusMessage: 'Veri çıkarma hatası',
      ));
    }
  }

  Future<void> _debugWebViewContent(Emitter<ParselSearchingState> emit) async {
    if (_webViewController == null) {
      print('WebViewController is null');
      return;
    }

    try {
      // 1. Check if JavaScript is enabled
      final jsEnabled = await _webViewController!.evaluateJavascript(
        source: 'typeof window !== "undefined"',
      );
      print('JavaScript enabled: $jsEnabled');

      // 2. Get current URL
      final currentUrl = await _webViewController!.getUrl();
      print('Current URL: $currentUrl');

      // 3. Check page title
      final title = await _webViewController!.evaluateJavascript(
        source: 'document.title',
      );
      print('Page title: $title');

      // 4. Check if pageTrackData exists
      final hasPageTrackData = await _webViewController!.evaluateJavascript(
        source: '''
        (function() {
          var checks = {
            direct: typeof pageTrackData !== 'undefined',
            window: typeof window.pageTrackData !== 'undefined',
            global: typeof global !== 'undefined' && typeof global.pageTrackData !== 'undefined'
          };
          return JSON.stringify(checks);
        })();
      ''',
      );
      print('pageTrackData existence: $hasPageTrackData');

      // 5. List all global variables (to find where data might be)
      final globals = await _webViewController!.evaluateJavascript(
        source: '''
        (function() {
          var globals = [];
          for (var key in window) {
            if (key.toLowerCase().includes('track') || 
                key.toLowerCase().includes('data') || 
                key.toLowerCase().includes('page')) {
              globals.push(key);
            }
          }
          return JSON.stringify(globals.slice(0, 20));
        })();
      ''',
      );
      print('Relevant global variables: $globals');

      // 6. Check for data in data attributes
      final dataAttributes = await _webViewController!.evaluateJavascript(
        source: '''
        (function() {
          var elements = document.querySelectorAll('[data-loc2], [data-loc3], [data-loc5], [data-ada], [data-parsel]');
          var data = [];
          elements.forEach(function(el) {
            data.push({
              tag: el.tagName,
              attrs: el.getAttributeNames().filter(n => n.startsWith('data-'))
            });
          });
          return JSON.stringify(data);
        })();
      ''',
      );
      print('Data attributes found: $dataAttributes');

      // 7. Try to find the data in script tags
      final scriptContent = await _webViewController!.evaluateJavascript(
        source: '''
        (function() {
          var scripts = document.getElementsByTagName('script');
          var found = [];
          for (var i = 0; i < scripts.length; i++) {
            var content = scripts[i].innerHTML || scripts[i].text || '';
            if (content.includes('pageTrackData') || 
                content.includes('loc2') || 
                content.includes('Ada No')) {
              found.push({
                index: i,
                hasPageTrackData: content.includes('pageTrackData'),
                hasLoc2: content.includes('loc2'),
                hasAdaNo: content.includes('Ada No'),
                length: content.length,
                snippet: content.substring(0, 200)
              });
            }
          }
          return JSON.stringify(found);
        })();
      ''',
      );
      print('Scripts with tracking data: $scriptContent');

      // 8. Check page readyState
      final readyState = await _webViewController!.evaluateJavascript(
        source: 'document.readyState',
      );
      print('Document ready state: $readyState');

      // 9. iOS-specific: Check if we're in a frame
      final inFrame = await _webViewController!.evaluateJavascript(
        source: 'window.self !== window.top',
      );
      print('In iframe: $inFrame');

      // 10. Try alternative data extraction paths
      final alternativeData = await _webViewController!.evaluateJavascript(
        source: '''
        (function() {
          var result = {
            method: 'none',
            data: null
          };
          
          // Method 1: Meta tags
          var metas = document.getElementsByTagName('meta');
          for (var i = 0; i < metas.length; i++) {
            if (metas[i].name && metas[i].name.includes('loc')) {
              result.method = 'meta';
              if (!result.data) result.data = {};
              result.data[metas[i].name] = metas[i].content;
            }
          }
          
          // Method 2: LD+JSON
          var ldJsons = document.querySelectorAll('script[type="application/ld+json"]');
          if (ldJsons.length > 0) {
            result.hasLdJson = true;
          }
          
          // Method 3: Look for specific text patterns
          var bodyText = document.body.innerText || '';
          if (bodyText.includes('Ada No:')) {
            result.hasAdaText = true;
          }
          
          return JSON.stringify(result);
        })();
      ''',
      );
      print('Alternative data sources: $alternativeData');
    } catch (e) {
      print('Debug error: $e');
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
      if (ilData.toString().contains("limit")) throw Exception("Günlük sorgu limitini aştınız");

      int? ilId;

      for (var feature in ilData['features']) {
        print("${feature['properties']['text'].toString().toLowerCase()} ${data['il'].toString().toLowerCase()}");
        if (feature['properties']['text'].toString().toLowerCase() == data['il'].toString().toLowerCase()) {
          print(feature['properties']['id'].toString().runtimeType);
          ilId = int.tryParse(feature['properties']['id'].toString());
          print("bitti il $ilId");
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
      print("veri çekildi ilce");

      final ilceData = json.decode(ilceResponse.body);
      if (ilceData.toString().contains("limit")) throw Exception("Günlük sorgu limitini aştınız");

      int? ilceId;

      for (var feature in ilceData['features']) {
        print("${feature['properties']['text'].toString().toLowerCase()} ${data['ilce'].toString().toLowerCase()}");
        if (feature['properties']['text'].toString().toLowerCase() == data['ilce'].toString().toLowerCase()) {
          ilceId = int.tryParse(feature['properties']['id'].toString());
          print("bitti ilce $ilceId");
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
      print("veri çekildi mahalle");
      final mahalleData = json.decode(mahalleResponse.body);
      if (mahalleData.toString().contains("limit")) throw Exception("Günlük sorgu limitini aştınız");

      int? mahalleId;

      final cleanMahalleName = data['mahalle'].toString().replaceAll(' Mh.', '').replaceAll(' Mah.', '').toLowerCase();

      for (var feature in mahalleData['features']) {
        final mahalleName = feature['properties']['text'].toString().toLowerCase();
        if (mahalleName == cleanMahalleName || mahalleName.contains(cleanMahalleName)) {
          print(feature['properties']['id'].toString());
          mahalleId = int.tryParse(feature['properties']['id'].toString());
          print("bitti mahalleId $mahalleId");

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
      print(e.toString());
      emit(state.copyWith(
        status: ParselSearchingStatus.error,
        errorMessage: 'Konum bilgileri alınamadı: ${e.toString()}',
        statusMessage: 'TKGM sorgu hatası ${e.toString().contains("limit") ? ': Günlük sorgu limitini aştınız' : ''}',
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

  void _onToggleSearchMode(ToggleSearchModeEvent event, Emitter<ParselSearchingState> emit) {
    final newMode = state.searchMode == SearchMode.webView ? SearchMode.manual : SearchMode.webView;
    emit(state.copyWith(
      searchMode: newMode,
      currentStep: 0,
      parselData: null,
      statusMessage: '',
      status: ParselSearchingStatus.initial,
      errorMessage: null,
    ));
  }

  void _onManualSearch(ManualSearchEvent event, Emitter<ParselSearchingState> emit) async {
    emit(state.copyWith(
      status: ParselSearchingStatus.extracting,
      statusMessage: 'Manuel sorgu hazırlanıyor...',
      currentStep: 2,
    ));

    final parselData = {
      'il': event.province,
      'ilce': event.district,
      'mahalle': event.neighborhood,
      'adaNo': event.adaNo,
      'parselNo': event.parselNo,
    };

    emit(state.copyWith(
      parselData: parselData,
      status: ParselSearchingStatus.extracted,
      statusMessage: 'Manuel veriler alındı, TKGM\'ye yönlendiriliyor...',
    ));

    // TKGM ID'lerini bul ve yönlendir
    await _findMahalleIdAndRedirect(parselData, emit);
  }
}
