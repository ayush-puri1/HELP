import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'screens/splash_screen.dart';
import 'screens/emergency_contacts_screen.dart';
import 'screens/activation_screen.dart';
import 'services/emergency_contacts_repository.dart';
import 'services/background_listening_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize background service
  await BackgroundListeningService.initialize();
  
  // Listen for activation events from background service
  final service = FlutterBackgroundService();
  service.on('activate').listen((event) {
    if (event != null && navigatorKey.currentContext != null) {
      navigatorKey.currentContext!.go('/activation');
    }
  });
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EmergencyContactsRepository()),
        ChangeNotifierProvider(create: (_) => BackgroundListeningService()),
      ],
      child: MaterialApp.router(
        title: 'Voice Recognition',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        routerConfig: _router,
      ),
    );
  }
}

final GoRouter _router = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/contacts',
      builder: (context, state) => const EmergencyContactsScreen(),
    ),
    GoRoute(
      path: '/activation',
      builder: (context, state) => const ActivationScreen(),
    ),
  ],
);
