import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData?.text != null && clipboardData!.text!.isNotEmpty) {
      controller.text = clipboardData.text!;
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    }
  }

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
            : IconButton(
                icon: const Icon(Icons.content_paste_rounded),
                onPressed: _pasteFromClipboard,
              ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      onChanged: onChanged,
    );
  }
}
