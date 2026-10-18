import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/meals/data/meal_repository.dart';
import '../features/meals/domain/meal.dart';
import '../features/meals/presentation/meal_state.dart';
import '../features/shell/modern_app_shell.dart';

/// Real screens with an empty, isolated repository for desktop UI review.
class UiPreview extends StatelessWidget {
  const UiPreview({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFF3F4F6),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ProviderScope(
          overrides: [
            mealRepositoryProvider.overrideWithValue(_PreviewRepository()),
            mealsProvider.overrideWith((ref) async => _sampleMeals),
            filteredMealsProvider.overrideWith(
              (ref, filter) async => _PreviewRepository().find(filter),
            ),
          ],
          child: LayoutBuilder(
            builder: (context, constraints) => MediaQuery(
              data: MediaQuery.of(context).copyWith(size: constraints.biggest),
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => const Column(
                    children: [
                      Material(
                        color: Colors.white,
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
                                color: Color(0xFF737373),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(child: ModernAppShell()),
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
  Future<List<Meal>> find([MealFilter filter = const MealFilter()]) async {
    return _sampleMeals.where((meal) {
      if (filter.startDate != null &&
          meal.eatenDate.isBefore(filter.startDate!)) {
        return false;
      }
      if (filter.endDate != null &&
          meal.eatenDate.isAfter(
            filter.endDate!.add(const Duration(days: 1)),
          )) {
        return false;
      }
      if (filter.type != null && meal.type != filter.type) return false;
      if (filter.place?.isNotEmpty == true &&
          !meal.placeName.contains(filter.place!)) {
        return false;
      }
      if (filter.menu?.isNotEmpty == true &&
          !meal.items.any((e) => e.name.contains(filter.menu!))) {
        return false;
      }
      if (filter.person?.isNotEmpty == true &&
          !meal.people.any((e) => e.contains(filter.person!))) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<Meal?> byId(String id) async =>
      _sampleMeals.where((meal) => meal.id == id).firstOrNull;
  @override
  Future<List<String>> recentPlaces() async => [];
  @override
  Future<List<String>> recentPeople() async => [];
}

final _sampleMeals = <Meal>[
  _sampleMeal(
    id: 'preview-1',
    daysAgo: 0,
    type: MealType.dinner,
    place: '을지로 골목식당',
    address: '서울 중구 을지로 12길',
    menus: const ['삼겹살', '볶음밥'],
    people: const ['민지', '준호'],
    memo: '퇴근 후 천천히 구워 먹은 저녁. 김치가 특히 맛있었다.',
    latitude: 37.5662,
    longitude: 126.9910,
    photoCount: 3,
  ),
  _sampleMeal(
    id: 'preview-2',
    daysAgo: 2,
    type: MealType.lunch,
    place: '성수 분식',
    address: '서울 성동구 연무장길',
    menus: const ['떡볶이', '튀김'],
    people: const ['혼자'],
    memo: '맵고 달달한 소스. 다음에는 순대도 같이 먹기.',
    latitude: 37.5446,
    longitude: 127.0557,
    photoCount: 2,
  ),
  _sampleMeal(
    id: 'preview-3',
    daysAgo: 5,
    type: MealType.lateNight,
    place: '한강 라면',
    address: '서울 영등포구 여의동로',
    menus: const ['계란 라면'],
    people: const ['지수'],
    memo: '밤바람 맞으며 먹어서 더 맛있었던 라면.',
    latitude: 37.5285,
    longitude: 126.9349,
    photoCount: 1,
  ),
  _sampleMeal(
    id: 'preview-4',
    daysAgo: 8,
    type: MealType.snack,
    place: '오후의 카페',
    address: '서울 마포구 동교로',
    menus: const ['당근 케이크', '아이스 라떼'],
    people: const ['민지'],
    memo: '창가 자리가 좋았던 조용한 카페.',
    latitude: 37.5561,
    longitude: 126.9236,
    photoCount: 2,
  ),
];

Meal _sampleMeal({
  required String id,
  required int daysAgo,
  required MealType type,
  required String place,
  required String address,
  required List<String> menus,
  required List<String> people,
  required String memo,
  required double latitude,
  required double longitude,
  required int photoCount,
}) {
  final date = DateTime.now().subtract(Duration(days: daysAgo));
  return Meal(
    id: id,
    eatenDate: DateTime(date.year, date.month, date.day),
    eatenTime: type == MealType.dinner ? '19:20' : null,
    type: type,
    placeName: place,
    placeSource: 'preview',
    placeAddress: address,
    latitude: latitude,
    longitude: longitude,
    memo: memo,
    createdAt: date,
    updatedAt: date,
    items: menus.map((name) => MealItem(name: name)).toList(),
    people: people,
    photos: List.generate(
      photoCount,
      (index) => MealPhoto(
        id: '$id-photo-$index',
        relativePath: 'asset:assets/samples/food-quadrants.png',
        sortOrder: (daysAgo + index) % 4,
        isCover: index == 0,
      ),
    ),
  );
}
