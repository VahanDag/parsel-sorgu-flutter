import 'dart:typed_data';

import 'package:equatable/equatable.dart';

abstract class HistoryEvent extends Equatable {
  const HistoryEvent();

  @override
  List<Object?> get props => [];
}

class LoadHistoryEvent extends HistoryEvent {
  const LoadHistoryEvent();
}

class AddHistoryEntryEvent extends HistoryEvent {
  final Map<String, dynamic> parselData;
  final Uint8List screenshotBytes;

  const AddHistoryEntryEvent({
    required this.parselData,
    required this.screenshotBytes,
  });

  @override
  List<Object?> get props => [parselData, screenshotBytes];
}

class DeleteHistoryEntryEvent extends HistoryEvent {
  final String id;

  const DeleteHistoryEntryEvent(this.id);

  @override
  List<Object?> get props => [id];
}

class ClearHistoryEvent extends HistoryEvent {
  const ClearHistoryEvent();
}
