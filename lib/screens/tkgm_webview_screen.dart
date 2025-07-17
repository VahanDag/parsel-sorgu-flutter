import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class TKGMWebViewScreen extends StatefulWidget {
  final String url;
  const TKGMWebViewScreen({super.key, required this.url});

  @override
  State<TKGMWebViewScreen> createState() => _TKGMWebViewScreenState();
}

class _TKGMWebViewScreenState extends State<TKGMWebViewScreen> {
  late InAppWebViewController _webViewController;
  double _progress = 0;

  // Konum ve parsel bilgileri
  Position? _userPosition;
  Map<String, dynamic>? _parselData;
  Map<String, dynamic>? _distanceData;
  List<double>? _edgeLengths;

  // UI kontrol
  bool _isLoadingLocation = false;
  bool _isLoadingParselData = false;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _checkLocationPermissionAndGetLocation();
  }

  // Konum izni kontrolü ve konumu alma
  Future<void> _checkLocationPermissionAndGetLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Konum servisleri kapalı');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Konum izni reddedildi');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Konum izni kalıcı olarak reddedildi');
      }

      _userPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _isLoadingLocation = false;
      });

      // Parsel verilerini al
      _fetchParselData();
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });
      _showMessage('Konum alınamadı: ${e.toString()}', isError: true);
    }
  }

  // Parsel verilerini API'den çek
  Future<void> _fetchParselData() async {
    setState(() {
      _isLoadingParselData = true;
    });

    try {
      // URL'den parsel bilgilerini çıkar
      final uri = Uri.parse(widget.url);
      final fragment = uri.fragment;
      final parts = fragment.split('/');

      if (parts.length >= 5) {
        final mahalleId = parts[2];
        final adaNo = parts[3];
        final parselNo = parts[4];

        // TKGM API'sini çağır
        final response = await http.get(
          Uri.parse('https://cbsapi.tkgm.gov.tr/megsiswebapi.v3/api/parsel/$mahalleId/$adaNo/$parselNo'),
          headers: {'Accept': 'application/json', 'Origin': 'https://parselsorgu.tkgm.gov.tr', 'Referer': 'https://parselsorgu.tkgm.gov.tr/'},
        );

        if (response.statusCode == 200) {
          _parselData = json.decode(response.body);

          // Mesafe hesapla
          if (_userPosition != null && _parselData != null) {
            _calculateDistances();
          }

          // Kenar uzunluklarını hesapla
          _calculateEdgeLengths();
        }
      }
    } catch (e) {
      _showMessage('Parsel verileri alınamadı: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isLoadingParselData = false;
      });
    }
  }

  // Haversine mesafe hesaplama
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Dünya yarıçapı (km)

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);

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
    const turkeyBounds = {'minLat': 35.8, 'maxLat': 42.1, 'minLon': 25.7, 'maxLon': 44.8};

    final point1InTurkey = (lat1 >= turkeyBounds['minLat']! && lat1 <= turkeyBounds['maxLat']! && lon1 >= turkeyBounds['minLon']! && lon1 <= turkeyBounds['maxLon']!);
    final point2InTurkey = (lat2 >= turkeyBounds['minLat']! && lat2 <= turkeyBounds['maxLat']! && lon2 >= turkeyBounds['minLon']! && lon2 <= turkeyBounds['maxLon']!);

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

  // Mesafeleri hesapla
  void _calculateDistances() {
    if (_parselData == null || _userPosition == null) return;

    // Parselin merkez noktasını bul
    final coordinates = _parselData!['geometry']['coordinates'][0] as List;
    double avgLat = 0;
    double avgLon = 0;

    for (var coord in coordinates) {
      avgLon += coord[0];
      avgLat += coord[1];
    }

    avgLat /= coordinates.length;
    avgLon /= coordinates.length;

    // Mesafeleri hesapla
    final straightDistance = _haversineDistance(_userPosition!.latitude, _userPosition!.longitude, avgLat, avgLon);

    final roadDistance = _estimateRoadDistance(straightDistance, _userPosition!.latitude, _userPosition!.longitude, avgLat, avgLon);

    setState(() {
      _distanceData = {
        'straight': straightDistance,
        'road': roadDistance,
        'difference': roadDistance - straightDistance,
        'percentage': ((roadDistance - straightDistance) / straightDistance) * 100,
      };
    });
  }

  // Kenar uzunluklarını hesapla
  void _calculateEdgeLengths() {
    if (_parselData == null) return;

    final coordinates = _parselData!['geometry']['coordinates'][0] as List;
    final lengths = <double>[];

    for (int i = 0; i < coordinates.length - 1; i++) {
      final coord1 = coordinates[i];
      final coord2 = coordinates[i + 1];

      final distance = _calculateEdgeDistance(
        coord1[1],
        coord1[0], // lat, lon
        coord2[1],
        coord2[0], // lat, lon
      );

      lengths.add(distance);
    }

    setState(() {
      _edgeLengths = lengths;
    });
  }

  // İki koordinat arası mesafe (metre)
  double _calculateEdgeDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000; // Dünya yarıçapı metre cinsinden
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final deltaPhi = (lat2 - lat1) * math.pi / 180;
    final deltaLambda = (lon2 - lon1) * math.pi / 180;

    final a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) + math.cos(phi1) * math.cos(phi2) * math.sin(deltaLambda / 2) * math.sin(deltaLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return R * c; // metre cinsinden mesafe
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
              _webViewController.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_progress < 1.0)
                LinearProgressIndicator(value: _progress, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)),
              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                  initialSettings: InAppWebViewSettings(javaScriptEnabled: true, useShouldOverrideUrlLoading: true, domStorageEnabled: true),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                  },
                  onProgressChanged: (controller, progress) {
                    setState(() {
                      _progress = progress / 100;
                    });
                  },
                ),
              ),
            ],
          ),

          // Bilgi kartları
          if (_distanceData != null || _edgeLengths != null)
            Positioned(
              bottom: 60,
              left: 20,
              right: 20,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showDetails = !_showDetails;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Başlık ve genişlet/daralt ikonu
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                                  const SizedBox(width: 8),
                                  const Text('Parsel Detayları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Icon(_showDetails ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, color: Colors.grey),
                            ],
                          ),

                          // Detaylar
                          if (_showDetails) ...[
                            const SizedBox(height: 16),

                            // Mesafe bilgileri
                            if (_distanceData != null) ...[
                              _buildSectionTitle('📍 Konumunuzdan Uzaklık'),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                                child: Column(
                                  children: [
                                    _buildDistanceRow('✈️ Kuş Uçuşu:', '${_distanceData!['straight'].toStringAsFixed(2)} km'),
                                    const SizedBox(height: 4),
                                    _buildDistanceRow('🚗 Tahmini Yol:', '${_distanceData!['road'].toStringAsFixed(2)} km', isHighlighted: true),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Kenar uzunlukları
                            if (_edgeLengths != null) ...[
                              _buildSectionTitle('📐 Parsel Ölçüleri'),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                                child: Column(
                                  children: [
                                    // En-boy bilgisi
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildMeasurementCard('En Uzun', '${_edgeLengths!.reduce(math.max).toStringAsFixed(2)} m', Colors.green.shade700),
                                        _buildMeasurementCard('En Kısa', '${_edgeLengths!.reduce(math.min).toStringAsFixed(2)} m', Colors.orange.shade700),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Tüm kenarlar
                                    const Text('Kenar Uzunlukları:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      children: _edgeLengths!.asMap().entries.map((entry) {
                                        return Chip(
                                          label: Text('K${entry.key + 1}: ${entry.value.toStringAsFixed(1)}m', style: const TextStyle(fontSize: 12)),
                                          backgroundColor: Colors.green.shade100,
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Alan bilgisi
                            if (_parselData != null && _parselData!['properties']['alan'] != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.square_foot, size: 20),
                                    const SizedBox(width: 8),
                                    Text('Toplam Alan: ${_parselData!['properties']['alan']} m²', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 8),
                            Text(
                              '⚠️ Mesafe tahmini olup, gerçek değerler farklı olabilir',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Yükleniyor göstergesi
          if (_isLoadingLocation || _isLoadingParselData)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      const SizedBox(width: 8),
                      Text(_isLoadingLocation ? 'Konum alınıyor...' : 'Parsel bilgileri yükleniyor...', style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),

      // Konum yenileme butonu
      floatingActionButton: _userPosition == null && !_isLoadingLocation
          ? FloatingActionButton.extended(
              onPressed: _checkLocationPermissionAndGetLocation,
              icon: const Icon(Icons.my_location),
              label: const Text('Konumu Al'),
              backgroundColor: Theme.of(context).primaryColor,
            )
          : null,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
  }

  Widget _buildDistanceRow(String label, String value, {bool isHighlighted = false, bool isSubtle = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: isSubtle ? Colors.grey.shade600 : null)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            color: isHighlighted ? Colors.blue.shade700 : (isSubtle ? Colors.grey.shade600 : null),
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurementCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
