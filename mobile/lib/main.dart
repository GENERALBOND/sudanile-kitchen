import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/favorites_provider.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('access_token');
  
  runApp(SudanileKitchenApp(initialToken: token));
}

class SudanileKitchenApp extends StatelessWidget {
  final String? initialToken;
  
  const SudanileKitchenApp({super.key, this.initialToken});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService(initialToken)),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
      ],
      child: MaterialApp(
        title: 'Sudanile Kitchen',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.orange,
          fontFamily: 'Poppins',
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
