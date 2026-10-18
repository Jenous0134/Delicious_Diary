import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hankki_diary/app/app.dart';
import 'package:hankki_diary/features/meals/data/meal_repository.dart';
import 'package:hankki_diary/features/meals/domain/meal.dart';
import 'package:hankki_diary/features/meals/presentation/meal_state.dart';
import 'package:hankki_diary/features/shell/modern_app_shell.dart';

class _ModernPreviewRepository extends MealRepository {
  final meals = [
    Meal(
      id: 'meal-1',
      eatenDate: DateTime(2026, 10, 18),
      type: MealType.dinner,
      placeName: '을지로 골목식당',
      placeSource: 'manual',
      createdAt: DateTime(2026, 10, 18),
      updatedAt: DateTime(2026, 10, 18),
      items: const [MealItem(name: '삼겹살')],
      people: const ['친구'],
    ),
  ];

  @override
  Future<List<Meal>> find([MealFilter filter = const MealFilter()]) async =>
      meals;

  @override
  Future<Meal?> byId(String id) async => meals.first;

  @override
  Future<List<String>> recentPlaces() async => const [];

  @override
  Future<List<String>> recentPeople() async => const [];
}

void main() {
  testWidgets('modern shell exposes five-tab photo archive navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(_ModernPreviewRepository()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          locale: const Locale('ko', 'KR'),
          supportedLocales: const [Locale('ko', 'KR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const ModernAppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('한끼일기'), findsOneWidget);
    expect(find.text('삼겹살'), findsOneWidget);
    expect(find.text('피드'), findsOneWidget);
    expect(find.text('캘린더'), findsOneWidget);
    expect(find.text('지도'), findsOneWidget);
    expect(find.text('보관함'), findsOneWidget);

    await tester.tap(find.text('보관함'));
    await tester.pumpAndSettle();
    expect(find.text('전체 사진'), findsOneWidget);
    expect(find.text('대표 사진'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
