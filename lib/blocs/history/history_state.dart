import 'package:equatable/equatable.dart';
import 'package:parsel_sorgu/models/history_entry.dart';

enum HistoryStatus { initial, loading, loaded, error }

class HistoryState extends Equatable {
  final List<HistoryEntry> entries;
  final HistoryStatus status;

  const HistoryState({
    this.entries = const [],
    this.status = HistoryStatus.initial,
  });

  HistoryState copyWith({
    List<HistoryEntry>? entries,
    HistoryStatus? status,
  }) {
    return HistoryState(
      entries: entries ?? this.entries,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [entries, status];
}
