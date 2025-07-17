import 'package:flutter/material.dart';
import 'package:parsel_sorgu_app/core/url_expander.dart';
import 'package:parsel_sorgu_app/screens/alternative_parsel_searching.dart';
import 'package:parsel_sorgu_app/screens/splash_screen.dart'; // Yeni splash ekranını import edin
import 'package:share_handler/share_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? sharedUrl;

  @override
  void initState() {
    super.initState();
    _initShareHandling();
  }

  // Paylaşım olaylarını yönetmek için birleşik bir fonksiyon
  Future<void> _initShareHandling() async {
    final handler = ShareHandlerPlatform.instance;

    // 1. Uygulama kapalıyken gelen ilk paylaşımı yakala
    try {
      final initialMedia = await handler.getInitialSharedMedia();

      if (initialMedia != null) {
        _handleSharedMedia(initialMedia);
      }
    } catch (e) {}

    // 2. Uygulama açıkken gelen yeni paylaşımları dinle
    handler.sharedMediaStream.listen((SharedMedia media) {
      _handleSharedMedia(media);
    }, onError: (error) {});
  }

  // Gelen paylaşım verisini işleyen ve arayüzü güncelleyen fonksiyon
  void _handleSharedMedia(SharedMedia media) async {
    if (media.content != null && (media.content!.contains('sahibinden.com') || media.content!.contains('shbd.io'))) {
      String finalUrl = media.content!;

      // Kısaltılmış URL ise genişlet
      if (media.content!.contains('shbd.io')) {
        final expandedUrl = await UrlExpander.expandUrl(media.content!);
        if (expandedUrl != null) {
          finalUrl = expandedUrl;
        }
      }

      setState(() {
        sharedUrl = finalUrl;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parsel Sorgulama',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        cardTheme: CardThemeData(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      // Ana ekran olarak splash ekranını göster
      home: SplashScreen(
        sharedUrl: sharedUrl,
        nextScreen: AlternativeParselScreen(sharedUrl: sharedUrl),
      ),
      debugShowCheckedModeBanner: false, // Debug banner'ını kaldır
    );
  }
}
