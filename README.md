# Parsel Sorgulama

Emlak sitelerinden parsel bilgilerini otomatik olarak çıkarıp TKGM (Tapu ve Kadastro Genel Müdürlüğü) sisteminde sorgulayan pratik bir mobil uygulama.

**Şu anda desteklenen platform:** Sahibinden.com
**Gelecek güncellemelerde:** Hepsiemlak, Emlakjet ve diğer popüler emlak siteleri eklenecektir.

## İndirin

<a href="https://apps.apple.com/us/app/parsel-sorgu/id6749833788"><img src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/tr-tr?size=250x83" alt="App Store'dan indirin" style="height: 60px;"></a>
<a href=""><img src="https://play.google.com/intl/en_us/badges/static/images/badges/tr_badge_web_generic.png" alt="Google Play'den edinin" style="height: 85px;"></a>

## Özellikler

### 🔗 URL Paylaşımı ile Hızlı Erişim

Emlak sitesi ilanını herhangi bir tarayıcıdan veya uygulamadan paylaşın, uygulama otomatik olarak açılsın ve parsel bilgilerini çıkarsın. (Şu anda Sahibinden.com desteklenmektedir)

### 🏘️ Otomatik Veri Çıkarma

İlan sayfasından il, ilçe, mahalle, ada ve parsel numarası bilgilerini otomatik olarak tespit eder ve TKGM sisteminde kullanıma hazır hale getirir.

### 📍 Konum Tabanlı Mesafe Hesaplama

Mevcut konumunuzdan seçili parsele olan kuş uçuşu ve tahmini yol mesafesini hesaplar.

### 📐 Detaylı Parsel Ölçümleri

TKGM sisteminden alınan koordinat bilgileri ile parsel kenar uzunluklarını ve alanını görüntüler.

### 🎯 İki Arama Modu

- **WebView Modu:** İlanı görüntüleyerek otomatik veri çıkarma
- **Manuel Mod:** Parsel bilgilerini elle girerek doğrudan sorgulama

### 🌐 Kısaltılmış URL Desteği

Hem tam Sahibinden.com linkleri hem de shbd.io kısaltılmış linklerini destekler.

## Nasıl Kullanılır?

1. **Paylaşım ile Kullanım:**

   - Desteklenen bir emlak sitesinde (şu anda Sahibinden.com) ilan açın
   - Paylaş butonuna tıklayın
   - Listeden "Parsel Sorgulama" uygulamasını seçin
   - Uygulama otomatik olarak parsel bilgilerini çıkaracak ve TKGM sorgusunu başlatacaktır

2. **Manuel Kullanım:**

   - Uygulamayı açın
   - URL'yi kopyalayıp giriş alanına yapıştırın
   - "Sayfayı Yükle" butonuna basın
   - Sayfa yüklendikten sonra "Parsel Bilgilerini Çıkar" butonuna tıklayın
   - TKGM sorgusuna yönlendirileceksiniz

3. **Elle Veri Girişi:**
   - "Manuel Arama" moduna geçin
   - İl, ilçe, mahalle, ada ve parsel bilgilerini girin
   - "TKGM'de Sorgula" butonuna basın

## Teknik Altyapı

Bu proje Flutter framework'ü kullanılarak geliştirilmiş olup aşağıdaki teknolojileri içermektedir:

- **Flutter SDK** - Çapraz platform mobil uygulama geliştirme
- **BLoC Pattern** - Durum yönetimi ve iş mantığı ayrımı
- **WebView** - İlan sayfalarının görüntülenmesi ve veri çıkarma
- **Geolocator** - Konum servisleri ve mesafe hesaplamaları
- **Receive Sharing Intent** - Diğer uygulamalardan URL alma
- **HTTP & API Integration** - TKGM servislerine bağlanma

### Kullanılan Kütüphaneler

