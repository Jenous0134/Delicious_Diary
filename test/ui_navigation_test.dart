import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hankki_diary/app/app.dart';
import 'package:hankki_diary/app/ui_preview.dart';
import 'package:hankki_diary/features/meals/data/meal_repository.dart';
import 'package:hankki_diary/features/meals/domain/meal.dart';
import 'package:hankki_diary/features/meals/presentation/meal_state.dart';
import 'package:hankki_diary/features/shell/app_shell.dart';

class _MemoryMeals extends MealRepository {
  final records = [
    for (final type in [MealType.lunch, MealType.dinner])
      Meal(
        id: type.name,
        eatenDate: DateTime.now(),
        type: type,
        placeName: type == MealType.lunch ? '점심식당' : '우리집',
        placeSource: 'manual',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: [MealItem(name: type == MealType.lunch ? '파스타' : '된장찌개')],
      ),
  ];
  @override
  Future<List<Meal>> find([MealFilter filter = const MealFilter()]) async =>
      records
          .where(
            (m) =>
                (filter.type == null || m.type == filter.type) &&
                (filter.place == null || m.placeName.contains(filter.place!)) &&
                (filter.menu == null ||
                    filter.menu!.isEmpty ||
                    m.items.any((i) => i.name.contains(filter.menu!))),
          )
          .toList();
  @override
  Future<Meal?> byId(String id) async => records.firstWhere((m) => m.id == id);
  @override
  Future<List<String>> recentPlaces() async => [];
  @override
  Future<List<String>> recentPeople() async => [];
}

Future<void> _open(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  Widget home = const AppShell(),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [mealRepositoryProvider.overrideWithValue(_MemoryMeals())],
      child: MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('ko', 'KR'),
        supportedLocales: const [Locale('ko', 'KR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('preview isolates meals and editor from the device database', (
    tester,
  ) async {
    await _open(tester, home: const UiPreview());
    expect(find.text('기억하고 싶은 한 끼'), findsOneWidget);
    expect(find.text('기록을 불러오지 못했습니다.'), findsNothing);
    await tester.tap(find.byTooltip('새 식사 기록'));
    await tester.pumpAndSettle();
    expect(find.text('오늘의 한 끼'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('home filters records and search action switches tabs', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('점심 · 점심식당'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '저녁'));
    await tester.pumpAndSettle();
    expect(find.text('점심 · 점심식당'), findsNothing);
    expect(find.text('저녁 · 우리집'), findsOneWidget);
    await tester.tap(find.byTooltip('기록 검색'));
    await tester.pumpAndSettle();
    expect(find.text('어떤 한 끼를 찾고 있나요?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search applies filters, edits conditions and resets selection', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('검색').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '점심식당');
    await tester.ensureVisible(find.widgetWithText(FilledButton, '검색하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '검색하기'));
    await tester.pumpAndSettle();
    expect(find.text('총 1개의 기록'), findsOneWidget);
    expect(find.text('점심 · 점심식당'), findsOneWidget);
    expect(find.text('저녁 · 우리집'), findsNothing);
    await tester.tap(find.text('조건 수정'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '점심식당'), findsOneWidget);
    await tester.tap(find.text('초기화'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '점심식당'), findsNothing);
    await tester.ensureVisible(find.widgetWithText(FilledButton, '검색하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '검색하기'));
    await tester.pumpAndSettle();
    expect(find.text('총 2개의 기록'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact screen and large text keep calendar, search and editor usable',
    (tester) async {
      await _open(tester, size: const Size(360, 640), scale: 1.3);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('캘린더').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('검색').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '우리집');
      await tester.ensureVisible(find.widgetWithText(FilledButton, '검색하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '검색하기'));
      await tester.pumpAndSettle();
      expect(find.text('총 1개의 기록'), findsOneWidget);
      await tester.tap(find.byTooltip('새 식사 기록'));
      await tester.pumpAndSettle();
      expect(find.text('오늘의 한 끼'), findsOneWidget);
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
