import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'tkgm_event.dart';
import 'tkgm_state.dart';

class TkgmBloc extends Bloc<TkgmEvent, TkgmState> {
  InAppWebViewController? _webViewController;

  TkgmBloc() : super(const TkgmState()) {
    on<InitializeTkgmEvent>(_onInitializeTkgm);
    on<LoadLocationEvent>(_onLoadLocation);
    on<FetchParselDataEvent>(_onFetchParselData);
    on<ToggleDetailsVisibilityEvent>(_onToggleDetailsVisibility);
    on<WebViewProgressChangedEvent>(_onWebViewProgressChanged);
    on<RefreshPageEvent>(_onRefreshPage);
    on<CheckLocationStatusEvent>(_onCheckLocationStatus);
  }

  void setWebViewController(InAppWebViewController controller) {
    _webViewController = controller;
  }

  void _onInitializeTkgm(InitializeTkgmEvent event, Emitter<TkgmState> emit) {
    emit(state.copyWith(url: event.url));
  }

  void _onLoadLocation(LoadLocationEvent event, Emitter<TkgmState> emit) async {
    emit(state.copyWith(
      status: TkgmStatus.loadingLocation,
      hasLocationButtonPressed: true,
    ));

    try {
      // Konum servisinin açık olup olmadığını kontrol et
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        emit(state.copyWith(
          status: TkgmStatus.locationServiceDisabled,
          errorMessage: 'Konum servisleri kapalı. Konum servislerini açmak için ayarlara yönlendirileceksiniz.',
        ));
        await Geolocator.openLocationSettings();
        return;
      }

      // İzin durumunu kontrol et (geolocator ile)
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          emit(state.copyWith(
            status: TkgmStatus.permissionDenied,
            errorMessage: 'Konum izni reddedildi. Konum izni vermek için ayarlara yönlendirileceksiniz.',
          ));
          await Geolocator.openAppSettings();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        emit(state.copyWith(
          status: TkgmStatus.permissionPermanentlyDenied,
          errorMessage: 'Konum izni kalıcı olarak reddedildi. Uygulama ayarlarından izin vermeniz gerekiyor.',
        ));
        await Geolocator.openAppSettings();
        return;
      }

      // Her şey tamam, konumu al
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      emit(state.copyWith(
        userPosition: position,
        status: TkgmStatus.locationLoaded,
      ));

