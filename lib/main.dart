import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:parsel_sorgu/blocs/parsel_searching/parsel_searching_bloc.dart';
import 'package:parsel_sorgu/blocs/shared_url/shared_url_bloc.dart';
import 'package:parsel_sorgu/blocs/shared_url/shared_url_event.dart';
import 'package:parsel_sorgu/blocs/shared_url/shared_url_state.dart';
import 'package:parsel_sorgu/blocs/tkgm/tkgm_bloc.dart';
import 'package:parsel_sorgu/screens/parsel_searching/parsel_searching_screen.dart';
import 'package:parsel_sorgu/screens/splash_screen.dart';

part 'screens/widgets/invalid_url_error_sheet.dart';

///
/// Author: Vahan Dağ
///
/// 14.12.2025
///

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  late SharedUrlBloc sharedUrlBloc;

  @override
  void initState() {
    super.initState();
    // SharedUrlBloc'u bir kez oluştur
    sharedUrlBloc = SharedUrlBloc(onInvalidUrl: _showInvalidUrlModal);
  }

  void _showInvalidUrlModal() {
    final BuildContext? context = navigatorKey.currentContext;
    if (context != null && !Navigator.canPop(context)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (timeStamp) {
          showInvalidUrlBottomSheet(context: context, sharedUrlBloc: sharedUrlBloc);
        },
      );
    }
  }

  @override
  void dispose() {
    sharedUrlBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SharedUrlBloc>.value(
          value: sharedUrlBloc..add(const InitializeSharedUrl()),
        ),
        BlocProvider<ParselSearchingBloc>(
          create: (context) => ParselSearchingBloc(),
        ),
        BlocProvider<TkgmBloc>(
          create: (context) => TkgmBloc(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Parsel Sorgulama',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          cardTheme: CardThemeData(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        home: const AppHome(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AppHome extends StatelessWidget {
  const AppHome({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SharedUrlBloc, SharedUrlState>(
      listener: (context, state) {},
      builder: (context, state) {
        return SplashScreen(
          nextScreen: ParselSearchScreen(),
        );
      },
    );
  }
}
