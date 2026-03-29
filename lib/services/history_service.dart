import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:parsel_sorgu/models/history_entry.dart';

class HistoryService {
  static const _historyKey = 'parsel_history';
  static const _maxEntries = 100;

  Future<String> get _screenshotDirPath async {
    final dir = await getApplicationDocumentsDirectory();
    final screenshotDir = Directory('${dir.path}/history_screenshots');
    if (!await screenshotDir.exists()) {
      await screenshotDir.create(recursive: true);
    }
    return screenshotDir.path;
  }

  Future<String> saveScreenshot(Uint8List bytes, String id) async {
    final dirPath = await _screenshotDirPath;
    final file = File('$dirPath/$id.png');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<List<HistoryEntry>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_historyKey);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = json.decode(jsonString);
    final entries = jsonList.map((e) => HistoryEntry.fromJson(e)).toList();
    entries.sort((a, b) => b.searchDate.compareTo(a.searchDate));
    return entries;
  }

  Future<void> addEntry(HistoryEntry entry) async {
    final entries = await getHistory();

    // Ayni parsel zaten varsa tarihini ve screenshot'ini guncelle
    final existingIndex = entries.indexWhere(
      (e) =>
          e.il == entry.il &&
          e.ilce == entry.ilce &&
          e.mahalle == entry.mahalle &&
          e.adaNo == entry.adaNo &&
          e.parselNo == entry.parselNo,
    );

    if (existingIndex != -1) {
      final existing = entries.removeAt(existingIndex);
      // Eski screenshot'i sil
      final oldFile = File(existing.screenshotPath);
      if (await oldFile.exists()) await oldFile.delete();
    }

    entries.insert(0, entry);

    // Maks kayit siniri
    if (entries.length > _maxEntries) {
      final removed = entries.removeAt(entries.length - 1);
      final file = File(removed.screenshotPath);
      if (await file.exists()) await file.delete();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      json.encode(entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> deleteEntry(String id) async {
    final entries = await getHistory();
    final entry = entries.firstWhere((e) => e.id == id);
    entries.removeWhere((e) => e.id == id);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      json.encode(entries.map((e) => e.toJson()).toList()),
    );

    final file = File(entry.screenshotPath);
    if (await file.exists()) await file.delete();
  }

  Future<void> clearAll() async {
    final dirPath = await _screenshotDirPath;
    final dir = Directory(dirPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}
