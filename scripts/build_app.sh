#!/bin/zsh
# 앱을 빌드해서 dist/ 폴더에 .app 과 배포용 HealthOK.dmg 를 만든다.
# 사용: ./scripts/build_app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

export SDKROOT=macosx

xcodegen generate --quiet
xcodebuild -project HealthCheckup.xcodeproj -scheme HealthCheckup -configuration Release \
  -derivedDataPath build -destination 'generic/platform=macOS' build -quiet

mkdir -p dist
APP="건강하면됐지.app"
rm -rf dist/HealthCheckup.app dist/HealthCheckup.zip dist/건강하면됐지.zip "dist/$APP"
cp -R "build/Build/Products/Release/$APP" dist/

# Developer ID 인증서가 있으면 서명하고 Apple 공증까지 받음 (없으면 ad-hoc 서명 그대로)
# 공증 정보는 한 번만 저장: xcrun notarytool store-credentials healthok --apple-id <Apple ID> --team-id <팀 ID>
NOTARY_PROFILE=${NOTARY_PROFILE:-healthok}
DEV_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk '{print $2}' || true)
if [[ -n "$DEV_ID" ]]; then
  echo "Developer ID로 서명합니다"
  codesign --force --options runtime --timestamp --sign "$DEV_ID" "dist/$APP"
  codesign --verify --strict --verbose=1 "dist/$APP"
  if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "Apple 공증을 받는 중입니다 (몇 분 걸릴 수 있음)"
    rm -f dist/notarize.zip
    ditto -c -k --keepParent "dist/$APP" dist/notarize.zip
    xcrun notarytool submit dist/notarize.zip --keychain-profile "$NOTARY_PROFILE" --wait
    rm -f dist/notarize.zip
    xcrun stapler staple "dist/$APP"
    spctl --assess --type execute --verbose=2 "dist/$APP"
  else
    echo "주의: 공증 정보(키체인 프로필 '$NOTARY_PROFILE')가 없어 공증은 건너뜁니다"
  fi
else
  echo "주의: Developer ID 인증서가 없어 ad-hoc 서명으로 만듭니다 (다른 맥에서 처음 열 때 경고가 뜸)"
fi
# DMG: 열면 앱과 '응용 프로그램' 바로가기가 보여서 끌어 놓기만 하면 설치됨
DMG=dist/HealthOK.dmg
STAGE=dist/.dmg
rm -rf "$STAGE" "$DMG" && mkdir -p "$STAGE"
cp -R "dist/$APP" "$STAGE/"
ln -s /Applications "$STAGE/응용 프로그램"
cp "scripts/dist_files/설치 방법.txt" "$STAGE/"
hdiutil create -quiet -volname "건강하면됐지" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG"
rm -rf "$STAGE"
if [[ -n "$DEV_ID" ]]; then
  codesign --force --timestamp --sign "$DEV_ID" "$DMG"
  if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "DMG 공증을 받는 중입니다"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
  fi
fi

echo "완료: dist/$APP, $DMG"
