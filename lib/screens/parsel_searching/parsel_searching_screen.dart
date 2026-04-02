import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parsel_sorgu/blocs/parsel_searching/parsel_searching_bloc.dart';
import 'package:parsel_sorgu/blocs/parsel_searching/parsel_searching_event.dart';
import 'package:parsel_sorgu/blocs/parsel_searching/parsel_searching_state.dart';
import 'package:parsel_sorgu/blocs/shared_url/shared_url_bloc.dart';
import 'package:parsel_sorgu/blocs/shared_url/shared_url_event.dart';
import 'package:parsel_sorgu/blocs/shared_url/shared_url_state.dart';
import 'package:parsel_sorgu/blocs/tkgm/tkgm_bloc.dart';
import 'package:parsel_sorgu/screens/parsel_searching/widgets/action_buttons_widget.dart';
import 'package:parsel_sorgu/screens/parsel_searching/widgets/control_buttons_widget.dart';
import 'package:parsel_sorgu/screens/parsel_searching/widgets/first_time_info_bottom_sheet.dart';
import 'package:parsel_sorgu/screens/parsel_searching/widgets/manual_search_widget.dart';
import 'package:parsel_sorgu/screens/parsel_searching/widgets/parsel_data_card_widget.dart';
import 'package:parsel_sorgu/screens/parsel_searching/widgets/parsel_webview_widget.dart';
import 'package:parsel_sorgu/screens/parsel_searching/widgets/search_mode_toggle_widget.dart';
import 'package:parsel_sorgu/screens/parsel_searching/widgets/status_message_widget.dart';
import 'package:parsel_sorgu/screens/parsel_searching/widgets/step_indicator_widget.dart';
import 'package:parsel_sorgu/screens/parsel_searching/widgets/url_input_widget.dart';
import 'package:parsel_sorgu/screens/tkgm/tkgm_webview_screen.dart';
import 'package:parsel_sorgu/screens/widgets/banner_ad_widget.dart';
import 'package:parsel_sorgu/core/ad_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ParselSearchScreen extends StatefulWidget {
  const ParselSearchScreen({super.key});

  @override
  State<ParselSearchScreen> createState() => _ParselSearchScreenState();
}

