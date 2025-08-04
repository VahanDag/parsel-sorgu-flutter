import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'measurement_card_widget.dart';
import 'section_title_widget.dart';

class EdgeLengthsWidget extends StatelessWidget {
  final List<double> edgeLengths;

  const EdgeLengthsWidget({super.key, required this.edgeLengths});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitleWidget(title: '📐 Parsel Ölçüleri'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  MeasurementCardWidget(
                    label: 'En Uzun',
                    value: '${edgeLengths.reduce(math.max).toStringAsFixed(2)} m',
                    color: Colors.green.shade700,
                  ),
                  MeasurementCardWidget(
                    label: 'En Kısa',
                    value: '${edgeLengths.reduce(math.min).toStringAsFixed(2)} m',
                    color: Colors.orange.shade700,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Kenar Uzunlukları:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: edgeLengths.asMap().entries.map((entry) {
                  return Chip(
                    label: Text(
                      'K${entry.key + 1}: ${entry.value.toStringAsFixed(1)}m',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.green.shade100,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}