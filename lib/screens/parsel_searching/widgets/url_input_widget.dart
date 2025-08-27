import 'package:flutter/material.dart';

class UrlInputWidget extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClear;
  final Function(String) onChanged;

  const UrlInputWidget({
    super.key,
    required this.controller,
    required this.onClear,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: 'Arsa linkini buraya yapıştırın',
        prefixIcon: const Icon(Icons.link, size: 28),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: onClear,
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      onChanged: onChanged,
    );
  }
}
