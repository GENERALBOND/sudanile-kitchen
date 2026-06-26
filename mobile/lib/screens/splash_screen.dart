import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/recipe_service.dart';
import '../providers/favorites_provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // Preload data while splash screen is showing
    if (authService.isAuthenticated) {
      final favProvider = Provider.of<FavoritesProvider>(context, listen: false);
      final recipeService = RecipeService();
      
      // Load everything in parallel
      await Future.wait([
        recipeService.getCategories(),
        recipeService.getRecipes(),
        favProvider.loadFavorites(),
      ]);
    }
    
    // Wait a moment for smooth transition
    await Future.delayed(const Duration(seconds: 1));
    
    if (!mounted) return;
    
    // Navigate to appropriate screen
    if (authService.isAuthenticated) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.orange.shade400, Colors.orange.shade700],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  size: 70,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sudanile Kitchen',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Preserving South Sudanese Culinary Heritage',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
