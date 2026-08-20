import 'package:flutter/material.dart';
import '../utils/meal_types.dart';
import '../utils/app_themes.dart';
import 'search_screen.dart';

class AllMealTimesScreen extends StatelessWidget {
  const AllMealTimesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Meal Times'),
        backgroundColor: Colors.orange,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
        ),
        itemCount: mealTypeOptions.length,
        itemBuilder: (context, index) {
          final option = mealTypeOptions[index];
          final icon = switch (option.key) {
            'breakfast' => Icons.free_breakfast,
            'lunch' => Icons.lunch_dining,
            'dinner' => Icons.dinner_dining,
            _ => Icons.schedule,
          };
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SearchScreen(initialMeal: option.key),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: context.appColors.iconCircleBg,
                      borderRadius: BorderRadius.circular(35),
                    ),
                    child: Icon(
                      icon,
                      size: 35,
                      color: context.appColors.iconCircleFg,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      option.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}