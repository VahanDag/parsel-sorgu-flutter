import 'package:flutter/material.dart';

import 'info_row_widget.dart';

class ParselDataCardWidget extends StatelessWidget {
  final Map<String, dynamic> parselData;

  const ParselDataCardWidget({super.key, required this.parselData});

  bool _isDataComplete() {
    final requiredFields = ['il', 'ilce', 'mahalle', 'adaNo', 'parselNo'];
    for (String field in requiredFields) {
      final value = parselData[field]?.toString().trim();
      if (value == null || value.isEmpty || value.toLowerCase().contains("belirtilmemiş")) {
        return false;
      }
    }
    return true;
  }

  List<String> _getMissingFields() {
    final List<String> missingFields = [];
    final fieldNames = {'il': 'İl', 'ilce': 'İlçe', 'mahalle': 'Mahalle', 'adaNo': 'Ada No', 'parselNo': 'Parsel No'};

    fieldNames.forEach((key, name) {
      final value = parselData[key]?.toString().trim();
      if (value == null || value.isEmpty || value.toLowerCase().contains("belirtilmemiş")) {
        missingFields.add(name);
      }
    });

    return missingFields;
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = _isDataComplete();
    final missingFields = _getMissingFields();

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isComplete ? [Colors.green.shade50, Colors.green.shade100] : [Colors.orange.shade50, Colors.orange.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isComplete ? Colors.green.shade300 : Colors.orange.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isComplete ? Icons.check_circle : Icons.warning,
                    color: isComplete ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isComplete ? 'Parsel Bilgileri Alındı' : 'Parsel Bilgileri Eksik',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isComplete ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InfoRowWidget(label: 'İl', value: parselData['il']),
              InfoRowWidget(label: 'İlçe', value: parselData['ilce']),
              InfoRowWidget(label: 'Mahalle', value: parselData['mahalle']),
              InfoRowWidget(label: 'Ada No', value: parselData['adaNo']),
              InfoRowWidget(label: 'Parsel No', value: parselData['parselNo']),
            ],
          ),
        ),
        if (!isComplete) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'TKGM Sorgusu İçin Eksik Bilgiler:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• ${missingFields.join('\n• ')}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bu bilgiler olmadan TKGM sorgusu yapılamaz. Lütfen farklı bir ilan deneyin veya sayfanın tam yüklenmesini bekleyin.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
