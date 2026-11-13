#!/bin/zsh
# 새 버전 배포: 빌드·서명·공증 → 업데이트 서명 → appcast.xml → GitHub Release
# 사용: ./scripts/release.sh            (release-notes/<버전>.md 가 있어야 함)
#       DRY_RUN=1 ./scripts/release.sh  (올리지 않고 dist/ 에 파일만 만듦)
set -euo pipefail
cd "$(dirname "$0")/.."

REPO=gotgam100/healthOK
VERSION=$(awk -F'"' '/MARKETING_VERSION/{print $2}' project.yml)
BUILD=$(awk -F'"' '/CURRENT_PROJECT_VERSION/{print $2}' project.yml)
NOTES="release-notes/$VERSION.md"
TAG="v$VERSION"

[[ -f "$NOTES" ]] || { echo "릴리스 노트가 없습니다: $NOTES"; exit 1; }
if [[ "${DRY_RUN:-0}" != "1" ]] && gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "$TAG 은 이미 올라가 있습니다. project.yml 의 버전을 올려 주세요."; exit 1
fi
echo "== $VERSION (빌드 $BUILD) 배포 준비"

./scripts/build_app.sh

# 업데이트 서명 (열쇠는 이 맥 키체인의 'healthok' 계정에 있음)
SIGN_UPDATE=build.noindex/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update
ATTRS=$("$SIGN_UPDATE" --account healthok dist/HealthOK.dmg)

# appcast.xml: 앱이 확인하는 최신 버전 정보
python3 - "$VERSION" "$BUILD" "$TAG" "$NOTES" "$ATTRS" > dist/appcast.xml <<'PY'
import sys, html, email.utils
version, build, tag, notes_path, attrs = sys.argv[1:]
lines = open(notes_path, encoding="utf-8").read().strip().splitlines()
out, in_list = [], False
for l in lines:
    if l.startswith("- "):
        if not in_list: out.append("<ul>"); in_list = True
        out.append(f"<li>{html.escape(l[2:])}</li>")
    else:
        if in_list: out.append("</ul>"); in_list = False
        if l.strip(): out.append(f"<p>{html.escape(l.lstrip('# '))}</p>")
if in_list: out.append("</ul>")
url = f"https://github.com/gotgam100/healthOK/releases/download/{tag}/HealthOK.dmg"
print(f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>건강하면됐지</title>
    <item>
      <title>{version}</title>
      <pubDate>{email.utils.formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{build}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <description><![CDATA[{"".join(out)}]]></description>
      <enclosure url="{url}" type="application/octet-stream" {attrs} />
    </item>
  </channel>
</rss>""")
PY
echo "appcast.xml 을 만들었습니다"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "DRY_RUN: 올리지 않습니다 (dist/HealthOK.dmg, dist/appcast.xml)"; exit 0
fi

BODY=$(mktemp)
{ cat "$NOTES"; echo; echo "받는 법: 아래 Assets의 HealthOK.dmg를 내려받아 열고, 앱을 '응용 프로그램' 폴더로 끌어 놓으세요. 이미 설치했다면 앱이 새 버전을 알려 주고 앱 안에서 설치합니다."; } > "$BODY"
gh release create "$TAG" dist/HealthOK.dmg dist/appcast.xml --repo "$REPO" --title "건강하면됐지 $VERSION" --notes-file "$BODY"
rm -f "$BODY"
echo "== 올렸습니다: https://github.com/$REPO/releases/tag/$TAG"
