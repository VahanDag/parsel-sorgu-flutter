#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import os
import random
import sys
import time
from datetime import datetime
from typing import Dict, List, Optional, Tuple

import requests


class TurkeyLocationFetcher:
    def __init__(self):
        self.session = requests.Session()
        # Browser gibi görünmek için headers ekle
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'application/json, text/plain, */*',
            'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.8',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
            'Sec-Ch-Ua': '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
            'Sec-Ch-Ua-Mobile': '?0',
            'Sec-Ch-Ua-Platform': '"Windows"',
            'Sec-Fetch-Dest': 'empty',
            'Sec-Fetch-Mode': 'cors',
            'Sec-Fetch-Site': 'same-origin',
        })

        # Checkpoint dosyası
        self.checkpoint_file = 'location_data_checkpoint.json'
        self.failed_requests_file = 'failed_requests.json'

        # Rate limiting ayarları
        self.min_delay = 3  # Minimum bekleme süresi (saniye) - artırıldı
        self.max_delay = 7  # Maximum bekleme süresi (saniye) - artırıldı
        self.retry_count = 3  # Tekrar deneme sayısı
        self.timeout = 60  # Request timeout (saniye)
        self.consecutive_403_count = 0  # Ardışık 403 sayacı
        self.max_consecutive_403 = 5  # Maksimum ardışık 403 hatası

    def random_delay(self):
        """Rastgele bekleme süresi"""
        delay = random.uniform(self.min_delay, self.max_delay)
        time.sleep(delay)

    def save_checkpoint(self, data: Dict):
        """İlerlemeyi kaydet"""
        with open(self.checkpoint_file, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        stats = data.get('stats', {})
        print(f"  💾 Checkpoint: {stats.get('total_provinces_processed', 0)} il, "
              f"{stats.get('total_districts', 0)} ilçe, "
              f"{stats.get('total_neighborhoods', 0)} mahalle kaydedildi")

    def load_checkpoint(self) -> Optional[Dict]:
        """Kaydedilmiş ilerlemeyi yükle"""
        if os.path.exists(self.checkpoint_file):
            with open(self.checkpoint_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        return None

    def save_failed_requests(self, failed: List):
        """Başarısız istekleri kaydet"""
        with open(self.failed_requests_file, 'w', encoding='utf-8') as f:
            json.dump(failed, f, ensure_ascii=False, indent=2)

    def fetch_with_retry(self, url: str, description: str) -> Optional[Dict]:
        """Retry mekanizması ile veri çek"""
        for attempt in range(self.retry_count):
            try:
                if attempt > 0:
                    wait_time = (attempt + 1) * 10
                    print(
                        f"    ⏳ {wait_time} saniye bekleniyor... (Deneme {attempt + 1}/{self.retry_count})")
                    time.sleep(wait_time)

                response = self.session.get(url, timeout=self.timeout)

                if response.status_code == 403:
                    self.consecutive_403_count += 1
                    print(
                        f"    ⚠️  403 Forbidden hatası! API erişimi engellendi. (Ardışık: {self.consecutive_403_count})")

                    if self.consecutive_403_count >= self.max_consecutive_403:
                        print(f"\n    🛑 Çok fazla ardışık 403 hatası!")
                        print(f"    💡 Öneriler:")
                        print(f"       1. VPN lokasyonunu değiştirin")
                        print(f"       2. 10-15 dakika bekleyin")
                        print(f"       3. Script'i yeniden başlatın")
                        print(
                            f"    💾 Veriler kaydedildi, kaldığınız yerden devam edebilirsiniz.\n")
                        return None

                    if attempt == 0:
                        print(
                            f"    💡 İpucu: VPN değiştirip script'i yeniden başlatmayı deneyin.")
                    if attempt < self.retry_count - 1:
                        print(f"    🔄 Yeniden deneniyor...")
                        # Session'ı yenile
                        self.session = requests.Session()
                        self.session.headers.update({
                            'User-Agent': f'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/{120+attempt}.0.0.0 Safari/537.36',
                            'Accept': 'application/json, text/plain, */*',
                            'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.8',
                        })
                        continue
                    return None

                response.raise_for_status()
                # Başarılı istek, 403 sayacını sıfırla
                self.consecutive_403_count = 0
                return response.json()

            except requests.exceptions.Timeout:
                print(f"    ⏱️  Zaman aşımı hatası: {description}")
            except requests.exceptions.ConnectionError:
                print(f"    🔌 Bağlantı hatası: {description}")
            except Exception as e:
                print(f"    ❌ Hata ({description}): {e}")

        return None

    def fetch_provinces(self) -> List[Tuple[str, int]]:
        """İlleri ve ID'lerini çeker"""
        url = "https://parselsorgu.tkgm.gov.tr/app/modules/administrativeQuery/data/ilListe.json"
        print("🔍 İller çekiliyor...")

        data = self.fetch_with_retry(url, "İller")
        if not data:
            return []

        provinces = []
        for feature in data.get('features', []):
            props = feature.get('properties', {})
            province_name = props.get('text', '')
            province_id = props.get('id', 0)
            if province_name and province_id:
                provinces.append((province_name, province_id))
                print(f"  ✓ {province_name} (ID: {province_id})")

        provinces.sort(key=lambda x: x[0])
        self.random_delay()
        return provinces

    def fetch_districts(self, province_id: int, province_name: str) -> List[Tuple[str, int]]:
        """Bir ilin ilçelerini ve ID'lerini çeker"""
        url = f"https://cbsapi.tkgm.gov.tr/megsiswebapi.v3.1/api/idariYapi/ilceListe/{province_id}"

        data = self.fetch_with_retry(url, f"{province_name} ilçeleri")
        if not data:
            return []

        districts = []
        for feature in data.get('features', []):
            props = feature.get('properties', {})
            district_name = props.get('text', '')
            district_id = props.get('id', 0)
            if district_name and district_id:
                districts.append((district_name, district_id))

        districts.sort(key=lambda x: x[0])
        self.random_delay()
        return districts

    def fetch_neighborhoods(self, district_id: int, district_name: str) -> List[str]:
        """Bir ilçenin mahallelerini çeker"""
        url = f"https://cbsapi.tkgm.gov.tr/megsiswebapi.v3.1/api/idariYapi/mahalleListe/{district_id}"

        data = self.fetch_with_retry(url, f"{district_name} mahalleleri")
        if not data:
            return []

        neighborhoods = []
        for feature in data.get('features', []):
            props = feature.get('properties', {})
            neighborhood_name = props.get('text', '')
            if neighborhood_name:
                neighborhoods.append(neighborhood_name)

        neighborhoods.sort()
        self.random_delay()
        return neighborhoods

    def fetch_all_data(self, resume: bool = True):
        """Tüm verileri çeker ve organize eder"""
        print("🚀 Veri çekme işlemi başlıyor...")
        print(
            f"⏱️  Bekleme süreleri: {self.min_delay}-{self.max_delay} saniye")
        print(f"🔄 Tekrar deneme sayısı: {self.retry_count}")
        print(f"⏳ Timeout: {self.timeout} saniye\n")

        # Checkpoint kontrolü
        checkpoint_data = None
        if resume and os.path.exists(self.checkpoint_file):
            checkpoint_data = self.load_checkpoint()
            print(f"✅ Önceki ilerleme bulundu!")
            stats = checkpoint_data.get('stats', {})
            print(f"📊 Durum: {stats.get('total_provinces_processed', 0)} il, "
                  f"{stats.get('total_districts', 0)} ilçe, "
                  f"{stats.get('total_neighborhoods', 0)} mahalle")
            if 'last_processed' in stats:
                print(f"📍 Son işlenen il: {stats['last_processed']}")
            print(
                f"⏰ Son güncelleme: {stats.get('last_update', 'Bilinmiyor')}")
            print("🔄 Kaldığı yerden devam ediliyor...\n")

        # İlleri çek veya checkpoint'ten yükle
        if checkpoint_data and 'provinces' in checkpoint_data:
            provinces = checkpoint_data['provinces']
            province_data = checkpoint_data.get('province_data', {})
            district_data = checkpoint_data.get('district_data', {})
            processed_provinces = checkpoint_data.get(
                'processed_provinces', [])
            failed_requests = checkpoint_data.get('failed_requests', [])
            print(f"📊 {len(processed_provinces)}/{len(provinces)} il işlenmiş\n")
        else:
            provinces = self.fetch_provinces()
            if not provinces:
                print("❌ İller çekilemedi!")
                return None, None
            province_data = {}
            district_data = {}
            processed_provinces = []
            failed_requests = []

        print(f"\n📍 Toplam {len(provinces)} il bulundu.\n")

        total_districts = 0
        total_neighborhoods = 0

        # Her il için ilçeleri çek
        for idx, (province_name, province_id) in enumerate(provinces, 1):
            # Ardışık 403 kontrolü
            if self.consecutive_403_count >= self.max_consecutive_403:
                print(f"\n🛑 API sürekli 403 hatası veriyor. Script durduruluyor.")
                print(f"💾 {len(processed_provinces)} il işlendi ve kaydedildi.")
                print(f"💡 VPN değiştirip tekrar çalıştırın.\n")
                break

            # Daha önce işlenmişse atla
            if province_name in processed_provinces:
                print(
                    f"[{idx}/{len(provinces)}] {province_name} ✓ (Zaten işlenmiş)")
                continue

            print(
                f"\n[{idx}/{len(provinces)}] 🏙️  {province_name} ilinin ilçeleri çekiliyor...")

            districts = self.fetch_districts(province_id, province_name)

            if not districts:
                print(f"  ⚠️  {province_name} ilçeleri çekilemedi!")
                failed_requests.append({
                    'type': 'province',
                    'name': province_name,
                    'id': province_id,
                    'timestamp': datetime.now().isoformat()
                })
            else:
                district_names = []
                province_failed_districts = []

                for district_name, district_id in districts:
                    district_names.append(district_name)
                    print(f"    📍 {district_name} mahalleleri çekiliyor...")

                    neighborhoods = self.fetch_neighborhoods(
                        district_id, district_name)

                    if neighborhoods:
                        full_district_name = f"{district_name} ({province_name})"
                        district_data[full_district_name] = neighborhoods
                        total_neighborhoods += len(neighborhoods)
                        print(f"      ✅ {len(neighborhoods)} mahalle")
                    else:
                        print(f"      ⚠️  Mahalleler çekilemedi!")
                        province_failed_districts.append({
                            'type': 'district',
                            'province': province_name,
                            'name': district_name,
                            'id': district_id
                        })

                if district_names:
                    province_data[province_name] = district_names
                    total_districts += len(district_names)

                if province_failed_districts:
                    failed_requests.extend(province_failed_districts)

            processed_provinces.append(province_name)

            # HER İL İŞLENDİKTEN SONRA checkpoint kaydet (veri güvenliği için)
            print(f"  💾 {province_name} ili tamamlandı, veriler kaydediliyor...")
            self.save_checkpoint({
                'provinces': provinces,
                'province_data': province_data,
                'district_data': district_data,
                'processed_provinces': processed_provinces,
                'failed_requests': failed_requests,
                'stats': {
                    'total_provinces_processed': len(processed_provinces),
                    'total_districts': total_districts,
                    'total_neighborhoods': total_neighborhoods,
                    'last_processed': province_name,
                    'last_update': datetime.now().isoformat()
                }
            })

            # Her il arasında ekstra bekleme
            if idx < len(provinces):
                print(f"  ⏳ Sonraki il için bekleniyor...")
                time.sleep(random.uniform(5, 10))

        # Başarısız istekleri kaydet
        if failed_requests:
            self.save_failed_requests(failed_requests)
            print(
                f"\n⚠️  {len(failed_requests)} başarısız istek '{self.failed_requests_file}' dosyasına kaydedildi.")

        print(f"\n{'='*60}")
        print(f"✅ Veri çekme tamamlandı!")
        print(
            f"📊 Toplam: {len(processed_provinces)} il, {total_districts} ilçe, {total_neighborhoods} mahalle")
        if failed_requests:
            print(f"⚠️  Başarısız: {len([f for f in failed_requests if f.get('type') == 'province'])} il, "
                  f"{len([f for f in failed_requests if f.get('type') == 'district'])} ilçe")
        print(f"{'='*60}\n")

        return province_data, district_data


def generate_dart_code(province_data: Dict, district_data: Dict) -> str:
    """Dart kodu oluşturur"""
    dart_code = """// Türkiye İl, İlçe ve Mahalle Verileri
// Otomatik olarak oluşturulmuştur
// Üretim tarihi: {}
// Toplam: {} il, {} ilçe, {} mahalle

class LocationConstants {{
  // İl (Province) verisi
  static const Map<String, List<String>> provinces = {{
""".format(
        datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        len(province_data),
        sum(len(districts) for districts in province_data.values()),
        sum(len(neighborhoods) for neighborhoods in district_data.values())
    )

    # İlleri ve ilçeleri ekle
    for province_name in sorted(province_data.keys()):
        districts = province_data[province_name]
        dart_code += f"    '{province_name}': [\n"
        for district in districts:
            dart_code += f"      '{district}',\n"
        dart_code += "    ],\n"

    dart_code += """  };

  // İlçe -> Mahalle eşleştirmesi
  static const Map<String, List<String>> districts = {
"""

    # İlçeleri ve mahalleleri ekle
    for district_name in sorted(district_data.keys()):
        neighborhoods = district_data[district_name]
        dart_code += f"    '{district_name}': [\n"
        for neighborhood in neighborhoods:
            escaped_neighborhood = neighborhood.replace("'", "\\'")
            dart_code += f"      '{escaped_neighborhood}',\n"
        dart_code += "    ],\n"

    dart_code += """  };
  
  // Helper method to get neighborhoods for a district
  static List<String> getNeighborhoods(String district, String province) {
    final key = '$district ($province)';
    return districts[key] ?? [];
  }
  
  // Helper method to get all provinces
  static List<String> getAllProvinces() {
    return provinces.keys.toList()..sort();
  }
  
  // Helper method to get districts of a province
  static List<String> getDistricts(String province) {
    return provinces[province] ?? [];
  }
}
"""

    return dart_code


def main():
    try:
        fetcher = TurkeyLocationFetcher()

        print("=" * 60)
        print("🇹🇷 TÜRKİYE İL-İLÇE-MAHALLE VERİ ÇEKİCİ")
        print("=" * 60)

        # Kullanıcıya seçenek sun
        if os.path.exists(fetcher.checkpoint_file):
            print("\n📁 Önceki bir çalışma bulundu!")
            choice = input(
                "Kaldığınız yerden devam etmek ister misiniz? (E/h): ").lower()
            resume = choice != 'h'
        else:
            resume = False

        # Verileri çek
        province_data, district_data = fetcher.fetch_all_data(resume=resume)

        if not province_data or not district_data:
            print("\n❌ Yeterli veri çekilemedi!")
            return 1

        # Dart kodu oluştur
        print("📝 Dart kodu oluşturuluyor...")
        dart_code = generate_dart_code(province_data, district_data)

        # Dosyaya kaydet
        output_file = "location_constants.dart"
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(dart_code)

        print(f"✅ Dart kodu '{output_file}' dosyasına kaydedildi!")
        print(f"   📏 Dosya boyutu: {len(dart_code):,} karakter")

        # Özet bilgi dosyası oluştur
        summary_file = "location_data_summary.json"
        summary = {
            "generation_date": datetime.now().isoformat(),
            "total_provinces": len(province_data),
            "total_districts": sum(len(districts) for districts in province_data.values()),
            "total_neighborhoods": sum(len(neighborhoods) for neighborhoods in district_data.values()),
            "provinces": {k: len(v) for k, v in province_data.items()},
            "sample_districts": {k: len(v) for k, v in list(district_data.items())[:10]}
        }

        with open(summary_file, 'w', encoding='utf-8') as f:
            json.dump(summary, f, ensure_ascii=False, indent=2)

        print(f"📊 Özet bilgiler '{summary_file}' dosyasına kaydedildi!")

        # Checkpoint dosyasını temizle
        if os.path.exists(fetcher.checkpoint_file):
            choice = input(
                "\n🗑️  Checkpoint dosyasını silmek ister misiniz? (e/H): ").lower()
            if choice == 'e':
                os.remove(fetcher.checkpoint_file)
                print("✅ Checkpoint dosyası silindi.")

        return 0

    except KeyboardInterrupt:
        print("\n\n⚠️  İşlem kullanıcı tarafından iptal edildi!")
        print("💾 İlerleme kaydedildi. Script'i tekrar çalıştırarak devam edebilirsiniz.")
        return 1
    except Exception as e:
        print(f"\n❌ Beklenmeyen hata: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
