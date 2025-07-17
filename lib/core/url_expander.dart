import 'package:http/http.dart' as http;

class UrlExpander {
  // Kısaltılmış URL'yi genişletir
  static Future<String?> expandUrl(String shortUrl) async {
    try {
      final response = await http
          .head(
            Uri.parse(shortUrl),
            // Yönlendirmeleri takip etme
          )
          .timeout(const Duration(seconds: 5));

      // Location header'ını kontrol et
      final location = response.headers['location'];
      if (location != null) {
        return location;
      }

      // Alternatif: GET isteği ile dene
      final getResponse = await http.get(Uri.parse(shortUrl)).timeout(const Duration(seconds: 5));

      // Son URL'yi döndür
      return getResponse.request?.url.toString() ?? shortUrl;
    } catch (e) {
      print("URL genişletme hatası: $e");
      return null;
    }
  }
}
