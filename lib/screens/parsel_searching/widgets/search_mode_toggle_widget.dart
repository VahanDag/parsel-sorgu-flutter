import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parsel_sorgu/blocs/parsel_searching/parsel_searching_bloc.dart';
import 'package:parsel_sorgu/blocs/parsel_searching/parsel_searching_event.dart';
import 'package:parsel_sorgu/blocs/parsel_searching/parsel_searching_state.dart';

class SearchModeToggleWidget extends StatelessWidget {
  const SearchModeToggleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ParselSearchingBloc, ParselSearchingState>(
      builder: (context, state) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeButton(
                context,
                'WebView Arama',
                SearchMode.webView,
                state.searchMode == SearchMode.webView,
                Icons.web,
              ),
              _buildModeButton(
                context,
                'Manuel Arama',
                SearchMode.manual,
                state.searchMode == SearchMode.manual,
                Icons.edit,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeButton(
    BuildContext context,
    String label,
    SearchMode mode,
    bool isSelected,
    IconData icon,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          context.read<ParselSearchingBloc>().add(const ToggleSearchModeEvent());
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: isSelected 
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected 
                    ? Colors.white 
                    : Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: isSelected 
                      ? Colors.white 
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}