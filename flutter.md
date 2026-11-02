# Windows에서 Android 실행하기

매번 아래 두 명령만 실행한다. 프로젝트 폴더를 열어둔 터미널이라면 첫 번째 명령은 생략할 수 있다.

```powershell
Set-Location "C:\Users\yjlee\OneDrive\바탕 화면\a\project\private\well-spent-log"
.\scripts\android.ps1 -Device R3CX209KK7Y
```

스크립트가 프로젝트 부모 폴더를 사용 가능한 `V:`~`Z:` 드라이브에 연결하고 `V:\well-spent-log` 같은 영문 경로에서 Flutter를 실행한다. 같은 연결이 있으면 재사용하며 다른 용도의 연결은 덮어쓰지 않는다. 연결은 실행 후에도 유지하고, 재부팅 등으로 없어지면 다음 실행 때 다시 만든다.

기존의 `subst W:` → `Set-Location W:\` → `flutter run` 순서 자체는 잘못된 것이 아니다. 다만 기존 캐시에 기록된 드라이브가 없어지거나 다른 빌드 경로와 섞이면 문제가 생길 수 있으므로 앞으로는 스크립트로 실행 경로를 통일한다. `subst` 명령을 따로 실행하거나 드라이브 연결을 수동으로 해제할 필요는 없다.

## APK 파일만 빌드하기

프로젝트 루트에서 실행한다.

```powershell
.\scripts\android.ps1 -BuildOnly
```

생성 위치: `build\app\outputs\flutter-apk\app-debug.apk`.
