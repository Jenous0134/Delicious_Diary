import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/meal_repository.dart';
import '../domain/meal.dart';

final mealRepositoryProvider = Provider((ref) => MealRepository());

class MealRevision extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final mealRevisionProvider = NotifierProvider<MealRevision, int>(
  MealRevision.new,
);
final mealsProvider = FutureProvider<List<Meal>>((ref) {
  ref.watch(mealRevisionProvider);
  return ref.read(mealRepositoryProvider).find();
});
final filteredMealsProvider = FutureProvider.family<List<Meal>, MealFilter>((
  ref,
  filter,
) {
  ref.watch(mealRevisionProvider);
  return ref.read(mealRepositoryProvider).find(filter);
});
void refreshMeals(WidgetRef ref) =>
    ref.read(mealRevisionProvider.notifier).bump();
