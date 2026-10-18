import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/meals/data/meal_repository.dart';
import '../features/meals/domain/meal.dart';
import '../features/meals/presentation/meal_state.dart';
import '../features/shell/app_shell.dart';

/// Real screens with an empty, isolated repository for desktop UI review.
class UiPreview extends StatelessWidget {
  const UiPreview({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFEAE4DB),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ProviderScope(
          overrides: [
            mealRepositoryProvider.overrideWithValue(_PreviewRepository()),
            mealsProvider.overrideWith((ref) async => <Meal>[]),
            filteredMealsProvider.overrideWith((ref, filter) async => <Meal>[]),
          ],
          child: LayoutBuilder(
            builder: (context, constraints) => MediaQuery(
              data: MediaQuery.of(context).copyWith(size: constraints.biggest),
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => const Column(
                    children: [
                      Material(
                        color: Color(0xFFF0E5D8),
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Text(
                              'UI 미리보기 · 사진 저장과 백업은 Android 앱에서',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF7A5638),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(child: AppShell()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PreviewRepository extends MealRepository {
  @override
  Future<List<Meal>> find([MealFilter filter = const MealFilter()]) async => [];
  @override
  Future<List<String>> recentPlaces() async => [];
  @override
  Future<List<String>> recentPeople() async => [];
}
