import 'package:equatable/equatable.dart';

class HistoryEntry extends Equatable {
  final String id;
  final String il;
  final String ilce;
  final String mahalle;
  final String adaNo;
  final String parselNo;
  final String tkgmUrl;
  final String screenshotPath;
  final DateTime searchDate;

  const HistoryEntry({
    required this.id,
    required this.il,
    required this.ilce,
    required this.mahalle,
    required this.adaNo,
    required this.parselNo,
    required this.tkgmUrl,
    required this.screenshotPath,
    required this.searchDate,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      id: json['id'] as String,
      il: json['il'] as String,
      ilce: json['ilce'] as String,
      mahalle: json['mahalle'] as String,
      adaNo: json['adaNo'] as String,
      parselNo: json['parselNo'] as String,
      tkgmUrl: json['tkgmUrl'] as String,
      screenshotPath: json['screenshotPath'] as String,
      searchDate: DateTime.parse(json['searchDate'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'il': il,
      'ilce': ilce,
      'mahalle': mahalle,
      'adaNo': adaNo,
      'parselNo': parselNo,
      'tkgmUrl': tkgmUrl,
      'screenshotPath': screenshotPath,
      'searchDate': searchDate.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id];
}
