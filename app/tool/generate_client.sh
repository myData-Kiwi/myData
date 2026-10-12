#!/usr/bin/env bash
# Regenerate packages/mydata_client from host/openapi.json with OpenAPI Generator (dart, package:http).
# The client is generated, never hand-written. Run after changing the host API:
#   (cd host && uv run mydata openapi --out openapi.json) && app/tool/generate_client.sh
set -euo pipefail
VERSION=7.26.0
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$(dirname "$HERE")"
SPEC="$(dirname "$APP")/host/openapi.json"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/mydata"
JAR="$CACHE/openapi-generator-cli-$VERSION.jar"
mkdir -p "$CACHE"
if [ ! -f "$JAR" ]; then
  curl -fsSL -o "$JAR.part" "https://repo1.maven.org/maven2/org/openapitools/openapi-generator-cli/$VERSION/openapi-generator-cli-$VERSION.jar"
  mv "$JAR.part" "$JAR"
fi
OUT="$APP/packages/mydata_client"
# Everything except the files listed in .openapi-generator-ignore is regenerated from scratch.
find "$OUT" -mindepth 1 -maxdepth 1 ! -name pubspec.yaml ! -name .openapi-generator-ignore ! -name analysis_options.yaml -exec rm -rf {} +
java -jar "$JAR" generate -i "$SPEC" -g dart -o "$OUT" \
  --additional-properties=pubName=mydata_client,pubDescription="myData host API client (generated)" \
  --skip-validate-spec >/dev/null
rm -rf "$OUT/test" "$OUT/.travis.yml" "$OUT/git_push.sh"
(cd "$APP" && dart format packages/mydata_client >/dev/null)
echo "Generated $OUT from $SPEC"
