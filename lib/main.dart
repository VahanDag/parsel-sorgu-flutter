import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parsel_sorgu/blocs/parsel_searching/parsel_searching_bloc.dart';
import 'package:parsel_sorgu/blocs/shared_url/shared_url_bloc.dart';
import 'package:parsel_sorgu/blocs/shared_url/shared_url_event.dart';
import 'package:parsel_sorgu/blocs/shared_url/shared_url_state.dart';
import 'package:parsel_sorgu/blocs/tkgm/tkgm_bloc.dart';
import 'package:parsel_sorgu/screens/parsel_searching/parsel_searching_screen.dart';
import 'package:parsel_sorgu/screens/splash_screen.dart';

part 'screens/widgets/invalid_url_error_sheet.dart';

void main() {
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
  Widget build(BuildContext context) {
    sharedUrlBloc = SharedUrlBloc(onInvalidUrl: _showInvalidUrlModal);

    return MultiBlocProvider(
      providers: [
        BlocProvider<SharedUrlBloc>(
          create: (context) => sharedUrlBloc..add(const InitializeSharedUrl()),
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
          cardTheme: CardThemeData(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        // Ana ekran
        home: const AppHome(),
        debugShowCheckedModeBanner: false, // Debug banner'ını kaldır
      ),
    );
  }
}

class AppHome extends StatefulWidget {
  const AppHome({super.key});

  @override
  State<AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SharedUrlBloc, SharedUrlState>(
      builder: (context, state) {
        print("BlocBuilder: Building with state ${state.runtimeType}");
        String? sharedUrl;

        if (state is SharedUrlReceived) {
          sharedUrl = state.url;
          print("BlocBuilder: SharedUrl = $sharedUrl");
        }

        return SplashScreen(
          sharedUrl: sharedUrl,
          nextScreen: ParselSearchScreen(sharedUrl: sharedUrl),
        );
      },
    );
  }
}
