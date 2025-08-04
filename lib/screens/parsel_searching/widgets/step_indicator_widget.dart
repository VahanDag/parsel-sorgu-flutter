import 'package:flutter/material.dart';

class StepIndicatorWidget extends StatelessWidget {
  final int currentStep;

  const StepIndicatorWidget({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStep(context, 1, 'Link Girildi', currentStep >= 0),
          _buildConnector(context, currentStep >= 1),
          _buildStep(context, 2, 'Sayfa Yüklendi', currentStep >= 1),
          _buildConnector(context, currentStep >= 2),
          _buildStep(context, 3, 'Veri Alındı', currentStep >= 2),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context, int number, String label, bool isActive) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade300,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? Colors.black87 : Colors.grey,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConnector(BuildContext context, bool isActive) {
    return Container(
      height: 2,
      width: 40,
      color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade300,
    );
  }
}