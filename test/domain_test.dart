import 'package:flutter_test/flutter_test.dart';
import 'package:hankki_diary/features/meals/data/meal_repository.dart';
import 'package:hankki_diary/features/meals/domain/meal.dart';
import 'package:hankki_diary/features/places/data/place_search_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('검색 문자열은 한국어를 보존하고 공백만 정규화한다', () {
    expect(normalizeText('  을지로   맛집 '), '을지로 맛집');
    expect(normalizeText('ABC 식당'), 'abc 식당');
  });

  test('식사 구분 DB 값 왕복', () {
    for (final type in MealType.values) {
      expect(MealTypeText.fromDb(type.dbValue), type);
    }
  });

  test('Kakao 장소 검색 응답을 장소 스냅샷으로 변환한다', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'KakaoAK test-key');
      return http.Response(
        '''{"documents":[{"id":"42","place_name":"테스트 식당","road_address_name":"서울 중구 테스트로 1","address_name":"서울 중구","x":"126.9","y":"37.5"}]}''',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final result = await KakaoPlaceSearchService(
      apiKey: 'test-key',
      client: client,
    ).search('테스트');
    expect(result.single.name, '테스트 식당');
    expect(result.single.longitude, 126.9);
    expect(result.single.latitude, 37.5);
  });

  test('키가 없으면 외부 검색을 시도하지 않는다', () async {
    final service = KakaoPlaceSearchService(
      apiKey: '',
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    expect(service.isConfigured, isFalse);
    expect(() => service.search('식당'), throwsStateError);
  });

  test('카카오맵 서비스 비활성화 오류를 설정 안내로 변환한다', () async {
    final service = KakaoPlaceSearchService(
      apiKey: 'test-key',
      client: MockClient(
        (_) async => http.Response(
          '{"errorType":"NotAuthorizedError","message":"App(Delicious_Diary) disabled OPEN_MAP_AND_LOCAL service."}',
          403,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    expect(
      () => service.search('식당'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('카카오맵 > 사용 설정 > 상태'),
        ),
      ),
    );
  });
}
