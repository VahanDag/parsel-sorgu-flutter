import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parsel_sorgu/blocs/parsel_searching/parsel_searching_bloc.dart';
import 'package:parsel_sorgu/blocs/tkgm/tkgm_bloc.dart';
import 'package:parsel_sorgu/core/url_expander.dart';
import 'package:parsel_sorgu/screens/parsel_searching/parsel_searching_screen.dart';
import 'package:parsel_sorgu/screens/splash_screen.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

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
  late StreamSubscription _intentSub;

  @override
  void initState() {
    super.initState();
    _initShareHandling();
  }

  // Paylaşım olaylarını yönetmek için birleşik bir fonksiyon
  Future<void> _initShareHandling() async {
    // 1. Uygulama açıkken gelen yeni paylaşımları dinle
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedMedia(value.first);
      }
    }, onError: (error) {
      print("getMediaStream error: $error");
    });

    // 2. Uygulama kapalıyken gelen ilk paylaşımı yakala
    try {
      final List<SharedMediaFile> initialMedia = await ReceiveSharingIntent.instance.getInitialMedia();

      if (initialMedia.isNotEmpty) {
        _handleSharedMedia(initialMedia.first);
        // Kütüphaneye intent'in işlendiğini bildir
        ReceiveSharingIntent.instance.reset();
      }
    } catch (e) {
      print("getInitialMedia error: $e");
    }
  }

  // Gelen paylaşım verisini işleyen ve arayüzü güncelleyen fonksiyon
  void _handleSharedMedia(SharedMediaFile media) async {
    // SharedMediaFile'dan path'i al (URL metinleri için path kullanılır)
    final content = media.path;

    if (content.contains('sahibinden.com') || content.contains('shbd.io')) {
      String finalUrl = content;

      // Kısaltılmış URL ise genişlet
      if (content.contains('shbd.io')) {
        final expandedUrl = await UrlExpander.expandUrl(content);
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
  void dispose() {
    _intentSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ParselSearchingBloc>(
          create: (context) => ParselSearchingBloc(),
        ),
        BlocProvider<TkgmBloc>(
          create: (context) => TkgmBloc(),
        ),
      ],
      child: MaterialApp(
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
          nextScreen: ParselSearchScreen(sharedUrl: sharedUrl),
        ),
        debugShowCheckedModeBanner: false, // Debug banner'ını kaldır
      ),
    );
  }
}
