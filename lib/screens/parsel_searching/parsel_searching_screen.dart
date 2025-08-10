import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:parsel_sorgu/blocs/parsel_searching/parsel_searching_bloc.dart';
import 'package:parsel_sorgu/blocs/parsel_searching/parsel_searching_event.dart';
import 'package:parsel_sorgu/blocs/parsel_searching/parsel_searching_state.dart';
import 'package:parsel_sorgu/blocs/tkgm/tkgm_bloc.dart';
import 'package:parsel_sorgu/screens/parsel_searching/widgets/action_buttons_widget.dart';
import 'package:parsel_sorgu/screens/parsel_searching/widgets/control_buttons_widget.dart';
import 'package:parsel_sorgu/screens/parsel_searching/widgets/manual_search_widget.dart';
import 'package:parsel_sorgu/screens/parsel_searching/widgets/parsel_data_card_widget.dart';
import 'package:parsel_sorgu/screens/parsel_searching/widgets/parsel_webview_widget.dart';
import 'package:parsel_sorgu/screens/parsel_searching/widgets/search_mode_toggle_widget.dart';
import 'package:parsel_sorgu/screens/parsel_searching/widgets/status_message_widget.dart';
import 'package:parsel_sorgu/screens/parsel_searching/widgets/step_indicator_widget.dart';
import 'package:parsel_sorgu/screens/parsel_searching/widgets/url_input_widget.dart';
import 'package:parsel_sorgu/screens/tkgm/tkgm_webview_screen.dart';

class ParselSearchScreen extends StatefulWidget {
  final String? sharedUrl;
  const ParselSearchScreen({super.key, this.sharedUrl});

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

    // İlk URL'yi set et ve otomatik aramayı başlat
    if (widget.sharedUrl != null) {
      context.read<ParselSearchingBloc>().add(SetInitialUrlEvent(widget.sharedUrl));
      _urlController.text = widget.sharedUrl!;
      _shouldAutoLoad = true;
    }
  }

  @override
  void didUpdateWidget(ParselSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.sharedUrl != widget.sharedUrl && widget.sharedUrl != null) {
      context.read<ParselSearchingBloc>().add(SetInitialUrlEvent(widget.sharedUrl));
      _urlController.text = widget.sharedUrl!;
      _shouldAutoLoad = true;
    }
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
      body: BlocConsumer<ParselSearchingBloc, ParselSearchingState>(
        listener: (context, state) {
          // Pulse animasyonu kontrolü
          if (state.currentStep == 1 && state.status == ParselSearchingStatus.loaded) {
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
                      child: TKGMWebViewScreen(url: state.parselData!['tkgmUrl']),
                    ),
                  ),
                );
              }
            });
          }
        },
        builder: (context, state) {
          return GestureDetector(
            onTap: () => FocusNode().unfocus(),
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
                      onWebViewCreated: (controller) {
                        context.read<ParselSearchingBloc>().setWebViewController(controller);
                        print('WebView oluşturuldu');

                        // WebView hazır olduğunda otomatik yükleme yap
                        if (_shouldAutoLoad && widget.sharedUrl != null) {
                          _shouldAutoLoad = false;
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (mounted) {
                              context.read<ParselSearchingBloc>().add(LoadUrlEvent(widget.sharedUrl!));
                            }
                          });
                        }
                      },
                      onLoadStart: (controller, url) {
                        final urlString = url.toString();
                        if (urlString.startsWith('http') && urlString != _lastProcessedUrl) {
                          print('Yükleme başladı: $url');
                          context.read<ParselSearchingBloc>().add(WebViewLoadStartEvent(urlString));
                        }
                      },
                      onProgressChanged: (controller, progress) {
                        // Sadece önemli progress güncellemelerini logla (0, 50, 100)
                        if (progress == 0 || progress == 50 || progress == 100) {
                          print('Yükleme ilerlemesi: $progress%');
                        }
                      },
                      onLoadStop: (controller, url) {
                        final urlString = url.toString();
                        if (urlString.startsWith('http') && urlString.contains('sahibinden.com')) {
                          print('Yükleme tamamlandı: $url');
                          _lastProcessedUrl = urlString;
                          context.read<ParselSearchingBloc>().add(WebViewLoadStopEvent(urlString));
                        }
                      },
                      onReceivedError: (controller, request, error) {
                        final requestUrl = request.url.toString();
                        // Sadece HTTP/HTTPS URL'lerde ve önemli hatalarda log yap
                        if ((requestUrl.startsWith('http://') || requestUrl.startsWith('https://')) && !requestUrl.contains('favicon.ico') && !requestUrl.contains('sahibinden://')) {
                          print('WebView hatası: ${error.description} - URL: ${request.url}');
                          context.read<ParselSearchingBloc>().add(WebViewLoadErrorEvent(error.description));
                        }
                      },
                      onReceivedHttpError: (controller, request, errorResponse) {
                        final requestUrl = request.url.toString();
                        final statusCode = errorResponse.statusCode;
                        // Sadece 4xx ve 5xx hataları ve ana sayfa hatalarını logla
                        if (statusCode != null && statusCode >= 400 && !requestUrl.contains('favicon.ico') && requestUrl.contains('sahibinden.com')) {
                          print('HTTP hatası: $statusCode - URL: ${request.url}');
                          context.read<ParselSearchingBloc>().add(WebViewLoadErrorEvent('HTTP hatası: $statusCode'));
                        }
                      },
                      shouldOverrideUrlLoading: (controller, navigationAction) async {
                        final url = navigationAction.request.url.toString();

                        // App scheme'leri (sahibinden://) iptal et
                        if (!url.startsWith('http://') && !url.startsWith('https://')) {
                          return NavigationActionPolicy.CANCEL;
                        }

                        // Sadece sahibinden.com URL'lerini logla
                        if (url.contains('sahibinden.com')) {
                          print('URL yönlendirme: $url');
                        }

                        return NavigationActionPolicy.ALLOW;
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