```yaml
dependencies:
  flutter_bloc: ^8.1.6
  flutter_inappwebview: ^6.1.4
  geolocator: ^13.0.0
  receive_sharing_intent: ^1.8.1
  http: ^1.4.0
  permission_handler: ^11.3.1
  shared_preferences: ^2.3.2
```

## Geliştirici İçin

### Kurulum

```bash
# Bağımlılıkları yükleyin
flutter pub get

# Uygulamayı çalıştırın
flutter run

# Analiz yapın
flutter analyze

# Testleri çalıştırın
flutter test
```

### Derleme

```bash
# Android APK
flutter build apk

# iOS
flutter build ios

# Web
flutter build web
```

## Proje Yapısı

```
lib/
├── blocs/                  # BLoC durum yönetimi
│   ├── parsel_searching/   # Ana arama mantığı
│   ├── shared_url/         # Paylaşılan URL yönetimi
│   └── tkgm/               # TKGM sorgulama mantığı
├── screens/                # Ekranlar
│   ├── parsel_searching/   # Ana arama ekranı
│   ├── tkgm/               # TKGM sonuç ekranı
│   └── splash_screen.dart  # Giriş ekranı
├── services/               # Yardımcı servisler
└── main.dart               # Uygulama giriş noktası
```

## Gelecek Planlar

### 🚀 Yol Haritası

Uygulama modüler bir mimari ile tasarlandığından, farklı emlak sitelerinin eklenmesi için alt yapı hazırdır. Önümüzdeki güncellemelerde:

- **Hepsiemlak.com** entegrasyonu
- **Emlakjet.com** entegrasyonu
- **Zingat.com** desteği
- Diğer popüler emlak platformları

Her yeni platform eklendikçe kullanıcılar uygulama içinden bilgilendirilecek ve otomatik olarak yeni özelliklere erişim sağlayacaktır.

### 💡 Planlanan Özellikler

- Çoklu platform karşılaştırma aracı
- Favori parsel listesi
- Geçmiş sorgular ve kayıtlar
- Parsel değişiklik bildirimleri

## Sorumluluk Reddi

**ÖNEMLİ:** Bu uygulama TKGM (Tapu ve Kadastro Genel Müdürlüğü) veya başka bir resmi kurumun ürünü değildir. Sahibinden.com, Hepsiemlak, Emlakjet ya da diğer emlak platformları ile herhangi bir kurumsal bağlantısı bulunmamaktadır.

Uygulama sadece kullanıcıların kolaylıkla parsel bilgilerini emlak ilanlarından çıkarıp resmi TKGM web sitesine yönlendirmek amacıyla geliştirilmiş bağımsız bir üçüncü taraf araçtır. Tüm resmi sorgular TKGM'nin kendi sistemleri üzerinden gerçekleştirilmektedir.

Parsel bilgileri ve tapu kayıtları için tek yetkili kaynak TKGM resmi web sitesidir: [https://parselsorgu.tkgm.gov.tr](https://parselsorgu.tkgm.gov.tr)

Bu uygulamanın kullanımından doğabilecek herhangi bir hata, veri kaybı veya yanlış bilgilendirmeden geliştirici sorumlu tutulamaz. Kullanıcılar tüm resmi işlemleri mutlaka yetkili kurumlar üzerinden doğrulamalıdır.

## Gizlilik

Uygulama herhangi bir kullanıcı verisi toplamaz veya saklamaz. Tüm sorgular doğrudan TKGM sistemine yönlendirilir. Konum bilgisi sadece mesafe hesaplaması için kullanılır ve hiçbir yerde saklanmaz.

## Katkıda Bulunma

Bu proje açık kaynak olarak geliştirilmektedir. Hata bildirimleri ve öneriler için GitHub üzerinden issue açabilirsiniz.

## Lisans

Bu proje MIT lisansı altında yayınlanmıştır. Detaylar için `LICENSE` dosyasına bakınız.

## Geliştirici

**Vahan Dağ**

---

**Sürüm:** 1.1.0
**Son Güncelleme:** Aralık 2024
