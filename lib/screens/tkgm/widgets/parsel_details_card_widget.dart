import 'package:flutter/material.dart';

import 'area_info_widget.dart';
import 'distance_info_widget.dart';
import 'edge_lengths_widget.dart';

class ParselDetailsCardWidget extends StatelessWidget {
  final bool showDetails;
  final VoidCallback onToggleDetails;
  final Map<String, dynamic>? distanceData;
  final List<double>? edgeLengths;
  final Map<String, dynamic>? parselData;

  const ParselDetailsCardWidget({
    super.key,
    required this.showDetails,
    required this.onToggleDetails,
    this.distanceData,
    this.edgeLengths,
    this.parselData,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxCardHeight = screenHeight * 0.6; // Maksimum kart yüksekliği ekranın %60'ı

    return Positioned(
      bottom: 100,
      left: 20,
      right: 20,
      child: Listener(
        onPointerDown: (_) {},
        behavior: HitTestBehavior.opaque,
        child: GestureDetector(
          onTap: onToggleDetails,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: showDetails ? maxCardHeight : 80, // Kapatıldığında sabit yükseklik
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header - sabit kısım (kaydırılmaz)
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                                const SizedBox(width: 8),
                                const Text(
                                  'Parsel Detayları',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Icon(
                              showDetails ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                      // Content - kaydırılabilir kısım
                      if (showDetails)
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              children: [
                                if (distanceData != null) ...[
                                  DistanceInfoWidget(distanceData: distanceData!),
                                  const SizedBox(height: 12),
                                ],
                                if (edgeLengths != null) ...[
                                  EdgeLengthsWidget(edgeLengths: edgeLengths!),
                                  const SizedBox(height: 8),
                                ],
                                if (parselData != null) ...[
                                  AreaInfoWidget(parselData: parselData!),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  '⚠️ Mesafe tahmini olup, gerçek değerler farklı olabilir',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
