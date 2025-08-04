import 'package:flutter/material.dart';
import 'package:parsel_sorgu/screens/parsel_searching/widgets/how_to_works_sheet.dart';

class ControlButtonsWidget extends StatelessWidget {
  final bool showWebView;
  final VoidCallback onToggleWebView;

  const ControlButtonsWidget({
    super.key,
    required this.showWebView,
    required this.onToggleWebView,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        TextButton.icon(
          onPressed: onToggleWebView,
          icon: Icon(showWebView ? Icons.visibility_off : Icons.visibility),
          label: Text(showWebView ? 'Sayfayı Gizle' : 'Sayfayı Göster'),
        ),
        TextButton.icon(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => buildHowItWorksBottomSheet(),
            );
          },
          icon: const Icon(Icons.question_mark_rounded),
          label: const Text("Nasıl Çalışır?"),
        ),
      ],
    );
  }
}