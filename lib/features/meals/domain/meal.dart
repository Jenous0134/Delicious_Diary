enum MealType { breakfast, lunch, dinner, snack, lateNight, other }

extension MealTypeText on MealType {
  String get dbValue => const [
    'breakfast',
    'lunch',
    'dinner',
    'snack',
    'late_night',
    'other',
  ][index];
  String get label => const ['아침', '점심', '저녁', '간식', '야식', '기타'][index];
  static MealType fromDb(String value) => MealType.values.firstWhere(
    (e) => e.dbValue == value,
    orElse: () => MealType.other,
  );
}

class MealItem {
  const MealItem({required this.name, this.priceWon});
  final String name;
  final int? priceWon;
}

class MealPhoto {
  const MealPhoto({
    required this.id,
    required this.relativePath,
    required this.sortOrder,
    required this.isCover,
    this.thumbnailRelativePath,
  });
  final String id;
  final String relativePath;
  final String? thumbnailRelativePath;
  final int sortOrder;
  final bool isCover;
}

class Meal {
  const Meal({
    required this.id,
    required this.eatenDate,
    required this.type,
    required this.placeName,
    required this.placeSource,
    required this.createdAt,
    required this.updatedAt,
    this.eatenTime,
    this.placeAddress,
    this.latitude,
    this.longitude,
    this.memo,
    this.photos = const [],
    this.items = const [],
    this.people = const [],
  });
  final String id;
  final DateTime eatenDate;
  final String? eatenTime;
  final MealType type;
  final String placeName;
  final String placeSource;
  final String? placeAddress;
  final double? latitude;
  final double? longitude;
  final String? memo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<MealPhoto> photos;
  final List<MealItem> items;
  final List<String> people;
}

class MealDraft {
  const MealDraft({
    required this.eatenDate,
    required this.type,
    required this.placeName,
    required this.photoPaths,
    this.id,
    this.eatenTime,
    this.memo,
    this.items = const [],
    this.people = const [],
    this.existingPhotos = const [],
    this.orderedPhotoKeys = const [],
    this.placeSource = 'manual',
    this.placeProvider,
    this.placeProviderId,
    this.placeAddress,
    this.latitude,
    this.longitude,
  });
  final String? id;
  final DateTime eatenDate;
  final String? eatenTime;
  final MealType type;
  final String placeName;
  final String? memo;
  final List<String> photoPaths;
  final List<MealPhoto> existingPhotos;
  final List<String> orderedPhotoKeys;
  final String placeSource;
  final String? placeProvider;
  final String? placeProviderId;
  final String? placeAddress;
  final double? latitude;
  final double? longitude;
  final List<MealItem> items;
  final List<String> people;
}

class MealFilter {
  const MealFilter({
    this.startDate,
    this.endDate,
    this.place,
    this.menu,
    this.person,
    this.type,
  });
  final DateTime? startDate;
  final DateTime? endDate;
  final String? place;
  final String? menu;
  final String? person;
  final MealType? type;
}
