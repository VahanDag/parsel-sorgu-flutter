import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:parsel_sorgu/blocs/shared_url/shared_url_bloc.dart';
import 'package:parsel_sorgu/blocs/shared_url/shared_url_state.dart';
import 'package:parsel_sorgu/blocs/tkgm/tkgm_bloc.dart';
import 'package:parsel_sorgu/blocs/tkgm/tkgm_event.dart';
import 'package:parsel_sorgu/blocs/tkgm/tkgm_state.dart';
import 'package:parsel_sorgu/screens/tkgm/widgets/location_loading_indicator_widget.dart';
import 'package:parsel_sorgu/screens/tkgm/widgets/parsel_details_card_widget.dart';

class TKGMWebViewScreen extends StatefulWidget {
  final String url;
  const TKGMWebViewScreen({super.key, required this.url});

  @override
  State<TKGMWebViewScreen> createState() => _TKGMWebViewScreenState();
}

class _TKGMWebViewScreenState extends State<TKGMWebViewScreen> with WidgetsBindingObserver {
  bool _isProcessingLifecycleChange = false;
  String? _lastShownErrorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<TkgmBloc>().add(InitializeTkgmEvent(widget.url));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && !_isProcessingLifecycleChange) {
      _isProcessingLifecycleChange = true;

      // Uygulama ön plana geldiğinde konum durumunu kontrol et
      final tkgmState = context.read<TkgmBloc>().state;
      // Sadece kullanıcı konum butonuna bastıysa ve hata durumundaysa kontrol et
      if (tkgmState.hasLocationButtonPressed &&
          (tkgmState.status == TkgmStatus.locationServiceDisabled || tkgmState.status == TkgmStatus.permissionDenied || tkgmState.status == TkgmStatus.permissionPermanentlyDenied)) {
        // Kısa bir delay ile konum durumunu yeniden kontrol et (settings'den dönüş için)
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            context.read<TkgmBloc>().add(const CheckLocationStatusEvent());
            _isProcessingLifecycleChange = false;
          }
        });
      } else {
        _isProcessingLifecycleChange = false;
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TKGM Parsel Sorgu'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<TkgmBloc>().add(const RefreshPageEvent());
            },
          ),
        ],
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<SharedUrlBloc, SharedUrlState>(
            listener: (context, state) {
              if (state is SharedUrlReceived) {
                // Yeni URL paylaşıldığında parsel search sayfasına geri dön
                Navigator.pop(context);
              }
            },
          ),
          BlocListener<TkgmBloc, TkgmState>(
            listener: (context, state) {
              if (state.errorMessage != null && state.errorMessage != _lastShownErrorMessage) {
                _lastShownErrorMessage = state.errorMessage;
                _showMessage(state.errorMessage!, isError: true);
              } else if (state.errorMessage == null) {
                _lastShownErrorMessage = null;
              }
            },
          ),
        ],
        child: BlocBuilder<TkgmBloc, TkgmState>(
          builder: (context, state) {
          return Stack(
            children: [
              Column(
                children: [
                  if (state.progress < 1.0)
                    LinearProgressIndicator(
                      value: state.progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                    ),
                  Expanded(
                    child: InAppWebView(
                      initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        // useShouldOverrideUrlLoading: true,
                        // domStorageEnabled: true,
                      ),
                      onWebViewCreated: (controller) {
                        context.read<TkgmBloc>().setWebViewController(controller);
                      },
                      onProgressChanged: (controller, progress) {
                        context.read<TkgmBloc>().add(WebViewProgressChangedEvent(progress / 100));
                      },
                    ),
                  ),
                ],
              ),

              // Bilgi kartları
              if (state.hasDistanceData || state.hasEdgeData)
                ParselDetailsCardWidget(
                  showDetails: state.showDetails,
                  onToggleDetails: () {
                    context.read<TkgmBloc>().add(const ToggleDetailsVisibilityEvent());
                  },
                  distanceData: state.distanceData,
                  edgeLengths: state.edgeLengths,
                  parselData: state.parselData,
                ),

              // Yükleniyor göstergesi
              LocationLoadingIndicatorWidget(
                isLoadingLocation: state.isLoadingLocation,
                isLoadingParselData: state.isLoadingParselData,
              ),
            ],
          );
          },
        ),
      ),

      // Konum yenileme butonu
      floatingActionButton: BlocBuilder<TkgmBloc, TkgmState>(
        builder: (context, state) {
          return state.canShowLocationButton
              ? FloatingActionButton.extended(
                  onPressed: () {
                    context.read<TkgmBloc>().add(const LoadLocationEvent());
                  },
                  icon: const Icon(
                    Icons.my_location,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Konumu Al',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: Theme.of(context).primaryColor,
                )
              : const SizedBox.shrink();
        },
      ),
    );
  }
}