class _ParselSearchScreenState extends State<ParselSearchScreen> with TickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();

  // Animasyon için
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Son gösterilen hata mesajını takip etmek için
  String? _lastShownError;

  // Son işlenen URL'i takip etmek için (duplicate events'i önlemek için)
  String? _lastProcessedUrl;

  // Otomatik URL yükleme için
  bool _shouldAutoLoad = false;
  String? _pendingUrl;

  // SharedPreferences key
  static const String _firstTimeInfoShownKey = 'first_time_info_shown';

  @override
  void initState() {
    super.initState();

    // Pulse animasyonu için
    _pulseController = AnimationController(duration: const Duration(seconds: 1), vsync: this);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    // URL controller listener
    _urlController.addListener(() {
      context.read<ParselSearchingBloc>().add(UrlChangedEvent(_urlController.text));
    });

    // İlk kullanım kontrolü
    _checkFirstTimeUser();

    // Sayfa mount olduktan sonra SharedUrlBloc'un son state'ini kontrol et
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sharedUrlBloc = context.read<SharedUrlBloc>();
      if (sharedUrlBloc.state is SharedUrlReceived) {
        debugPrint("ParselSearchingScreen: Found existing SharedUrlReceived state, re-emitting");
        sharedUrlBloc.add(const ReemitLastUrl());
      }
    });
  }

  Future<void> _checkFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShownInfo = prefs.getBool(_firstTimeInfoShownKey) ?? false;

    if (!hasShownInfo && mounted) {
      // Ekran tamamen yüklendikten sonra bottom sheet'i göster
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          // Flag'i hemen kaydet - bottom sheet nasıl kapatılırsa kapatılsın tekrar gösterilmesin
          await prefs.setBool(_firstTimeInfoShownKey, true);
          if (mounted) {
            FirstTimeInfoBottomSheet.show(context, () {});
          }
        }
      });
    }
  }

  @override
  void didUpdateWidget(ParselSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // SharedUrlBloc'tan gelen URL'yi dinleyeceğiz, burada manuel işlem yapmıyoruz
  }

  void _clearUrlController() {
    _urlController.clear();
    context.read<ParselSearchingBloc>().add(const ClearUrlEvent());
    _pulseController.stop();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 16)),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  bool _isParselDataComplete(Map<String, dynamic>? parselData) {
    if (parselData == null) return false;

    final requiredFields = ['il', 'ilce', 'mahalle', 'adaNo', 'parselNo'];
    for (String field in requiredFields) {
      final value = parselData[field]?.toString().trim();
      if (value == null || value.isEmpty || value.toLowerCase().contains("belirtilmemiş")) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Parsel Sorgulama', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<SharedUrlBloc, SharedUrlState>(
            listener: (context, state) {
              if (state is SharedUrlReceived) {
                debugPrint("SharedUrlBloc: URL received = ${state.url}");
                // Önce mevcut state'i temizle (önceki parsel data'sını sil)
                context.read<ParselSearchingBloc>().add(const ClearUrlEvent());
                // URL'yi ParselSearchingBloc'a gönder ve text controller'a set et
                context.read<ParselSearchingBloc>().add(SetInitialUrlEvent(state.url));
                _urlController.text = state.url;
                _shouldAutoLoad = true;
                _pendingUrl = state.url; // URL'i güvenli bir şekilde sakla

                // iOS'ta WebView oluşturulmadıysa, biraz bekleyip manuel trigger yapalım
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted && _shouldAutoLoad && _pendingUrl != null) {
                    debugPrint("iOS fallback: Manuel LoadUrlEvent tetikleniyor");
                    context.read<ParselSearchingBloc>().add(LoadUrlEvent(_pendingUrl!));
                    _shouldAutoLoad = false;
                    _pendingUrl = null;
                  }
                });
              }
            },
          ),
          BlocListener<ParselSearchingBloc, ParselSearchingState>(
            listener: (context, state) {
              // Pulse animasyonu kontrolü - CloudFlare challenge aktifken animasyonu başlatma
              if (state.currentStep == 1 && state.status == ParselSearchingStatus.loaded && !state.isCloudFlareChallenge) {
                _pulseController.repeat(reverse: true);
              } else {
                _pulseController.stop();
              }

              // Hata mesajları - sadece yeni hata mesajlarını göster
              if (state.errorMessage != null && state.errorMessage != _lastShownError) {
                _lastShownError = state.errorMessage;
                _showMessage(state.errorMessage!, isError: true);
              } else if (state.errorMessage == null) {
                _lastShownError = null;
              }

              // TKGM'ye yönlendirme - sadece tüm veriler tamamsa
              if (state.parselData != null && state.parselData!.containsKey('tkgmUrl') && state.status == ParselSearchingStatus.extracted && _isParselDataComplete(state.parselData)) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BlocProvider(
                          create: (context) => TkgmBloc(),
                          child: TKGMWebViewScreen(
                            url: state.parselData!['tkgmUrl'],
                            parselData: state.parselData,
                          ),
                        ),
                      ),
                    );
                  }
                });
              }
            },
          ),
        ],
        child: BlocBuilder<ParselSearchingBloc, ParselSearchingState>(
          builder: (context, state) {
            return GestureDetector(
              onTap: () => FocusNode().unfocus(),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Üst kısım - Input ve butonlar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.grey.shade200, offset: const Offset(0, 2), blurRadius: 4)],
                      ),
                      child: Column(
                        children: [
                          // Adım göstergesi
                          StepIndicatorWidget(currentStep: state.currentStep),

                          // Arama modu toggle
                          const SearchModeToggleWidget(),

                          // Input alanı - sadece WebView modunda göster
                          if (state.searchMode == SearchMode.webView)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  UrlInputWidget(
                                    controller: _urlController,
                                    onClear: _clearUrlController,
                                    onChanged: (value) {
                                      // BLoC handles URL changes via listener
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Butonlar
                                  ActionButtonsWidget(
                                    isLoading: state.isLoading,
                                    isExtractingData: state.isExtractingData,
                                    isValidUrl: state.isValidUrl,
                                    currentStep: state.currentStep,
                                    onLoadUrl: () {
                                      context.read<ParselSearchingBloc>().add(LoadUrlEvent(state.url));
                                    },
                                    onExtractData: () {
                                      context.read<ParselSearchingBloc>().add(const ExtractDataEvent());
                                    },
                                    pulseAnimation: _pulseAnimation,
                                  ),
                                ],
                              ),
                            ),

                          // Manuel arama formu - sadece Manuel modunda göster
                          if (state.searchMode == SearchMode.manual) const ManualSearchWidget(),

                          // Durum mesajı ve Parsel kartı - her iki modda da göster
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              children: [
                                // Durum mesajı
                                StatusMessageWidget(statusMessage: state.statusMessage),

                                // Parsel bilgileri kartı
                                if (state.parselData != null) ParselDataCardWidget(parselData: state.parselData!),
                              ],
                            ),
                          ),

                          // WebView kontrol butonları - sadece WebView modunda göster
                          if (state.searchMode == SearchMode.webView)
                            ControlButtonsWidget(
                              showWebView: state.showWebView,
                              onToggleWebView: () {
                                context.read<ParselSearchingBloc>().add(const ToggleWebViewVisibilityEvent());
                              },
                            ),
                        ],
                      ),
                    ),

                    // WebView alanı - sadece WebView modunda göster
                    if (state.searchMode == SearchMode.webView)
                      ParselWebViewWidget(
                        showWebView: state.showWebView,
                        isLoading: state.isLoading,
                        hasLoadedUrl: state.currentStep >= 1,
                        onWebViewCreated: (controller) {
                          context.read<ParselSearchingBloc>().setWebViewController(controller);
                          debugPrint('WebView oluşturuldu');
                          debugPrint('_shouldAutoLoad: $_shouldAutoLoad');
                          debugPrint('state.url: ${state.url}');
                          debugPrint('state.url.isNotEmpty: ${state.url.isNotEmpty}');
                          debugPrint('_urlController.text: ${_urlController.text}');
                          debugPrint('_urlController.text.isNotEmpty: ${_urlController.text.isNotEmpty}');

                          // WebView hazır olduğunda otomatik yükleme yap
                          if (_shouldAutoLoad && _pendingUrl != null && _pendingUrl!.isNotEmpty) {
                            debugPrint('Otomatik yükleme başlatılıyor: $_pendingUrl');
                            _shouldAutoLoad = false;
                            final urlToLoad = _pendingUrl!;
                            _pendingUrl = null;
                            Future.delayed(const Duration(milliseconds: 500), () {
                              if (mounted) {
                                debugPrint('LoadUrlEvent tetikleniyor: $urlToLoad');
                                context.read<ParselSearchingBloc>().add(LoadUrlEvent(urlToLoad));
                              }
                            });
                          } else {
                            debugPrint(
                                'Otomatik yükleme şartları sağlanmadı - _shouldAutoLoad: $_shouldAutoLoad, _pendingUrl: $_pendingUrl, _urlController.text: ${_urlController.text}');
                          }
                        },
                        onLoadStart: (controller, url) {
                          final urlString = url.toString();
                          if (urlString.startsWith('http') && urlString != _lastProcessedUrl) {
                            debugPrint('Yükleme başladı: $url');
                            context.read<ParselSearchingBloc>().add(WebViewLoadStartEvent(urlString));
                          }
                        },
                        onProgressChanged: (controller, progress) {
                          // Sadece önemli progress güncellemelerini logla (0, 50, 100)
                          if (progress == 0 || progress == 50 || progress == 100) {
                            debugPrint('Yükleme ilerlemesi: $progress%');
                          }
                        },
                        onLoadStop: (controller, url) {
                          final urlString = url.toString();
                          if (urlString.startsWith('http')) {
                            debugPrint('Yükleme tamamlandı: $url');
                            _lastProcessedUrl = urlString;
                            context.read<ParselSearchingBloc>().add(WebViewLoadStopEvent(urlString));
                          }
                        },
                        onReceivedError: (controller, request, error) {
                          final requestUrl = request.url.toString();
                          // Sadece HTTP/HTTPS URL'lerde ve önemli hatalarda log yap
                          if ((requestUrl.startsWith('http://') || requestUrl.startsWith('https://')) && !requestUrl.contains('favicon.ico') && !requestUrl.contains('sahibinden://')) {
                            debugPrint('WebView hatası: ${error.description} - URL: ${request.url}');
                            context.read<ParselSearchingBloc>().add(WebViewLoadErrorEvent(error.description));
                          }
                        },
                        onReceivedHttpError: (controller, request, errorResponse) {
                          final requestUrl = request.url.toString();
                          final statusCode = errorResponse.statusCode;

                          // CloudFlare 403 hatalarını ignore et - bunlar normal CloudFlare challenge'ları
                          if (statusCode == 403 && (requestUrl.contains('secure.sahibinden.com') || requestUrl.contains('checkLoading'))) {
                            debugPrint('CloudFlare challenge algılandı: $statusCode - URL: ${request.url}');
                            return; // Error event göndermiyoruz
                          }

                          // Diğer kritik hataları sadece ana domain için logla
                          if (statusCode != null && statusCode >= 500 && requestUrl.contains('www.sahibinden.com') && !requestUrl.contains('favicon.ico')) {
                            debugPrint('Kritik HTTP hatası: $statusCode - URL: ${request.url}');
                            context.read<ParselSearchingBloc>().add(WebViewLoadErrorEvent('Sunucu hatası: $statusCode'));
                          }
                        },
                      ),

                    // Sorumluluk reddi bölümü
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.gavel_rounded,
                                color: Colors.red.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Sorumluluk Reddi',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Bu uygulama TKGM veya herhangi bir devlet kurumunun resmi uygulaması değildir.',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red.shade800,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sadece kullanıcıları resmi TKGM web sitesine yönlendiren bir araçtır.',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  height: 1.4,
                                  color: Colors.red.shade700,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.link_rounded,
                                color: Colors.red.shade700,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Resmi kaynak: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    // TKGM sitesini açmak için
                                    if (mounted) {
                                      Navigator.pushNamed(
                                        context,
                                        '/tkgm',
                                        arguments: 'https://parselsorgu.tkgm.gov.tr',
                                      );
                                    }
                                  },
                                  child: Text(
                                    'https://parselsorgu.tkgm.gov.tr',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      decoration: TextDecoration.underline,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
                  ),

                  // Sticky bottom banner reklam
                  BannerAdWidget(adUnitId: AdHelper.parselSearchBannerAdUnitId),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
