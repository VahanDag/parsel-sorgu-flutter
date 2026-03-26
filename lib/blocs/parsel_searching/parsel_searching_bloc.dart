import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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
    String processedUrl = event.url.trim();

    // Eğer URL boş değilse ve http/https ile başlamıyorsa, https ekle
    if (processedUrl.isNotEmpty && !processedUrl.startsWith('http://') && !processedUrl.startsWith('https://')) {
      processedUrl = 'https://$processedUrl';
    }

    emit(state.copyWith(
      url: processedUrl,
      currentStep: 0,
      parselData: null,
      statusMessage: '',
      status: ParselSearchingStatus.initial,
      isCloudFlareChallenge: false,
    ));
  }

  void _onClearUrl(ClearUrlEvent event, Emitter<ParselSearchingState> emit) {
    emit(state.copyWith(
      url: '',
      currentStep: 0,
      parselData: null,
      statusMessage: '',
      status: ParselSearchingStatus.initial,
      isCloudFlareChallenge: false,
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
      isCloudFlareChallenge: false,
    ));

    _loadingTimer?.cancel();
    _loadingTimer = Timer(const Duration(seconds: 60), () {
      // CloudFlare için süreyi artırdık
      if (state.status == ParselSearchingStatus.loading) {
        add(const WebViewLoadErrorEvent('Sayfa yükleme zaman aşımına uğradı'));
      }
    });

    try {
      await _webViewController!.loadUrl(
        urlRequest: URLRequest(url: WebUri(event.url)),
      );
      debugPrint("URL yükleme başlatıldı");
      // CloudFlare'ın tamamen yüklenmesi için herhangi bir işlem yapmıyoruz
      // onLoadStop callback'inde beklemeyi yapacağız
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
        debugPrint('Method 1 failed, trying alternative extraction...');

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
        debugPrint('Trying iOS-specific extraction method...');

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

      debugPrint('Extraction result: $result');

      if (result != null && result != 'null') {
        try {
          final data = json.decode(result);

          // Check if we got an error
          if (data['error'] != null) {
            debugPrint('JavaScript error: ${data['error']}');
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
          debugPrint('JSON parse error: $e');
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
      debugPrint('General extraction error: $e');
      emit(state.copyWith(
        status: ParselSearchingStatus.error,
        errorMessage: 'Veri alınamadı: ${e.toString()}',
        statusMessage: 'Veri çıkarma hatası',
      ));
    }
  }

  Future<void> _debugWebViewContent(Emitter<ParselSearchingState> emit) async {
    if (_webViewController == null) {
      debugPrint('WebViewController is null');
      return;
    }

    try {
      // 1. Check if JavaScript is enabled
      final jsEnabled = await _webViewController!.evaluateJavascript(
        source: 'typeof window !== "undefined"',
      );
      debugPrint('JavaScript enabled: $jsEnabled');

      // 2. Get current URL
      final currentUrl = await _webViewController!.getUrl();
      debugPrint('Current URL: $currentUrl');

      // 3. Check page title
      final title = await _webViewController!.evaluateJavascript(
        source: 'document.title',
      );
      debugPrint('Page title: $title');

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
      debugPrint('pageTrackData existence: $hasPageTrackData');

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
      debugPrint('Relevant global variables: $globals');

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
      debugPrint('Data attributes found: $dataAttributes');

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
      debugPrint('Scripts with tracking data: $scriptContent');

      // 8. Check page readyState
      final readyState = await _webViewController!.evaluateJavascript(
        source: 'document.readyState',
      );
      debugPrint('Document ready state: $readyState');

      // 9. iOS-specific: Check if we're in a frame
      final inFrame = await _webViewController!.evaluateJavascript(
        source: 'window.self !== window.top',
      );
      debugPrint('In iframe: $inFrame');

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
      debugPrint('Alternative data sources: $alternativeData');
    } catch (e) {
      debugPrint('Debug error: $e');
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
        debugPrint("${feature['properties']['text'].toString().toLowerCase()} ${data['il'].toString().toLowerCase()}");
        if (feature['properties']['text'].toString().toLowerCase() == data['il'].toString().toLowerCase()) {
          debugPrint("${feature['properties']['id'].toString().runtimeType}");
          ilId = int.tryParse(feature['properties']['id'].toString());
          debugPrint("bitti il $ilId");
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
      debugPrint("veri çekildi ilce");

      final ilceData = json.decode(ilceResponse.body);
      if (ilceData.toString().contains("limit")) throw Exception("Günlük sorgu limitini aştınız");
      if (ilceData is! Map || ilceData['features'] == null) {
        throw Exception('TKGM servisleri şu anda yanıt vermiyor. Lütfen daha sonra tekrar deneyin.');
      }

      int? ilceId;

      for (var feature in ilceData['features']) {
        if (feature['properties']['text'].toString().toLowerCase() == data['ilce'].toString().toLowerCase()) {
          ilceId = int.tryParse(feature['properties']['id'].toString());
          debugPrint("bitti ilce $ilceId");
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
      debugPrint("veri çekildi mahalle");
      final mahalleData = json.decode(mahalleResponse.body);
      if (mahalleData.toString().contains("limit")) throw Exception("Günlük sorgu limitini aştınız");
      if (mahalleData is! Map || mahalleData['features'] == null) {
        throw Exception('TKGM servisleri şu anda yanıt vermiyor. Lütfen daha sonra tekrar deneyin.');
      }

      int? mahalleId;

      final cleanMahalleName = data['mahalle'].toString().replaceAll(' Mh.', '').replaceAll(' Mah.', '').toLowerCase();

      // İlk önce tam eşleşme ara
      for (var feature in mahalleData['features']) {
        final mahalleName = feature['properties']['text'].toString().toLowerCase();
        debugPrint("$mahalleName $cleanMahalleName");

        if (mahalleName == cleanMahalleName || mahalleName.contains(cleanMahalleName) || cleanMahalleName.contains(mahalleName)) {
          debugPrint(feature['properties']['id'].toString());
          mahalleId = int.tryParse(feature['properties']['id'].toString());
          debugPrint("bitti mahalleId (tam eşleşme) $mahalleId");
          break;
        }
      }

      // Tam eşleşme bulunamazsa fuzzy matching ile ara
      if (mahalleId == null) {
        debugPrint("Tam eşleşme bulunamadı, fuzzy matching başlatılıyor...");
        double bestSimilarity = 0.0;
        Map<String, dynamic>? bestMatch;

        for (var feature in mahalleData['features']) {
          final mahalleName = feature['properties']['text'].toString().toLowerCase();
          final similarity = _calculateStringSimilarity(cleanMahalleName, mahalleName);

          debugPrint("'$mahalleName' vs '$cleanMahalleName' => ${(similarity * 100).toStringAsFixed(1)}%");

          // En az %60 benzerlik ve önceki en iyi eşleşmeden daha iyi ise
          if (similarity > 0.6 && similarity > bestSimilarity) {
            bestSimilarity = similarity;
            bestMatch = feature;
            debugPrint("Yeni en iyi eşleşme: '$mahalleName' (${(bestSimilarity * 100).toStringAsFixed(1)}%)");
          }
        }

        if (bestMatch != null) {
          mahalleId = int.tryParse(bestMatch['properties']['id'].toString());
          debugPrint("bitti mahalleId (fuzzy matching) $mahalleId - benzerlik: ${(bestSimilarity * 100).toStringAsFixed(1)}%");
          debugPrint("Eşleşen: '${bestMatch['properties']['text']}' <- '$cleanMahalleName'");
        } else {
          debugPrint("Fuzzy matching ile de eşleşme bulunamadı (min %60 benzerlik gerekli)");
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
      debugPrint(e.toString());
      emit(state.copyWith(
        status: ParselSearchingStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
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

  void _onWebViewLoadStop(WebViewLoadStopEvent event, Emitter<ParselSearchingState> emit) async {
    _loadingTimer?.cancel();

    // Sayfa içeriğinin tam yüklenip yüklenmediğini kontrol et
    emit(state.copyWith(
      statusMessage: 'Sayfa içeriği kontrol ediliyor...',
    ));

    // Biraz bekle ki sayfa tamamen yüklensin
    await Future.delayed(const Duration(seconds: 2));

    try {
      final currentUrl = await _webViewController?.getUrl();
      debugPrint(currentUrl.toString());
      // Sahibinden.com sayfası değilse sadece yüklendi durumuna geç, parsel sorgula aktif olmasın
      if (currentUrl == null || !currentUrl.toString().contains('sahibinden.com')) {
        emit(state.copyWith(
          status: ParselSearchingStatus.loaded,
          statusMessage: 'Sayfa yüklendi.',
          currentStep: 0,
          isCloudFlareChallenge: false,
        ));
        return;
      }

      // Sahibinden.com sayfa içeriğini kontrol et
      final pageContentCheck = await _webViewController?.evaluateJavascript(
        source: '''
        (function() {
          try {
            var body = document.body ? document.body.innerText.toLowerCase() : '';
            var title = document.title.toLowerCase();
            
            // CloudFlare challenge göstergeleri
            var isCloudFlareChallenge = body.includes('checking if the site connection is secure') ||
                                        body.includes('just a moment') ||
                                        body.includes('please wait') ||
                                        title.includes('just a moment') ||
                                        body.includes('ddos protection');
            
            // pageTrackData var mı kontrol et (gerçek sayfa içeriği)
            var hasPageTrackData = typeof pageTrackData !== 'undefined' && pageTrackData !== null;
            
            // Sahibinden içerik göstergeleri
            var hasSahibindenContent = body.includes('ilan') || 
                                       body.includes('emlak') || 
                                       body.includes('satılık') ||
                                       body.includes('kiralık') ||
                                       hasPageTrackData;
            
            return {
              isCloudFlareChallenge: isCloudFlareChallenge,
              hasPageTrackData: hasPageTrackData,
              hasSahibindenContent: hasSahibindenContent,
              bodyLength: body.length,
              title: title
            };
          } catch(e) {
            return {error: e.toString()};
          }
        })();
        ''',
      );
      debugPrint("pageContentCheck ${pageContentCheck.runtimeType}");
      debugPrint("pageContentCheck content $pageContentCheck");

      if (pageContentCheck != null && pageContentCheck.toString() != 'null') {
        Map<String, dynamic> contentData;

        // Check if pageContentCheck is already a Map or if it's a String that needs decoding
        if (pageContentCheck is Map) {
          contentData = Map<String, dynamic>.from(pageContentCheck);
        } else if (pageContentCheck is String) {
          contentData = json.decode(pageContentCheck);
        } else {
          throw Exception('Unexpected data type: ${pageContentCheck.runtimeType}');
        }

        final isCloudFlareChallenge = contentData['isCloudFlareChallenge'] == true;
        final hasPageTrackData = contentData['hasPageTrackData'] == true;
        final hasSahibindenContent = contentData['hasSahibindenContent'] == true;

        if (isCloudFlareChallenge) {
          // CloudFlare challenge aktif - buton pasif
          emit(state.copyWith(
            status: ParselSearchingStatus.loaded,
            statusMessage: 'CloudFlare doğrulaması bekleniyor... Lütfen bekleyin.',
            currentStep: 1,
            isCloudFlareChallenge: true,
          ));

          // 3 saniye sonra tekrar kontrol et
          Timer(const Duration(seconds: 3), () async {
            if (!isClosed) {
              add(WebViewLoadStopEvent(currentUrl.toString()));
            }
          });
        } else if (hasPageTrackData && hasSahibindenContent) {
          // Gerçek sayfa içeriği var - otomatik olarak veri çıkar
          emit(state.copyWith(
            status: ParselSearchingStatus.loaded,
            statusMessage: 'Sayfa yüklendi! Parsel bilgileri otomatik alınıyor...',
            currentStep: 1,
            isCloudFlareChallenge: false,
          ));

          // Otomatik olarak veri çıkarma işlemini başlat
          add(const ExtractDataEvent());
        } else {
          // Henüz tam yüklenmemiş - buton pasif
          emit(state.copyWith(
            status: ParselSearchingStatus.loaded,
            statusMessage: 'Sayfa içeriği yükleniyor... Lütfen bekleyin.',
            currentStep: 1,
            isCloudFlareChallenge: true,
          ));

          // 2 saniye sonra tekrar kontrol et
          Timer(const Duration(seconds: 2), () async {
            if (!isClosed) {
              add(WebViewLoadStopEvent(currentUrl.toString()));
            }
          });
        }
      } else {
        // JavaScript hatası - varsayılan olarak buton pasif
        emit(state.copyWith(
          status: ParselSearchingStatus.loaded,
          statusMessage: 'Sayfa kontrol edilemiyor... Lütfen bekleyin.',
          currentStep: 1,
          isCloudFlareChallenge: true,
        ));
      }
    } catch (e) {
      debugPrint(e.toString());
      // Hata durumunda buton pasif
      emit(state.copyWith(
        status: ParselSearchingStatus.loaded,
        statusMessage: 'Sayfa yükleme kontrolü başarısız. Lütfen bekleyin.',
        currentStep: 1,
        isCloudFlareChallenge: true,
      ));
    }
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
      isCloudFlareChallenge: false,
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

  /// String similarity hesaplar (Levenshtein distance kullanarak)
  /// 0.0 = hiç benzemez, 1.0 = tamamen aynı
  double _calculateStringSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    // Levenshtein distance hesapla
    final distance = _levenshteinDistance(s1, s2);
    final maxLength = s1.length > s2.length ? s1.length : s2.length;

    // Benzerlik oranını döndür (1 - normalizedDistance)
    return 1.0 - (distance / maxLength);
  }

  /// Levenshtein distance algoritması
  int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;

    // DP tablosu oluştur
    final dp = List.generate(len1 + 1, (i) => List.filled(len2 + 1, 0));

    // İlk satır ve sütunu doldur
    for (int i = 0; i <= len1; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      dp[0][j] = j;
    }

    // DP tablosunu doldur
    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        if (s1[i - 1] == s2[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]].reduce((a, b) => a < b ? a : b);
        }
      }
    }

    return dp[len1][len2];
  }
}
