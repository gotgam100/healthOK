# 개발 안내

## 실행

```bash
xcodegen generate          # HealthCheckup.xcodeproj 생성
open HealthCheckup.xcodeproj   # Xcode에서 ⌘R
```

## 가족에게 나눠 줄 앱 만들기

```bash
./scripts/build_app.sh     # dist/HealthOK.dmg 생성
```

Developer ID 인증서가 있으면 서명하고, 키체인에 공증 정보(`healthok`)가 있으면 Apple 공증까지 받습니다. 없으면 ad-hoc 서명으로 만듭니다.

## 판정 로직 테스트

```bash
cd Packages/HealthCore && SDKROOT=macosx swift test
```

## 구조

| 경로 | 내용 |
|------|------|
| `Packages/HealthCore` | 검사 항목 사전(`items.json`), 기준치 규칙(`rules.json`), 판정 엔진, 테스트 |
| `HealthCheckup/Models` | 기록 모델과 JSON 저장소(HealthStore), 이전 SwiftData 기록 옮기기(LegacyStore) |
| `HealthCheckup/Features` | 요약 / 검진 기록 표 / 입력 / 프로필 화면 |
| `scripts/build_app.sh` | 배포용 `.app` 빌드 |

데이터는 `~/Library/Application Support/HealthCheckup/health.json` 에만 저장됩니다 (직전 상태는 `health.json.bak`).
macOS 13 이상에서 돌도록 SwiftData 대신 JSON 파일을 씁니다. 저장 파일과 [파일 › 기록 내보내기] 파일의 형식이 같아서,
다른 맥에서는 [파일 › 기록 가져오기]로 그대로 옮길 수 있습니다. 예전 버전의 `health.store`가 있으면 처음 실행 때 한 번 옮겨오고 원본은 그대로 둡니다.

## 개발용 환경변수 (Debug 빌드)

| 변수 | 효과 |
|------|------|
| `HEALTHCHECKUP_STORE=/경로/test.json` | 다른 저장 파일 사용 (실제 데이터와 분리) |
| `HEALTHCHECKUP_SEED=1` | 비어 있으면 샘플 데이터 넣기 |
| `HEALTHCHECKUP_SECTION=summary\|trends\|records\|profile` | 시작 화면 |
| `HEALTHCHECKUP_PERSON=0` | 시작 구성원 번호 |
| `HEALTHCHECKUP_OPEN_EDITOR=1` | 최근 검진 편집 창 열기 |
| `HEALTHCHECKUP_EXPORT_MD=/경로/out.md` | 모든 구성원을 AI용 Markdown으로 저장 |
| `HEALTHCHECKUP_FAKE_VERSION=0.0.9` | 지금 버전을 이 값으로 여김 (업데이트 알림 시험) |
| `HEALTHCHECKUP_UPDATE_CHECK=1` | 켤 때 하루 한 번 제한 없이 업데이트 확인 |
| `HEALTHCHECKUP_DUMP_MENU=1` | 3초 뒤 메뉴바 구성을 표준 출력에 찍음 |
| `HEALTHCHECKUP_EDITOR_FOCUS=VITD` | 편집 창을 열면서 그 항목으로 이동 |
| `HEALTHCHECKUP_EDITOR_SEARCH=요` | 편집 창의 항목 검색어 미리 넣기 |
| `HEALTHCHECKUP_SECTION=trends` + `HEALTHCHECKUP_TREND=LDL` | 추이 화면에서 특정 항목 상세 열기 |
| `HEALTHCHECKUP_CHECKUP=2` | 요약에서 n번째 검진(오래된 순, 0부터) 선택 |
| `HEALTHCHECKUP_ORGAN=liver` | 요약에서 특정 부위 선택 |

## 새 버전 배포

1. `project.yml`의 `MARKETING_VERSION`을 올리고 `./scripts/build_app.sh`
2. `dist/HealthOK.dmg`를 `vX.Y.Z` Release에 올림
   (README의 내려받기 링크 `releases/latest/download/HealthOK.dmg`가 이 이름을 가리킴)
