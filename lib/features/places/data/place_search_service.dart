import 'dart:convert';
import 'package:http/http.dart' as http;

class PlaceResult {
  const PlaceResult({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
}

abstract interface class PlaceSearchService {
  bool get isConfigured;
  Future<List<PlaceResult>> search(String query);
}

class KakaoPlaceSearchService implements PlaceSearchService {
  KakaoPlaceSearchService({String? apiKey, http.Client? client})
    : apiKey = apiKey ?? const String.fromEnvironment('KAKAO_REST_API_KEY'),
      _client = client ?? http.Client();
  final String apiKey;
  final http.Client _client;
  @override
  bool get isConfigured => apiKey.trim().isNotEmpty;

  @override
  Future<List<PlaceResult>> search(String query) async {
    final clean = query.trim();
    if (!isConfigured) throw StateError('Kakao REST API 키가 설정되지 않았습니다.');
    if (clean.isEmpty) return const [];
    final uri = Uri.https('dapi.kakao.com', '/v2/local/search/keyword.json', {
      'query': clean,
      'size': '15',
    });
    final response = await _client
        .get(uri, headers: {'Authorization': 'KakaoAK $apiKey'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 401) {
      throw StateError('카카오 REST API 키가 올바르지 않습니다. REST API 키를 다시 확인해 주세요.');
    }
    if (response.statusCode == 403) {
      final message = _errorMessage(response);
      if (message.contains('disabled OPEN_MAP_AND_LOCAL service')) {
        throw StateError(
          '카카오맵 API가 비활성화되어 있습니다. 카카오 개발자 콘솔에서 '
          '[카카오맵 > 사용 설정 > 상태]를 ON으로 변경해 주세요.',
        );
      }
      throw StateError('카카오맵 API 사용 권한이 없습니다. 카카오 앱의 사용 설정을 확인해 주세요.');
    }
    if (response.statusCode == 429) {
      throw StateError('지도 검색 사용량을 초과했습니다. 잠시 후 다시 시도해 주세요.');
    }
    if (response.statusCode != 200) {
      throw StateError('장소 검색에 실패했습니다. (${response.statusCode})');
    }
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (body['documents'] as List).map((value) {
      final row = value as Map<String, dynamic>;
      return PlaceResult(
        id: row['id'] as String,
        name: row['place_name'] as String,
        address:
            ((row['road_address_name'] as String?)?.trim().isNotEmpty ?? false)
            ? row['road_address_name'] as String
            : row['address_name'] as String,
        latitude: double.parse(row['y'] as String),
        longitude: double.parse(row['x'] as String),
      );
    }).toList();
  }

  String _errorMessage(http.Response response) {
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is Map<String, dynamic>) {
        return value['message']?.toString() ?? value['msg']?.toString() ?? '';
      }
    } catch (_) {
      // Fall through to a generic error message for malformed responses.
    }
    return '';
  }
}
