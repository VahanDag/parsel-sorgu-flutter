import 'package:flutter/material.dart';

class LocationLoadingIndicatorWidget extends StatelessWidget {
  final bool isLoadingLocation;
  final bool isLoadingParselData;

  const LocationLoadingIndicatorWidget({
    super.key,
    required this.isLoadingLocation,
    required this.isLoadingParselData,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoadingLocation && !isLoadingParselData) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                isLoadingLocation ? 'Konum alınıyor...' : 'Parsel bilgileri yükleniyor...',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}