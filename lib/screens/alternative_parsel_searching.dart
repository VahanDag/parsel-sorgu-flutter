import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:parsel_sorgu_app/screens/tkgm_webview_screen.dart';
import 'package:parsel_sorgu_app/screens/widgets/how_to_works_sheet.dart';

class AlternativeParselScreen extends StatefulWidget {
  final String? sharedUrl;
  const AlternativeParselScreen({super.key, this.sharedUrl});

  @override
  State<AlternativeParselScreen> createState() => _AlternativeParselScreenState();
}

class _AlternativeParselScreenState extends State<AlternativeParselScreen> with TickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  InAppWebViewController? _webViewController;
  bool _isLoading = false;
  bool _isExtractingData = false;
  String _statusMessage = '';

  // Animasyon için
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Adım takibi
  int _currentStep = 0;

  // Parsel bilgileri
  Map<String, dynamic>? _parselData;

  // WebView görünürlüğü
  bool _showWebView = true;

  @override
  void initState() {
    super.initState();

    // Pulse animasyonu için
    _pulseController = AnimationController(duration: const Duration(seconds: 1), vsync: this);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    // İlk yüklemede URL varsa işle
    _checkAndProcessUrl();
  }

  // Widget güncellendiğinde (sharedUrl değiştiğinde) çağrılır
  @override
  void didUpdateWidget(AlternativeParselScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // URL değiştiyse ve yeni URL varsa işle
    if (oldWidget.sharedUrl != widget.sharedUrl && widget.sharedUrl != null) {
      _checkAndProcessUrl();
    }
  }

  // URL kontrolü ve işleme
  void _checkAndProcessUrl() {
    if (widget.sharedUrl != null && (widget.sharedUrl!.contains('sahibinden.com') || widget.sharedUrl!.contains('shbd.io'))) {
      _urlController.text = widget.sharedUrl!;

      // Biraz gecikme ekleyerek WebView'in hazır olmasını sağla
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _loadUrlInWebView();
        }
      });
    }
  }

  // URL geçerlilik kontrolü için helper fonksiyon
  bool _isValidUrl(String url) {
    if (url.isEmpty) return false;
    return url.contains('sahibinden.com') || url.contains('shbd.io');
  }

  // URL Controller temizleme fonksiyonu
  void _clearUrlController() {
    setState(() {
      _urlController.clear();
      _currentStep = 0; // Parseli Sorgula butonunu deaktif hale getir
      _parselData = null; // Parsel verilerini temizle
      _statusMessage = ''; // Status mesajını temizle
    });

    // Pulse animasyonunu durdur
    _pulseController.stop();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadUrlInWebView() async {
    // URL geçerlilik kontrolü
    if (!_isValidUrl(_urlController.text)) {
      _showMessage('Lütfen geçerli bir Sahibinden.com linki girin', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Sayfa yükleniyor...';
      _currentStep = 0;
      _parselData = null;
    });

    try {
      await _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(_urlController.text)));
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'URL yükleme hatası: $e';
      });
    }
  }

  Future<void> _extractDataFromWebView() async {
    setState(() {
      _isExtractingData = true;
      _statusMessage = 'Parsel bilgileri alınıyor...';
    });

    try {
      final result = await _webViewController?.evaluateJavascript(
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
        setState(() {
          _parselData = data;
          _statusMessage = 'Parsel bilgileri alındı, TKGM\'ye yönlendiriliyor...';
          _currentStep = 2;
        });

        await _findMahalleIdAndRedirect(data);
      } else {
        throw Exception('Sayfa verileri bulunamadı');
      }
    } catch (e) {
      _showMessage('Veri alınamadı: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isExtractingData = false;
      });
    }
  }

  Future<void> _findMahalleIdAndRedirect(Map<String, dynamic> data) async {
    try {
      setState(() {
        _statusMessage = 'TKGM sorgusu hazırlanıyor...';
      });

      // İl ID'sini bul
      final ilResponse = await http.get(Uri.parse('https://parselsorgu.tkgm.gov.tr/app/modules/administrativeQuery/data/ilListe.json'));

      final ilData = json.decode(ilResponse.body);
      int? ilId;

      for (var feature in ilData['features']) {
        if (feature['properties']['text'].toString().toLowerCase() == data['il'].toString().toLowerCase()) {
          ilId = feature['properties']['id'];
          break;
        }
      }

      if (ilId == null) throw Exception('İl bulunamadı');

      // İlçe ID'sini bul
      final ilceResponse = await http.get(
        Uri.parse('https://cbsapi.tkgm.gov.tr/megsiswebapi.v3.1/api/idariYapi/ilceListe/$ilId'),
        headers: {'Accept': 'application/json', 'Origin': 'https://parselsorgu.tkgm.gov.tr', 'Referer': 'https://parselsorgu.tkgm.gov.tr/'},
      );

      final ilceData = json.decode(ilceResponse.body);
      int? ilceId;

      for (var feature in ilceData['features']) {
        if (feature['properties']['text'].toString().toLowerCase() == data['ilce'].toString().toLowerCase()) {
          ilceId = feature['properties']['id'];
          break;
        }
      }

      if (ilceId == null) throw Exception('İlçe bulunamadı');

      // Mahalle ID'sini bul
      final mahalleResponse = await http.get(
        Uri.parse('https://cbsapi.tkgm.gov.tr/megsiswebapi.v3.1/api/idariYapi/mahalleListe/$ilceId'),
        headers: {'Accept': 'application/json', 'Origin': 'https://parselsorgu.tkgm.gov.tr', 'Referer': 'https://parselsorgu.tkgm.gov.tr/'},
      );

      final mahalleData = json.decode(mahalleResponse.body);
      String? mahalleId;

      final cleanMahalleName = data['mahalle'].toString().replaceAll(' Mh.', '').replaceAll(' Mah.', '').toLowerCase();

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

      setState(() {
        _statusMessage = 'TKGM sayfasına yönlendiriliyor...';
      });

      if (!mounted) return;

      // Kısa bir bekleme sonrası yönlendir
      await Future.delayed(const Duration(milliseconds: 500));

      Navigator.push(context, MaterialPageRoute(builder: (context) => TKGMWebViewScreen(url: tkgmUrl)));
    } catch (e) {
      _showMessage('Konum bilgileri alınamadı: ${e.toString()}', isError: true);
    }
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

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStep(1, 'Link Girildi', _currentStep >= 0),
          _buildConnector(_currentStep >= 1),
          _buildStep(2, 'Sayfa Yüklendi', _currentStep >= 1),
          _buildConnector(_currentStep >= 2),
          _buildStep(3, 'Veri Alındı', _currentStep >= 2),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String label, bool isActive) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade300),
            child: Center(
              child: Text(
                number.toString(),
                style: TextStyle(color: isActive ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: isActive ? Colors.black87 : Colors.grey, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConnector(bool isActive) {
    return Container(height: 2, width: 40, color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade300);
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
      body: SingleChildScrollView(
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
                  _buildStepIndicator(),

                  // Input alanı
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _urlController,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Sahibinden.com linkini buraya yapıştırın',
                            prefixIcon: const Icon(Icons.link, size: 28),
                            suffixIcon: _urlController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: _clearUrlController, // Güncellenmiş temizleme fonksiyonu
                                  )
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          onChanged: (value) => setState(() {}),
                        ),
                        const SizedBox(height: 16),

                        // Butonlar
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                // Sadece geçerli URL'ler için aktif
                                onPressed: (_isLoading || !_isValidUrl(_urlController.text)) ? null : _loadUrlInWebView,
                                icon: _isLoading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.download),
                                label: Text(_isLoading ? 'Yükleniyor...' : 'Sayfayı Yükle'),
                                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _currentStep == 1 ? _pulseAnimation.value : 1.0,
                                    child: ElevatedButton.icon(
                                      onPressed: (_isLoading || _isExtractingData || _currentStep < 1) ? null : _extractDataFromWebView,
                                      icon: _isExtractingData
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Icon(Icons.search),
                                      label: Text(_isExtractingData ? 'Alınıyor...' : 'Parseli Sorgula'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),

                        // Durum mesajı
                        if (_statusMessage.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_statusMessage, style: TextStyle(color: Colors.blue.shade700, fontSize: 14)),
                                ),
                              ],
                            ),
                          ),

                        // Parsel bilgileri kartı
                        if (_parselData != null)
                          Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Colors.green.shade50, Colors.green.shade100], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Parsel Bilgileri Alındı',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildInfoRow('İl', _parselData!['il']),
                                _buildInfoRow('İlçe', _parselData!['ilce']),
                                _buildInfoRow('Mahalle', _parselData!['mahalle']),
                                _buildInfoRow('Ada No', _parselData!['adaNo']),
                                _buildInfoRow('Parsel No', _parselData!['parselNo']),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // WebView göster/gizle butonu
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _showWebView = !_showWebView;
                          });
                        },
                        icon: Icon(_showWebView ? Icons.visibility_off : Icons.visibility),
                        label: Text(_showWebView ? 'Sayfayı Gizle' : 'Sayfayı Göster'),
                      ),

                      TextButton.icon(
                        onPressed: () {
                          showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => buildHowItWorksBottomSheet());
                        },
                        icon: Icon(Icons.question_mark_rounded),
                        label: Text("Nasıl Çalışır?"),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // WebView alanı - Visibility widget kullanarak gizle/göster
            if (_isLoading) const LinearProgressIndicator(),

            // WebView'i tamamen kaldırmak yerine Visibility ile kontrol et
            Visibility(
              visible: _showWebView,
              maintainState: true, // State'i koru
              child: Container(
                height: 500,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [BoxShadow(color: Colors.grey.shade200, offset: const Offset(0, 2), blurRadius: 4)],
                ),
                clipBehavior: Clip.antiAlias,
                child: InAppWebView(
                  key: const ValueKey('webview'), // Unique key ekle
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    useShouldOverrideUrlLoading: true,
                    supportZoom: true,
                    builtInZoomControls: true,
                    displayZoomControls: false,
                    useWideViewPort: true,
                    loadWithOverviewMode: true,
                  ),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                  },

                  // Özel URL şemalarını handle et
                  shouldOverrideUrlLoading: (controller, navigationAction) async {
                    final url = navigationAction.request.url.toString();

                    // Eğer HTTP/HTTPS değilse, sisteme bırak
                    if (!url.startsWith('http://') && !url.startsWith('https://')) {
                      return NavigationActionPolicy.CANCEL; // WebView'de yükleme
                    }

                    return NavigationActionPolicy.ALLOW; // Normal HTTP/HTTPS linklerini yükle
                  },

                  onReceivedError: (controller, request, error) {
                    setState(() {
                      _isLoading = false;
                    });

                    // Sadece HTTP/HTTPS isteklerindeki hataları göster
                    final requestUrl = request.url.toString();
                    if (requestUrl.startsWith('http://') || requestUrl.startsWith('https://')) {
                      _showMessage('Sayfa yüklenemedi: ${error.description}', isError: true);
                    }
                  },

                  onLoadStop: (controller, url) {
                    setState(() {
                      _isLoading = false;
                      _statusMessage = 'Sayfa yüklendi! Parseli sorgulamak için butona tıklayın.';
                      _currentStep = 1;
                    });

                    // Pulse animasyonunu başlat
                    _pulseController.repeat(reverse: true);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
