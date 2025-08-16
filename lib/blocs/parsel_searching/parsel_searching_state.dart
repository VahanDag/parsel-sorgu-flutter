import 'package:equatable/equatable.dart';

enum ParselSearchingStatus {
  initial,
  loading,
  loaded,
  extracting,
  extracted,
  error,
}

enum SearchMode {
  webView,
  manual,
}

class ParselSearchingState extends Equatable {
  final String url;
  final ParselSearchingStatus status;
  final String statusMessage;
  final int currentStep;
  final Map<String, dynamic>? parselData;
  final bool showWebView;
  final bool isWebViewReady;
  final String? errorMessage;
  final SearchMode searchMode;
  final bool isCloudFlareChallenge;

  const ParselSearchingState({
    this.url = '',
    this.status = ParselSearchingStatus.initial,
    this.statusMessage = '',
    this.currentStep = 0,
    this.parselData,
    this.showWebView = true,
    this.isWebViewReady = false,
    this.errorMessage,
    this.searchMode = SearchMode.webView,
    this.isCloudFlareChallenge = false,
  });

  bool get isValidUrl => url.isNotEmpty && (url.contains('sahibinden.com') || url.contains('shbd.io'));
  bool get isLoading => status == ParselSearchingStatus.loading;
  bool get isExtractingData => status == ParselSearchingStatus.extracting;
  bool get canLoadUrl => isValidUrl && !isLoading && !isExtractingData;
  bool get canExtractData => currentStep >= 1 && !isLoading && !isExtractingData && !isCloudFlareChallenge;

  ParselSearchingState copyWith({
    String? url,
    ParselSearchingStatus? status,
    String? statusMessage,
    int? currentStep,
    Map<String, dynamic>? parselData,
    bool? showWebView,
    bool? isWebViewReady,
    String? errorMessage,
    SearchMode? searchMode,
    bool? isCloudFlareChallenge,
  }) {
    return ParselSearchingState(
      url: url ?? this.url,
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
      currentStep: currentStep ?? this.currentStep,
      parselData: parselData ?? this.parselData,
      showWebView: showWebView ?? this.showWebView,
      isWebViewReady: isWebViewReady ?? this.isWebViewReady,
      errorMessage: errorMessage ?? this.errorMessage,
      searchMode: searchMode ?? this.searchMode,
      isCloudFlareChallenge: isCloudFlareChallenge ?? this.isCloudFlareChallenge,
    );
  }

  @override
  List<Object?> get props => [
        url,
        status,
        statusMessage,
        currentStep,
        parselData,
        showWebView,
        isWebViewReady,
        errorMessage,
        searchMode,
        isCloudFlareChallenge,
      ];
}