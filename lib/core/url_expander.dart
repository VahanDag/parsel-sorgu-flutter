import 'package:http/http.dart' as http;

class UrlExpander {
  // Kısaltılmış URL'yi genişletir
  static Future<String?> expandUrl(String shortUrl) async {
    try {
      print("UrlExpander: Expanding URL: $shortUrl");
      
      // HTTP Client oluştur ve yönlendirmeleri takip etmeyecek şekilde ayarla
      final client = http.Client();
      
      try {
        // İlk HEAD isteği - yönlendirme kontrolü için
        final headResponse = await client
            .head(Uri.parse(shortUrl))
            .timeout(const Duration(seconds: 10));

        print("UrlExpander: HEAD response status: ${headResponse.statusCode}");
        print("UrlExpander: HEAD response headers: ${headResponse.headers}");

        // 3xx status kodları yönlendirme anlamına gelir
        if (headResponse.statusCode >= 300 && headResponse.statusCode < 400) {
          final location = headResponse.headers['location'];
          if (location != null) {
            print("UrlExpander: Found redirect location: $location");
            // Relative URL ise absolute URL'e çevir
            final Uri baseUri = Uri.parse(shortUrl);
            final Uri redirectUri = Uri.parse(location);
            final String finalUrl = redirectUri.isAbsolute ? location : baseUri.resolve(location).toString();
            print("UrlExpander: Final expanded URL: $finalUrl");
            return finalUrl;
          }
        }

        // HEAD başarısızsa GET ile dene
        print("UrlExpander: HEAD didn't work, trying GET request");
        final getResponse = await client
            .get(Uri.parse(shortUrl))
            .timeout(const Duration(seconds: 10));

        print("UrlExpander: GET response status: ${getResponse.statusCode}");
        final finalUrl = getResponse.request?.url.toString();
        
        if (finalUrl != null && finalUrl != shortUrl) {
          print("UrlExpander: GET expanded URL: $finalUrl");
          return finalUrl;
        }

        // Hiçbir yönlendirme yoksa orijinal URL'i döndür
        print("UrlExpander: No redirection found, returning original URL");
        return shortUrl;
        
      } finally {
        client.close();
      }
    } catch (e) {
      print("UrlExpander: Error expanding URL: $e");
      // Hata durumunda orijinal URL'i döndür
      return shortUrl;
    }
  }
}