      add(const FetchParselDataEvent());
    } catch (e) {
      emit(state.copyWith(
        status: TkgmStatus.error,
        errorMessage: 'Konum alınamadı: ${e.toString()}',
      ));
    }
  }

  void _onFetchParselData(FetchParselDataEvent event, Emitter<TkgmState> emit) async {
    emit(state.copyWith(status: TkgmStatus.loadingParselData));

    try {
      // URL'den parsel bilgilerini çıkar
      final uri = Uri.parse(state.url);
      final fragment = uri.fragment;
      final parts = fragment.split('/');

      if (parts.length >= 5) {
        final mahalleId = parts[2];
        final adaNo = parts[3];
        final parselNo = parts[4];

        // TKGM API'sini çağır
        final response = await http.get(
          Uri.parse('https://cbsapi.tkgm.gov.tr/megsiswebapi.v3/api/parsel/$mahalleId/$adaNo/$parselNo'),
          headers: {
            'Accept': 'application/json',
            'Origin': 'https://parselsorgu.tkgm.gov.tr',
            'Referer': 'https://parselsorgu.tkgm.gov.tr/',
          },
        );

        if (response.statusCode == 200) {
          final parselData = json.decode(response.body);

          emit(state.copyWith(
            parselData: parselData,
            status: TkgmStatus.parselDataLoaded,
          ));

          // Mesafe hesapla
          if (state.userPosition != null) {
            _calculateDistances(emit);
          }

          // Kenar uzunluklarını hesapla
          _calculateEdgeLengths(emit);
        }
      }
    } catch (e) {
      emit(state.copyWith(
        status: TkgmStatus.error,
        errorMessage: 'Parsel verileri alınamadı: ${e.toString()}',
      ));
    }
  }

  void _calculateDistances(Emitter<TkgmState> emit) {
    if (state.parselData == null || state.userPosition == null) return;

    // Parselin merkez noktasını bul
    final coordinates = state.parselData!['geometry']['coordinates'][0] as List;
    double avgLat = 0;
    double avgLon = 0;

    for (var coord in coordinates) {
      avgLon += coord[0];
      avgLat += coord[1];
    }

    avgLat /= coordinates.length;
    avgLon /= coordinates.length;

    // Mesafeleri hesapla
    final straightDistance = _haversineDistance(
      state.userPosition!.latitude,
      state.userPosition!.longitude,
      avgLat,
      avgLon,
    );

    final roadDistance = _estimateRoadDistance(
      straightDistance,
      state.userPosition!.latitude,
      state.userPosition!.longitude,
      avgLat,
      avgLon,
    );

    emit(state.copyWith(
      distanceData: {
        'straight': straightDistance,
        'road': roadDistance,
        'difference': roadDistance - straightDistance,
        'percentage': ((roadDistance - straightDistance) / straightDistance) * 100,
      },
    ));
  }

  void _calculateEdgeLengths(Emitter<TkgmState> emit) {
    if (state.parselData == null) return;

    final coordinates = state.parselData!['geometry']['coordinates'][0] as List;
    final lengths = <double>[];

    for (int i = 0; i < coordinates.length - 1; i++) {
      final coord1 = coordinates[i];
      final coord2 = coordinates[i + 1];

      final distance = _calculateEdgeDistance(
        coord1[1], coord1[0], // lat, lon
        coord2[1], coord2[0], // lat, lon
      );

      lengths.add(distance);
    }

    emit(state.copyWith(edgeLengths: lengths));
  }

  // Haversine mesafe hesaplama
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Dünya yarıçapı (km)

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return R * c;
  }

  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // Tahmini yol mesafesi hesaplama
  double _estimateRoadDistance(double straightDistance, double lat1, double lon1, double lat2, double lon2) {
    double factor = 1.0;

    // 1. Mesafe bazlı faktör
    if (straightDistance < 10) {
      factor += 0.2; // Şehir içi %20
    } else if (straightDistance < 50) {
      factor += 0.15; // Kısa mesafe %15
    } else if (straightDistance < 200) {
      factor += 0.25; // Orta mesafe %25
    } else {
      factor += 0.35; // Uzun mesafe %35
    }

    // 2. Enlem farkı (dağlık alan tahmini)
    final latDiff = (lat2 - lat1).abs();
    if (latDiff > 2) {
      factor += 0.3; // Büyük enlem farkı = muhtemelen dağlık
    } else if (latDiff > 1) {
      factor += 0.15;
    }

    // 3. Boylam farkı
    final lonDiff = (lon2 - lon1).abs();
    if (lonDiff > 10) {
      factor += 0.4; // Büyük boylam farkı
    } else if (lonDiff > 5) {
      factor += 0.2;
    }

    // 4. Türkiye özel durumları
    const turkeyBounds = {
      'minLat': 35.8,
      'maxLat': 42.1,
      'minLon': 25.7,
      'maxLon': 44.8
    };

    final point1InTurkey = (lat1 >= turkeyBounds['minLat']! &&
        lat1 <= turkeyBounds['maxLat']! &&
        lon1 >= turkeyBounds['minLon']! &&
        lon1 <= turkeyBounds['maxLon']!);
    final point2InTurkey = (lat2 >= turkeyBounds['minLat']! &&
        lat2 <= turkeyBounds['maxLat']! &&
        lon2 >= turkeyBounds['minLon']! &&
        lon2 <= turkeyBounds['maxLon']!);

    if (point1InTurkey && point2InTurkey) {
      // Türkiye içi özel durumlar
      if (straightDistance > 100) {
        factor += 0.1; // Türkiye'nin dağlık yapısı
      }

      // Karadeniz - Akdeniz arası (dağlık)
      if ((lat1 > 41 && lat2 < 37) || (lat1 < 37 && lat2 > 41)) {
        factor += 0.3;
      }

      // Doğu - Batı arası (uzun mesafe)
      if (lonDiff > 10) {
        factor += 0.2;
      }
    }

    // 5. Su kütleleri tahmini
    if (lonDiff > 3 && latDiff < 1) {
      factor += 0.15; // Muhtemelen su kütlesi aşılıyor
    }

    // Maksimum faktör sınırı
    factor = math.min(factor, 3.0);

    return straightDistance * factor;
  }

  // İki koordinat arası mesafe (metre)
  double _calculateEdgeDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000; // Dünya yarıçapı metre cinsinden
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final deltaPhi = (lat2 - lat1) * math.pi / 180;
    final deltaLambda = (lon2 - lon1) * math.pi / 180;

    final a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) * math.cos(phi2) * math.sin(deltaLambda / 2) * math.sin(deltaLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return R * c; // metre cinsinden mesafe
  }

  void _onToggleDetailsVisibility(ToggleDetailsVisibilityEvent event, Emitter<TkgmState> emit) {
    emit(state.copyWith(showDetails: !state.showDetails));
  }

  void _onWebViewProgressChanged(WebViewProgressChangedEvent event, Emitter<TkgmState> emit) {
    emit(state.copyWith(progress: event.progress));
  }

  void _onRefreshPage(RefreshPageEvent event, Emitter<TkgmState> emit) {
    _webViewController?.reload();
  }

  void _onCheckLocationStatus(CheckLocationStatusEvent event, Emitter<TkgmState> emit) async {
    // Sadece konum/izin durumunu kontrol et, ayarlara yönlendirme
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      if (serviceEnabled && (permission == LocationPermission.whileInUse || permission == LocationPermission.always)) {
        // Her şey tamam, konum al
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );

        emit(state.copyWith(
          userPosition: position,
          status: TkgmStatus.locationLoaded,
          errorMessage: null,
        ));

        add(const FetchParselDataEvent());
      } else {
        // Hala problem var, buton gösterilmeye devam etsin
        emit(state.copyWith(
          status: TkgmStatus.initial,
          errorMessage: null,
        ));
      }
    } catch (e) {
      // Hata durumunda da buton gösterilsin
      emit(state.copyWith(
        status: TkgmStatus.initial,
        errorMessage: null,
      ));
    }
  }
}