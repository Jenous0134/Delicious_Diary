# Kakao Android 설정

## 네이티브 앱 키

1. `android/kakao.example.properties`를 `android/kakao.local.properties`로 복사합니다.
2. 아래 항목의 `=` 뒤에 카카오 개발자 콘솔의 **네이티브 앱 키**를 따옴표 없이 붙여 넣습니다.

```properties
KAKAO_NATIVE_APP_KEY=여기에_네이티브_앱_키
```

`android/kakao.local.properties`는 Git에서 제외됩니다. 키를 README, 소스 코드, 이슈 또는 커밋에 직접 기록하지 마세요.

현재 지도 화면은 `flutter_map`과 OpenStreetMap 타일을 사용하며, 카카오 REST API는 장소 검색에 사용합니다. 네이티브 앱 키 파일은 향후 KakaoMaps Android SDK 전환을 위한 자리입니다.

## Android 플랫폼 등록

카카오 개발자 콘솔에서 다음 값을 등록합니다.

- 패키지명: `com.example.hankki_diary`
- 디버그 키 해시: `Z1KFwz+5fMInW4jXmDGicVgg2ys=`

현재 개인용 release APK도 임시로 debug 서명을 사용하므로 키 해시가 같습니다. 나중에 별도의 release keystore를 만들면 release 인증서로 키 해시를 다시 계산해 추가해야 합니다.

카카오 개발자 콘솔 경로:

`내 애플리케이션 > Delicious_Diary > 앱 > 플랫폼 키 > Android 플랫폼 등록`

## 키 해시 다시 계산하기

Windows PowerShell에서 디버그 인증서의 키 해시를 계산하는 방식은 다음과 같습니다.

```powershell
keytool -exportcert -alias androiddebugkey `
  -keystore "$env:USERPROFILE\.android\debug.keystore" `
  -storepass android -file debug-cert.der

$bytes = [System.IO.File]::ReadAllBytes("debug-cert.der")
$sha1 = [System.Security.Cryptography.SHA1]::Create()
[Convert]::ToBase64String($sha1.ComputeHash($bytes))
Remove-Item debug-cert.der
```

서명키가 변경되면 이 값을 다시 계산하여 카카오 개발자 콘솔에 추가해야 합니다.
