import 'package:flutter/material.dart';

class DistanceRowWidget extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;
  final bool isSubtle;

  const DistanceRowWidget({
    super.key,
    required this.label,
    required this.value,
    this.isHighlighted = false,
    this.isSubtle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isSubtle ? Colors.grey.shade600 : null,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            color: isHighlighted 
                ? Colors.blue.shade700 
                : (isSubtle ? Colors.grey.shade600 : null),
          ),
        ),
      ],
    );
  }
}