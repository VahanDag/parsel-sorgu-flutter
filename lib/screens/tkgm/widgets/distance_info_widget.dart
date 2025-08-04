import 'package:flutter/material.dart';
import 'distance_row_widget.dart';
import 'section_title_widget.dart';

class DistanceInfoWidget extends StatelessWidget {
  final Map<String, dynamic> distanceData;

  const DistanceInfoWidget({super.key, required this.distanceData});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitleWidget(title: '📍 Konumunuzdan Uzaklık'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              DistanceRowWidget(
                label: '✈️ Kuş Uçuşu:',
                value: '${distanceData['straight'].toStringAsFixed(2)} km',
              ),
              const SizedBox(height: 4),
              DistanceRowWidget(
                label: '🚗 Tahmini Yol:',
                value: '${distanceData['road'].toStringAsFixed(2)} km',
                isHighlighted: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}