# 한끼일기

사진을 중심으로 식사를 기록하고 다시 찾아보는 개인용 Android Flutter 앱입니다. 서버, 로그인, 광고, 분석 SDK 및 클라우드 동기화를 사용하지 않습니다.

## 구현 기능

- SQLite 관계형 스키마와 앱 전용 저장소 원본 사진 복사
- 카메라 촬영 및 갤러리 다중 선택, Android 선택 데이터 유실 복구
- 사진 삭제·드래그 재정렬·첫 사진 대표 지정
- 목록·캘린더용 별도 썸네일과 상세 원본 확대/스와이프
- 날짜·시각, 식사 구분, 장소, 복수 메뉴별 가격, 복수 동행인, 메모
- 홈 최신순 목록, 상세, 수정, 삭제, 빈 화면 및 오류 상태
- 월간 캘린더, 날짜별 대표 썸네일과 복수 기록
- 날짜 범위·장소·메뉴·동행인·식사 구분 AND 검색
- 과거 장소와 동행인 오프라인 추천
- Kakao 키워드 장소 검색, 주소·좌표 스냅샷, 정적 지도 선택 확인
- API 키 미설정/오프라인 상태에서도 장소 직접 입력 가능
- 원본 사진과 JSON, manifest, SHA-256을 포함한 ZIP v1 백업
- ZIP Slip·심볼릭 링크·크기·항목 수·체크섬·참조 무결성 검증 후 전체 대체 복원
- 복원 실패 시 기존 DB와 사진 롤백
- 제공된 로고를 시작 화면과 Android 일반/적응형 아이콘에 적용

## 실행 및 검증

```shell
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --debug
```

Kakao 장소 검색을 포함해 실행하려면 예시 파일을 Git에서 제외되는 로컬 파일로 복사한 뒤 키를 입력합니다.

```powershell
Copy-Item config/kakao.example.json config/kakao.local.json
# config/kakao.local.json의 값을 실제 REST API 키로 교체
flutter run --dart-define-from-file=config/kakao.local.json
```

APK 빌드에도 같은 파일을 지정합니다.

```powershell
flutter build apk --debug --dart-define-from-file=config/kakao.local.json
```

`config/kakao.local.json`은 `.gitignore`에 등록되어 있습니다. 실제 키를 소스 코드, README, 이슈 또는 커밋에 넣지 마세요. 키가 없으면 검색 화면에 설정 필요 상태가 표시되며 장소 직접 입력은 정상 동작합니다. 모바일 앱에 포함된 키는 완전한 비밀이 될 수 없으므로 Kakao 개발자 콘솔에서 플랫폼 및 사용량 제한도 설정해야 합니다.

## 임시 설정

- Android applicationId: `com.example.hankki_diary`
- 실제 배포 전에 applicationId와 Kakao 개발자 콘솔의 Android 플랫폼 정보를 함께 변경해야 합니다.

## 데이터 보관

원본 사본은 앱 문서 저장소 `photos/original/`, 표시용 썸네일은 `photos/thumbnails/`에 저장됩니다. 앱 삭제 시 내부 데이터가 삭제될 수 있으므로 ZIP 백업을 외부 위치에 저장해야 합니다.

## 아직 외부 확인이 필요한 항목

- Kakao REST API 키로 실제 장소 검색/정적 지도 인증 확인
- Android 실기기에서 카메라, 시스템 사진 선택기, 공유/저장 창, ZIP 파일 선택 확인
- 배포용 applicationId 및 서명 확정
