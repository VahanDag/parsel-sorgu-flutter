import 'package:flutter/material.dart';

class ActionButtonsWidget extends StatelessWidget {
  final bool isLoading;
  final bool isExtractingData;
  final bool isValidUrl;
  final int currentStep;
  final VoidCallback onLoadUrl;
  final VoidCallback onExtractData;
  final Animation<double> pulseAnimation;

  const ActionButtonsWidget({
    super.key,
    required this.isLoading,
    required this.isExtractingData,
    required this.isValidUrl,
    required this.currentStep,
    required this.onLoadUrl,
    required this.onExtractData,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : onLoadUrl,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download),
            label: Text(isLoading ? 'Yükleniyor...' : 'Sayfayı Yükle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: currentStep == 1 ? pulseAnimation.value : 1.0,
                child: ElevatedButton.icon(
                  onPressed: (isLoading || isExtractingData || currentStep < 1) ? null : onExtractData,
                  icon: isExtractingData
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search),
                  label: Text(isExtractingData ? 'Alınıyor...' : 'Parseli Sorgula'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}