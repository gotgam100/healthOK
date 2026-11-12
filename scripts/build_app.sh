#!/bin/zsh
# 앱을 빌드해서 dist/ 폴더에 .app 과 가족 공유용 .zip 을 만든다.
# 사용: ./scripts/build_app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

export SDKROOT=macosx

xcodegen generate --quiet
xcodebuild -project HealthCheckup.xcodeproj -scheme HealthCheckup -configuration Release \
  -derivedDataPath build -destination 'generic/platform=macOS' build -quiet

mkdir -p dist
APP="건강하면됐지.app"
rm -rf dist/HealthCheckup.app dist/HealthCheckup.zip "dist/$APP"
cp -R "build/Build/Products/Release/$APP" dist/
# zip 안에는 앱과 설치 방법 안내를 함께 넣음
PKG=dist/.pkg/건강하면됐지
rm -rf dist/.pkg && mkdir -p "$PKG"
cp -R "dist/$APP" "$PKG/"
cp "scripts/dist_files/설치 방법.txt" "$PKG/"
(cd dist/.pkg && rm -f ../건강하면됐지.zip && ditto -c -k --norsrc --noextattr --keepParent 건강하면됐지 ../건강하면됐지.zip)
rm -rf dist/.pkg

echo "완료: dist/$APP, dist/건강하면됐지.zip"
