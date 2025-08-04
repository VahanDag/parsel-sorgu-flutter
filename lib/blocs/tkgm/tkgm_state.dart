import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

enum TkgmStatus {
  initial,
  loadingLocation,
  locationLoaded,
  loadingParselData,
  parselDataLoaded,
  error,
  locationServiceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
}

class TkgmState extends Equatable {
  final String url;
  final TkgmStatus status;
  final double progress;
  final Position? userPosition;
  final Map<String, dynamic>? parselData;
  final Map<String, dynamic>? distanceData;
  final List<double>? edgeLengths;
  final bool showDetails;
  final String? errorMessage;
  final bool hasLocationButtonPressed;

  const TkgmState({
    this.url = '',
    this.status = TkgmStatus.initial,
    this.progress = 0.0,
    this.userPosition,
    this.parselData,
    this.distanceData,
    this.edgeLengths,
    this.showDetails = false,
    this.errorMessage,
    this.hasLocationButtonPressed = false,
  });

  bool get isLoadingLocation => status == TkgmStatus.loadingLocation;
  bool get isLoadingParselData => status == TkgmStatus.loadingParselData;
  bool get hasLocationData => userPosition != null;
  bool get hasParselData => parselData != null;
  bool get hasDistanceData => distanceData != null;
  bool get hasEdgeData => edgeLengths != null;
  bool get canShowLocationButton => !hasLocationData && 
      !isLoadingLocation && 
      status != TkgmStatus.locationServiceDisabled && 
      status != TkgmStatus.permissionDenied && 
      status != TkgmStatus.permissionPermanentlyDenied;

  TkgmState copyWith({
    String? url,
    TkgmStatus? status,
    double? progress,
    Position? userPosition,
    Map<String, dynamic>? parselData,
    Map<String, dynamic>? distanceData,
    List<double>? edgeLengths,
    bool? showDetails,
    String? errorMessage,
    bool? hasLocationButtonPressed,
  }) {
    return TkgmState(
      url: url ?? this.url,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      userPosition: userPosition ?? this.userPosition,
      parselData: parselData ?? this.parselData,
      distanceData: distanceData ?? this.distanceData,
      edgeLengths: edgeLengths ?? this.edgeLengths,
      showDetails: showDetails ?? this.showDetails,
      errorMessage: errorMessage ?? this.errorMessage,
      hasLocationButtonPressed: hasLocationButtonPressed ?? this.hasLocationButtonPressed,
    );
  }

  @override
  List<Object?> get props => [
        url,
        status,
        progress,
        userPosition,
        parselData,
        distanceData,
        edgeLengths,
        showDetails,
        errorMessage,
        hasLocationButtonPressed,
      ];
}