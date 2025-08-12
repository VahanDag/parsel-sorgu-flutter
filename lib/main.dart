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
          cardTheme: CardTheme(
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
      // listener kullanarak state değişikliklerini yakalayabiliriz
      listener: (context, state) {
        print("BlocConsumer: State changed to ${state.runtimeType}");
        if (state is SharedUrlReceived) {
          print("BlocConsumer: SharedUrl received = ${state.url}");
          // Gerekirse burada navigation veya diğer işlemler yapılabilir
        }
      },
      // buildWhen ile gereksiz rebuild'leri önleyebiliriz
      buildWhen: (previous, current) {
        // Her zaman rebuild et (test amaçlı)
        print("BlocConsumer: Previous state: ${previous.runtimeType}, Current state: ${current.runtimeType}");
        return true;
      },
      builder: (context, state) {
        print("BlocConsumer: Building with state ${state.runtimeType}");
        String? sharedUrl;

        if (state is SharedUrlReceived) {
          sharedUrl = state.url;
          print("BlocConsumer: SharedUrl in builder = $sharedUrl");
        }

        return SplashScreen(
          sharedUrl: sharedUrl,
          nextScreen: ParselSearchScreen(
            sharedUrl: sharedUrl,
          ),
        );
      },
    );
  }
}
