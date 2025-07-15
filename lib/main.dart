import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:share_handler/share_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parsel Sorgulama',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const ParselSorgulamaScreen(),
    );
  }
}

class ParselSorgulamaScreen extends StatefulWidget {
  const ParselSorgulamaScreen({super.key});

  @override
  State<ParselSorgulamaScreen> createState() => _ParselSorgulamaScreenState();
}

class _ParselSorgulamaScreenState extends State<ParselSorgulamaScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  String _statusMessage = '';

  // Parsel bilgileri
  String? _il;
  String? _ilce;
  String? _mahalle;
  String? _adaNo;
  String? _parselNo;
  String? _mahalleId;

  @override
  void initState() {
    super.initState();
    _initShareHandler();
  }

  void _initShareHandler() {
    final handler = ShareHandlerPlatform.instance;
    handler.sharedMediaStream.listen((SharedMedia media) {
      if (media.content != null && media.content!.contains('sahibinden.com')) {
        _urlController.text = media.content!;
        _processSahibindenUrl();
      }
    });
  }

  Future<void> _processSahibindenUrl() async {
    if (_urlController.text.isEmpty) {
      _showError('Lütfen bir URL girin');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Sahibinden.com\'dan veriler alınıyor...';
    });

    try {
      // 1. Sahibinden HTML'ini çek - Gerçek tarayıcı gibi görün
      final response = await http.get(
        Uri.parse(_urlController.text),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
          'Accept-Encoding': 'gzip, deflate, br',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Sec-Ch-Ua': '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
          'Sec-Ch-Ua-Mobile': '?0',
          'Sec-Ch-Ua-Platform': '"Windows"',
          'Sec-Fetch-Dest': 'document',
          'Sec-Fetch-Mode': 'navigate',
          'Sec-Fetch-Site': 'none',
          'Sec-Fetch-User': '?1',
          'Upgrade-Insecure-Requests': '1',
        },
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Headers: ${response.headers}');

      if (response.statusCode != 200) {
        throw Exception('Sayfa yüklenemedi: ${response.statusCode}');
      }

      // 2. HTML'i parse et ve verileri çıkar
      final htmlContent = response.body;
      debugPrint('HTML Length: ${htmlContent.length}');

      // pageTrackData'yı bul
      final pageTrackDataMatch = RegExp(r'var\s+pageTrackData\s*=\s*({[^}]+})', multiLine: true, dotAll: true).firstMatch(htmlContent);

      if (pageTrackDataMatch == null) {
        // Alternatif arama yöntemi
        final startIndex = htmlContent.indexOf('pageTrackData');
        if (startIndex != -1) {
          debugPrint('pageTrackData found at index: $startIndex');
          // Script içeriğini daha geniş al
          final scriptStart = htmlContent.lastIndexOf('<script', startIndex);
          final scriptEnd = htmlContent.indexOf('</script>', startIndex);
          if (scriptStart != -1 && scriptEnd != -1) {
            final scriptContent = htmlContent.substring(scriptStart, scriptEnd);
            debugPrint('Script content length: ${scriptContent.length}');
            _extractDataFromScript(scriptContent);
          } else {
            throw Exception('Script tag bulunamadı');
          }
        } else {
          throw Exception('pageTrackData bulunamadı');
        }
      } else {
        _extractDataFromScript(pageTrackDataMatch.group(0)!);
      }

      // 3. TKGM API'lerinden mahalle ID'sini bul
      setState(() {
        _statusMessage = 'Mahalle bilgileri alınıyor...';
      });

      await _findMahalleId();

      // 4. WebView'a yönlendir
      if (_mahalleId != null && _adaNo != null && _parselNo != null) {
        _openTKGMWebView();
      } else {
        throw Exception('Eksik bilgi');
      }
    } catch (e) {
      _showError('Hata: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _extractDataFromScript(String scriptContent) {
    debugPrint('Extracting data from script...');

    // customVars array'inden verileri çıkar - daha esnek regex
    final ilMatch = RegExp(r'"name"\s*:\s*"loc2"\s*,\s*"value"\s*:\s*"([^"]+)"').firstMatch(scriptContent);
    final ilceMatch = RegExp(r'"name"\s*:\s*"loc3"\s*,\s*"value"\s*:\s*"([^"]+)"').firstMatch(scriptContent);
    final mahalleMatch = RegExp(r'"name"\s*:\s*"loc5"\s*,\s*"value"\s*:\s*"([^"]+)"').firstMatch(scriptContent);
    final adaMatch = RegExp(r'"name"\s*:\s*"Ada No"\s*,\s*"value"\s*:\s*"([^"]+)"').firstMatch(scriptContent);
    final parselMatch = RegExp(r'"name"\s*:\s*"Parsel No"\s*,\s*"value"\s*:\s*"([^"]+)"').firstMatch(scriptContent);

    // Alternatif pattern'ler dene
    if (ilMatch == null || ilceMatch == null) {
      debugPrint('Primary patterns failed, trying alternatives...');

      // dmpData array'inden dene
      final ilAlt = RegExp(r'"name"\s*:\s*"loc2"\s*,\s*"value"\s*:\s*"([^"]+)"').firstMatch(scriptContent);
      final ilceAlt = RegExp(r'"name"\s*:\s*"loc3"\s*,\s*"value"\s*:\s*"([^"]+)"').firstMatch(scriptContent);

      _il = ilMatch?.group(1) ?? ilAlt?.group(1);
      _ilce = ilceMatch?.group(1) ?? ilceAlt?.group(1);
    } else {
      _il = ilMatch.group(1);
      _ilce = ilceMatch.group(1);
    }

    _mahalle = mahalleMatch?.group(1);
    _adaNo = adaMatch?.group(1)?.replaceAll('.', '').replaceAll(',', '');
    _parselNo = parselMatch?.group(1)?.replaceAll('.', '').replaceAll(',', '');

    debugPrint('Extracted - İl: $_il, İlçe: $_ilce, Mahalle: $_mahalle, Ada: $_adaNo, Parsel: $_parselNo');

    // En az il, ilçe, ada ve parsel numarası olmalı
    if (_il == null || _ilce == null || _adaNo == null || _parselNo == null) {
      throw Exception('Gerekli bilgiler çıkarılamadı. İl: $_il, İlçe: $_ilce, Ada: $_adaNo, Parsel: $_parselNo');
    }
  }

  Future<void> _findMahalleId() async {
    try {
      // 1. İl ID'sini bul
      final ilResponse = await http.get(Uri.parse('https://parselsorgu.tkgm.gov.tr/app/modules/administrativeQuery/data/ilListe.json'));

      final ilData = json.decode(ilResponse.body);
      int? ilId;

      for (var feature in ilData['features']) {
        if (feature['properties']['text'].toString().toLowerCase() == _il?.toLowerCase()) {
          ilId = feature['properties']['id'];
          break;
        }
      }

      if (ilId == null) throw Exception('İl bulunamadı');

      // 2. İlçe ID'sini bul
      final ilceResponse = await http.get(
        Uri.parse('https://cbsapi.tkgm.gov.tr/megsiswebapi.v3.1/api/idariYapi/ilceListe/$ilId'),
        headers: {'Accept': 'application/json', 'Origin': 'https://parselsorgu.tkgm.gov.tr', 'Referer': 'https://parselsorgu.tkgm.gov.tr/'},
      );

      final ilceData = json.decode(ilceResponse.body);
      int? ilceId;

      for (var feature in ilceData['features']) {
        if (feature['properties']['text'].toString().toLowerCase() == _ilce?.toLowerCase()) {
          ilceId = feature['properties']['id'];
          break;
        }
      }

      if (ilceId == null) throw Exception('İlçe bulunamadı');

      // 3. Mahalle ID'sini bul
      final mahalleResponse = await http.get(
        Uri.parse('https://cbsapi.tkgm.gov.tr/megsiswebapi.v3.1/api/idariYapi/mahalleListe/$ilceId'),
        headers: {'Accept': 'application/json', 'Origin': 'https://parselsorgu.tkgm.gov.tr', 'Referer': 'https://parselsorgu.tkgm.gov.tr/'},
      );

      final mahalleData = json.decode(mahalleResponse.body);

      // Mahalle adını temizle ve karşılaştır
      final cleanMahalleName = _mahalle?.replaceAll(' Mh.', '').replaceAll(' Mah.', '').toLowerCase();

      for (var feature in mahalleData['features']) {
        final mahalleName = feature['properties']['text'].toString().toLowerCase();
        if (mahalleName == cleanMahalleName || mahalleName.contains(cleanMahalleName!)) {
          _mahalleId = feature['properties']['id'].toString();
          break;
        }
      }

      if (_mahalleId == null) throw Exception('Mahalle bulunamadı');
    } catch (e) {
      throw Exception('Konum bilgileri alınamadı: ${e.toString()}');
    }
  }

  void _openTKGMWebView() {
    final url = 'https://parselsorgu.tkgm.gov.tr/#ara/idari/$_mahalleId/$_adaNo/$_parselNo';

    Navigator.push(context, MaterialPageRoute(builder: (context) => TKGMWebViewScreen(url: url)));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parsel Sorgulama'), backgroundColor: Theme.of(context).colorScheme.inversePrimary),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Sahibinden.com arsa ilanı URL\'sini yapıştırın:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(hintText: 'https://www.sahibinden.com/ilan/...', border: OutlineInputBorder(), prefixIcon: Icon(Icons.link)),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _processSahibindenUrl,
              icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
              label: Text(_isLoading ? 'İşleniyor...' : 'Parseli Sorgula'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
            ),
            if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_statusMessage, style: const TextStyle(fontStyle: FontStyle.italic)),
                      if (_il != null) ...[
                        const SizedBox(height: 8),
                        Text('İl: $_il'),
                        Text('İlçe: $_ilce'),
                        Text('Mahalle: $_mahalle'),
                        Text('Ada No: $_adaNo'),
                        Text('Parsel No: $_parselNo'),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const Spacer(),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(height: 8),
                    Text(
                      'Sahibinden.com\'dan bir arsa ilanını bu uygulamayla paylaşabilir veya URL\'sini yapıştırabilirsiniz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}

class TKGMWebViewScreen extends StatefulWidget {
  final String url;

  const TKGMWebViewScreen({super.key, required this.url});

  @override
  State<TKGMWebViewScreen> createState() => _TKGMWebViewScreenState();
}

class _TKGMWebViewScreenState extends State<TKGMWebViewScreen> {
  late InAppWebViewController _webViewController;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TKGM Parsel Sorgu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _webViewController.reload();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 1.0) LinearProgressIndicator(value: _progress),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              initialOptions: InAppWebViewGroupOptions(crossPlatform: InAppWebViewOptions(javaScriptEnabled: true, useShouldOverrideUrlLoading: true)),
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
    );
  }
}
