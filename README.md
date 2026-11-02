## 잘쓸결심(돈을 잘 쓰다 + 지출내역을 잘 쓰다)
- 버는 것보다 쓰는 게 중요하다!
- 아껴쓰자!
- 쓰면 바로 적자!


"이번 달 돈을 얼마나 썼지?"
"왜 이렇게 돈을 많이 썼지?! 도대체 어디에 쓴거야?"
"내가 이번 달에 식비에 이렇게 많은 돈을 썼다고? 자세한 내용을 확인해봐야겠다"

"내가 돈을 가장 많이 쓰는 게 어떤 부분일까?"
"나의 소비 패턴은 어떻지?"
"이번 달은 평소보다 아껴쓴 것 같은데 맞나?"


이런 질문들을 객관적인 데이터로 확인하고 불필요한 지출을 줄여 돈을 더 잘 쓰기 위한 '잘쓸결심'

## Android 빌드 리소스 복구

Windows에서는 한글 상위 경로로 인한 셰이더 컴파일 오류를 피하도록 다음 스크립트로 실행한다. 사용 가능한 `V:`~`Z:` 드라이브 중 프로젝트 부모 폴더를 연결하고 `V:\well-spent-log` 같은 영문 경로에서 Flutter를 실행한다. 기존의 다른 드라이브 연결은 덮어쓰지 않으며, 같은 경로의 연결은 재사용하고 실행 후에도 유지한다.

```powershell
.\scripts\android.ps1 -BuildOnly
.\scripts\android.ps1 -Device R3CX209KK7Y
```

`compileFlutterBuildDebug`에서 `Cannot invoke "java.io.File.exists()" because "parent" is null`이 발생하면 이전 빌드에서 사용한 SUBST 드라이브가 해제되었는지 확인한다. Flutter 의존성 파일에는 절대 경로가 남는다. Android 빌드는 현재 없는 드라이브 참조를 감지하면 해당 변형의 Flutter 중간 산출물과 `.dart_tool/flutter_build` 캐시를 자동으로 정리한 뒤 재생성한다. 프로젝트 내부의 생성 캐시만 대상으로 하며 앱의 지출 기록·설정에는 영향을 주지 않는다.

아이콘이 한자로 표시되거나 실행 화면에서 멈춘다면 APK의 글꼴과 셰이더가 누락됐는지 확인한다. Android 빌드는 필수 리소스가 빠지면 오류로 중단하도록 검사한다.

`Flutter asset bundle is incomplete` 오류가 나오면 실행 중인 Flutter 명령을 종료하고 프로젝트 루트(`pubspec.yaml`이 있는 폴더)에서 다음 명령을 실행한다. `.dart_tool/flutter_build`는 생성된 빌드 캐시이며 휴대전화의 지출 데이터와는 무관하다.

```powershell
Remove-Item -LiteralPath .dart_tool\flutter_build -Recurse -Force
flutter run -d R3CX209KK7Y
```

한글 경로를 피하기 위해 `W:` 같은 SUBST 드라이브를 사용한다면 해당 드라이브로 이동한 상태에서 실행한다.
