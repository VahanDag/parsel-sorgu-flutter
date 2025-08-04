import 'package:flutter/material.dart';

class AreaInfoWidget extends StatelessWidget {
  final Map<String, dynamic> parselData;

  const AreaInfoWidget({super.key, required this.parselData});

  @override
  Widget build(BuildContext context) {
    if (parselData['properties']['alan'] == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.square_foot, size: 20),
          const SizedBox(width: 8),
          Text(
            'Toplam Alan: ${parselData['properties']['alan']} m²',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}