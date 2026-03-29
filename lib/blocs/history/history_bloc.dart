import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parsel_sorgu/blocs/history/history_event.dart';
import 'package:parsel_sorgu/blocs/history/history_state.dart';
import 'package:parsel_sorgu/models/history_entry.dart';
import 'package:parsel_sorgu/services/history_service.dart';

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  final HistoryService _historyService = HistoryService();

  HistoryBloc() : super(const HistoryState()) {
    on<LoadHistoryEvent>(_onLoadHistory);
    on<AddHistoryEntryEvent>(_onAddHistoryEntry);
    on<DeleteHistoryEntryEvent>(_onDeleteHistoryEntry);
    on<ClearHistoryEvent>(_onClearHistory);
  }

  Future<void> _onLoadHistory(
    LoadHistoryEvent event,
    Emitter<HistoryState> emit,
  ) async {
    emit(state.copyWith(status: HistoryStatus.loading));
    try {
      final entries = await _historyService.getHistory();
      emit(state.copyWith(entries: entries, status: HistoryStatus.loaded));
    } catch (e) {
      emit(state.copyWith(status: HistoryStatus.error));
    }
  }

  Future<void> _onAddHistoryEntry(
    AddHistoryEntryEvent event,
    Emitter<HistoryState> emit,
  ) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final screenshotPath = await _historyService.saveScreenshot(
        event.screenshotBytes,
        id,
      );

      final entry = HistoryEntry(
        id: id,
        il: event.parselData['il'] ?? '',
        ilce: event.parselData['ilce'] ?? '',
        mahalle: event.parselData['mahalle'] ?? '',
        adaNo: event.parselData['adaNo'] ?? '',
        parselNo: event.parselData['parselNo'] ?? '',
        tkgmUrl: event.parselData['tkgmUrl'] ?? '',
        screenshotPath: screenshotPath,
        searchDate: DateTime.now(),
      );

      await _historyService.addEntry(entry);
      final entries = await _historyService.getHistory();
      emit(state.copyWith(entries: entries, status: HistoryStatus.loaded));
    } catch (e) {
      // Sessizce basarisiz ol, kullanici deneyimini bozma
    }
  }

  Future<void> _onDeleteHistoryEntry(
    DeleteHistoryEntryEvent event,
    Emitter<HistoryState> emit,
  ) async {
    try {
      await _historyService.deleteEntry(event.id);
      final entries = await _historyService.getHistory();
      emit(state.copyWith(entries: entries, status: HistoryStatus.loaded));
    } catch (e) {
      emit(state.copyWith(status: HistoryStatus.error));
    }
  }

  Future<void> _onClearHistory(
    ClearHistoryEvent event,
    Emitter<HistoryState> emit,
  ) async {
    try {
      await _historyService.clearAll();
      emit(state.copyWith(entries: [], status: HistoryStatus.loaded));
    } catch (e) {
      emit(state.copyWith(status: HistoryStatus.error));
    }
  }
}
