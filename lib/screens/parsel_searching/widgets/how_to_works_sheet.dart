// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';

Widget buildHowItWorksBottomSheet() {
  return DraggableScrollableSheet(
    initialChildSize: 0.85,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    expand: false,
    builder: (context, scrollController) {
      return HowItWorksContents(scrollController: scrollController);
    },
  );
}

class HowItWorksContents extends StatefulWidget {
  const HowItWorksContents({super.key, this.scrollController});
  final ScrollController? scrollController;
  @override
  State<HowItWorksContents> createState() => _HowItWorksContentsState();
}

class _HowItWorksContentsState extends State<HowItWorksContents> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),

          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16),

                    // Header
                    _buildHeader(),

                    SizedBox(height: 32),

                    // Kullanım yöntemleri
                    _buildUsageMethods(),

                    SizedBox(height: 32),

                    // Özellikler
                    _buildFeatures(),

                    SizedBox(height: 32),

                    // Örnek link
                    _buildExampleSection(),

                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Ana ikon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue[400]!, Colors.blue[600]!]),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), offset: Offset(0, 8), blurRadius: 24)],
          ),
          child: Icon(Icons.home_work_outlined, size: 40, color: Colors.white),
        ),

        SizedBox(height: 20),

        // Başlık
        Text(
          'Parsel Sorgulama',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey[800]),
        ),

        SizedBox(height: 8),

        // Alt başlık
        Text(
          'TKGM sisteminden güncel parsel bilgilerini hzılıca sorgulayın',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.4),
        ),
      ],
    );
  }

  Widget _buildUsageMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nasıl Kullanılır?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[800]),
        ),

        SizedBox(height: 20),

        // Paylaşım yöntemi
        _buildMethodCard(
          icon: Icons.share,
          iconColor: Colors.green[600]!,
          iconBg: Colors.green[50]!,
          title: '1. Paylaşım ile (Önerilen)',
          subtitle: 'En hızlı yöntem',
          steps: ['Sahibinden uygulamasında ilan açın', 'Paylaş (Share) butonuna dokunun', 'Parsel Sorgulama uygulamasını seçin', 'Otomatik olarak parsel sorgulanır ✨'],
        ),

        SizedBox(height: 20),

        // Manuel yöntem
        _buildMethodCard(
          icon: Icons.link,
          iconColor: Colors.blue[600]!,
          iconBg: Colors.blue[50]!,
          title: '2. Link ile Manuel',
          subtitle: 'Klasik yöntem',
          steps: ['Sahibinden.com\'dan ilan linkini kopyalayın', 'Uygulamaya yapıştırın', '"Sayfayı Yükle" butonuna tıklayın', '"Parseli Sorgula" ile TKGM sorgusu yapın'],
        ),
      ],
    );
  }

  Widget _buildMethodCard({required IconData icon, required Color iconColor, required Color iconBg, required String title, required String subtitle, required List<String> steps}) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                    ),
                    Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;

            return Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 2),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(step, style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFeatures() {
    final features = [
      {'icon': Icons.verified_outlined, 'title': 'TKGM Entegrasyonu', 'description': 'Tapu ve Kadastro\'dan güncel parsel bilgileri', 'color': Colors.orange[600]},
      {'icon': Icons.speed, 'title': 'Hızlı Sorgulama', 'description': 'Link analizi ile otomatik parsel tespiti', 'color': Colors.purple[600]},
      {'icon': Icons.mobile_friendly, 'title': 'Kolay Paylaşım', 'description': 'Diğer uygulamalardan direkt paylaşım desteği', 'color': Colors.teal[600]},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Özellikler',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[800]),
        ),
        SizedBox(height: 16),
        ...features.map((feature) {
          return Container(
            margin: EdgeInsets.only(bottom: 16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), offset: Offset(0, 2), blurRadius: 8)],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: (feature['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(feature['icon'] as IconData, color: feature['color'] as Color, size: 20),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature['title'] as String,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                      ),
                      SizedBox(height: 4),
                      Text(feature['description'] as String, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildExampleSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.amber[50]!, Colors.orange[50]!]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.orange[600], size: 24),
              SizedBox(width: 12),
              Text(
                'Örnek Link',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[800]),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'https://www.sahibinden.com/ilan/...',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600], fontFamily: 'monospace'),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // Örnek linki text field'a yapıştır
                    setState(() {
                      // _urlController.text = 'https://www.sahibinden.com/ilan/emlak-konut-satilik-ornek-ilan-123456789';
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(6)),
                    child: Icon(Icons.content_copy, size: 16, color: Colors.orange[600]),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          Text('Bu örnek linki kullanarak uygulamayı test edebilirsiniz', style: TextStyle(fontSize: 13, color: Colors.orange[700])),
        ],
      ),
    );
  }
}
