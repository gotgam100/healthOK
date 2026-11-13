# 건강하면됐지 배포 안내

새 버전을 만들어 GitHub에 올리고, 이미 설치한 사람의 앱이 **앱 안에서 업데이트**되게 하는 방법입니다.

## 어떻게 돌아가나

- **서명**: Developer ID 인증서로 "이 개발자가 만든 앱"이라는 표시를 합니다.
- **공증**: Apple이 앱을 검사하고 확인 도장을 찍습니다. 받는 사람이 경고 없이 열 수 있습니다.
- **업데이트 서명**: 업데이트 파일(DMG)에 이 맥에만 있는 열쇠로 한 번 더 서명합니다. 앱은 이 서명이 맞는 파일만 설치합니다.
- **appcast.xml**: 최신 버전 정보 파일입니다. Release에 DMG와 함께 올리면, 앱이 `releases/latest/download/appcast.xml`을 보고 새 버전을 알아챕니다.

## 처음 한 번만 준비 (이 맥은 이미 끝남)

1. **Developer ID 인증서**: 키체인에 `Developer ID Application: … (SB2Z6HL579)`가 있어야 합니다.
   ```bash
   security find-identity -v -p codesigning
   ```
2. **공증 정보**: 키체인 프로필 `healthok`.
   ```bash
   xcrun notarytool store-credentials healthok --apple-id "Apple ID 이메일" --team-id SB2Z6HL579
   ```
   암호는 [account.apple.com](https://account.apple.com) › 앱 암호에서 만든 것을 넣습니다.
3. **업데이트 서명 열쇠**: 키체인 계정 `healthok`에 들어 있습니다. 공개 열쇠는 `HealthCheckup/Info.plist`의 `SUPublicEDKey`입니다.
   ```bash
   build.noindex/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys --account healthok -p   # 공개 열쇠 보기
   ```

### 꼭 백업할 것

이 둘을 잃으면 이미 배포한 앱에 더 이상 업데이트를 보낼 수 없거나, 인증서를 새로 만들어야 합니다.

- **업데이트 서명 열쇠**
  ```bash
  build.noindex/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys --account healthok -x ~/Desktop/healthok-sparkle-key.txt
  ```
  만든 파일을 비밀번호 관리자나 외장 디스크에 보관하고, 바탕화면에서는 지웁니다.
- **Developer ID 인증서**: 키체인 접근 › 로그인 › 내 인증서 › `Developer ID Application …` 우클릭 › 내보내기(.p12, 암호 설정)

## 새 버전 올리기

1. `project.yml`에서 버전을 올립니다. **둘 다** 올려야 앱이 새 버전으로 알아봅니다.
   - `MARKETING_VERSION`: 보이는 버전 (예: `0.3.0` → `0.3.1`)
   - `CURRENT_PROJECT_VERSION`: 빌드 번호, 1씩 올림 (예: `6` → `7`)
2. `release-notes/<버전>.md`에 바뀐 점을 적습니다. `- `로 시작하는 줄은 목록이 됩니다. 이 내용이 앱의 업데이트 창과 GitHub Release에 나옵니다.
3. 변경 내용을 커밋하고 푸시한 뒤 실행합니다.
   ```bash
   ./scripts/release.sh
   ```
   빌드 → 서명 → 공증(앱·DMG) → 업데이트 서명 → `appcast.xml` → GitHub Release(`HealthOK.dmg`, `appcast.xml`)까지 한 번에 합니다. 공증 때문에 몇 분 걸립니다.

올리지 않고 파일만 만들어 보려면 `DRY_RUN=1 ./scripts/release.sh`, 공증까지 건너뛰려면 `SKIP_NOTARIZE=1`을 앞에 붙입니다.

## 업데이트 시험하기 (올리기 전, 내 맥에서만)

1. 지금 버전으로 `SKIP_NOTARIZE=1 ./scripts/build_app.sh` 후 `build.noindex/package/건강하면됐지.app`을 임시 폴더에 복사 (옛 버전)
2. 버전·빌드 번호를 올리고 `DRY_RUN=1 SKIP_NOTARIZE=1 ./scripts/release.sh` (새 버전 DMG·appcast)
3. `dist/appcast.xml`의 DMG 주소를 `http://localhost:8765/HealthOK.dmg`로 바꿔 DMG와 함께 한 폴더에 두고 `python3 -m http.server 8765`
4. 옛 버전을 `HEALTHCHECKUP_FEED_URL=http://localhost:8765/appcast.xml HEALTHCHECKUP_CHECK_UPDATE_NOW=1 HEALTHCHECKUP_STORE=/tmp/시험.json`으로 실행 → 업데이트 창에서 **설치**
5. 시험 뒤 `defaults delete local.healthcheckup.app SULastCheckTime` 등 `SU`로 시작하는 값을 지워 둡니다.
