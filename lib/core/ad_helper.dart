import 'dart:io';

import 'package:flutter/foundation.dart';

class AdHelper {
  static bool get _isTest => kDebugMode;

  // Banner - ParselSearchScreen
  static String get parselSearchBannerAdUnitId {
    if (Platform.isAndroid) {
      return _isTest
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-6142015479722071/3360293215';
    } else if (Platform.isIOS) {
      return _isTest
          ? 'ca-app-pub-3940256099942544/2934735716'
          : 'ca-app-pub-6142015479722071/3360293215';
    }
    throw UnsupportedError('Unsupported platform');
  }

  // Banner - HistoryScreen
  static String get historyBannerAdUnitId {
    if (Platform.isAndroid) {
      return _isTest
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-6142015479722071/3093576582';
    } else if (Platform.isIOS) {
      return _isTest
          ? 'ca-app-pub-3940256099942544/2934735716'
          : 'ca-app-pub-6142015479722071/9912369445';
    }
    throw UnsupportedError('Unsupported platform');
  }

  // Banner - TKGMWebViewScreen
  static String get tkgmBannerAdUnitId {
    if (Platform.isAndroid) {
      return _isTest
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-6142015479722071/6585222350';
    } else if (Platform.isIOS) {
      return _isTest
          ? 'ca-app-pub-3940256099942544/2934735716'
          : 'ca-app-pub-6142015479722071/4610125274';
    }
    throw UnsupportedError('Unsupported platform');
  }
}
