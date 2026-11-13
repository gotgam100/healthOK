#!/bin/zsh
# 앱을 빌드해서 배포용 dist/HealthOK.dmg 를 만든다 (Developer ID 서명·Apple 공증 포함).
# 사용: ./scripts/build_app.sh
#   SKIP_NOTARIZE=1 ./scripts/build_app.sh   # 공증 없이 서명만 (내 맥에서 시험할 때)
set -euo pipefail
cd "$(dirname "$0")/.."

export SDKROOT=macosx

xcodegen generate --quiet
xcodebuild -project HealthCheckup.xcodeproj -scheme HealthCheckup -configuration Release \
  -derivedDataPath build.noindex -destination 'generic/platform=macOS' build -quiet

# 서명·공증할 앱 사본은 Spotlight가 찾지 않는 폴더(.noindex)에 두고, dist/에는 DMG만 남김
APP="건강하면됐지.app"
WORK=build.noindex/package
mkdir -p dist
rm -rf "$WORK" "dist/$APP"
mkdir -p "$WORK"
cp -R "build.noindex/Build/Products/Release/$APP" "$WORK/"

# 공증 정보는 한 번만 저장: xcrun notarytool store-credentials healthok --apple-id <Apple ID> --team-id <팀 ID>
NOTARY_PROFILE=${NOTARY_PROFILE:-healthok}
DEV_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk '{print $2}' || true)
CAN_NOTARIZE=0
if [[ -n "$DEV_ID" && "${SKIP_NOTARIZE:-0}" != "1" ]] && xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  CAN_NOTARIZE=1
fi

notarize() {   # $1: 공증받을 파일 (zip 또는 dmg)
  xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait | grep -E "status:|id:" | tail -2
}

if [[ -n "$DEV_ID" ]]; then
  echo "Developer ID로 서명합니다"
  sign() { codesign --force --options runtime --timestamp --sign "$DEV_ID" "$@"; }
  # Sparkle 부품은 안쪽부터 차례로 서명 (Downloader는 원래 권한 설정 유지)
  FW="$WORK/$APP/Contents/Frameworks/Sparkle.framework"
  if [[ -d "$FW" ]]; then
    sign "$FW/Versions/B/XPCServices/Installer.xpc"
    sign --preserve-metadata=entitlements "$FW/Versions/B/XPCServices/Downloader.xpc"
    sign "$FW/Versions/B/Autoupdate"
    sign "$FW/Versions/B/Updater.app"
    sign "$FW"
  fi
  sign "$WORK/$APP"
  codesign --verify --deep --strict "$WORK/$APP"
  if [[ $CAN_NOTARIZE == 1 ]]; then
    echo "앱 공증을 받는 중입니다 (몇 분 걸릴 수 있음)"
    ditto -c -k --keepParent "$WORK/$APP" "$WORK/notarize.zip"
    notarize "$WORK/notarize.zip"
    rm -f "$WORK/notarize.zip"
    xcrun stapler staple -q "$WORK/$APP"
    spctl --assess --type execute --verbose=2 "$WORK/$APP"
  else
    echo "주의: 공증은 건너뜁니다 (SKIP_NOTARIZE이거나 공증 정보 '$NOTARY_PROFILE'이 없음)"
  fi
else
  echo "주의: Developer ID 인증서가 없어 ad-hoc 서명으로 만듭니다 (다른 맥에서 처음 열 때 경고가 뜸)"
fi

# DMG: 열면 앱과 '응용 프로그램' 바로가기가 보여서 끌어 놓기만 하면 설치됨
DMG=dist/HealthOK.dmg
STAGE=build.noindex/dmg
rm -rf "$STAGE" "$DMG" && mkdir -p "$STAGE"
cp -R "$WORK/$APP" "$STAGE/"
ln -s /Applications "$STAGE/응용 프로그램"
cp "scripts/dist_files/설치 방법.txt" "$STAGE/"
hdiutil create -quiet -volname "건강하면됐지" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG"
rm -rf "$STAGE"
if [[ -n "$DEV_ID" ]]; then
  codesign --force --timestamp --sign "$DEV_ID" "$DMG"
  if [[ $CAN_NOTARIZE == 1 ]]; then
    echo "DMG 공증을 받는 중입니다"
    notarize "$DMG"
    xcrun stapler staple -q "$DMG"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
  fi
fi

echo "완료: $DMG"
