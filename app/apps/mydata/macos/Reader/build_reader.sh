#!/bin/bash
# Builds myDataReader.app and puts it inside the myData app, signed, before Xcode signs the myData app.
#
# Run by the Runner target's "Embed myData Reader" build phase, after Flutter's own phases. It can also be
# run by hand with the destination as its one argument:
#   macos/Reader/build_reader.sh /tmp/try/myDataReader.app
#
# Signing follows the myData app: the same identity (EXPANDED_CODE_SIGN_IDENTITY; ad hoc "-" when it is
# empty), so a development certificate set in Runner/Configs/Signing.local.xcconfig signs both. With the
# hardened runtime on (ENABLE_HARDENED_RUNTIME=YES, needed for notarisation) the helper is signed with it
# and with Reader.entitlements, without which the hardened runtime blocks Contacts and Calendars.
#
# The compiled, signed helper is cached in the target's temporary folder under a stamp of everything that
# goes into it (sources, plist, entitlements, this script, identity, architectures, compiler). Xcode runs
# this phase on every build; it compiles only when the stamp changes, and otherwise copies the cached app.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME=myDataReader
MIN_MACOS=14.0

if [[ $# -ge 1 ]]; then
  OUT="$1"
else
  : "${TARGET_BUILD_DIR:?run from Xcode, or pass the destination .app}"
  : "${WRAPPER_NAME:?run from Xcode, or pass the destination .app}"
  OUT="$TARGET_BUILD_DIR/$WRAPPER_NAME/Contents/Helpers/$NAME.app"
fi

IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-}"
[[ -n "$IDENTITY" ]] || IDENTITY="-"
HARDENED="${ENABLE_HARDENED_RUNTIME:-NO}"
ARCH_LIST="${ARCHS:-$(uname -m)}"
WORK="${TARGET_TEMP_DIR:-${TMPDIR:-/tmp}/mydata-reader-build}/$NAME"
CACHED="$WORK/$NAME.app"
SOURCES=("$HERE"/Sources/*.swift)

stamp="$(
  {
    printf '%s\n' "$IDENTITY" "$HARDENED" "$ARCH_LIST" "$MIN_MACOS" "${OTHER_CODE_SIGN_FLAGS:-}"
    xcrun --sdk macosx swiftc --version 2>&1 | head -n 1
    for f in "$HERE/build_reader.sh" "$HERE/Info.plist" "$HERE/Reader.entitlements" "${SOURCES[@]}"; do
      printf '%s\n' "$(basename "$f")"
      cat "$f"
    done
  } | shasum -a 256 | cut -d ' ' -f 1
)"

if [[ -d "$CACHED" && -f "$WORK/stamp" && "$(cat "$WORK/stamp")" == "$stamp" ]]; then
  echo "myDataReader: unchanged, using the cached build"
else
  echo "myDataReader: building for $ARCH_LIST, signing with ${IDENTITY}"
  rm -rf "$WORK"
  mkdir -p "$WORK"
  SDK="$(xcrun --sdk macosx --show-sdk-path)"
  binaries=()
  for arch in $ARCH_LIST; do
    # The app's own deployment target (older) must not leak into the helper's link.
    env -u MACOSX_DEPLOYMENT_TARGET xcrun --sdk macosx swiftc \
      -swift-version 5 -O -whole-module-optimization \
      -target "$arch-apple-macos$MIN_MACOS" -sdk "$SDK" \
      -framework Contacts -framework EventKit -framework AppKit \
      -module-name "$NAME" -o "$WORK/$NAME-$arch" "${SOURCES[@]}"
    binaries+=("$WORK/$NAME-$arch")
  done

  mkdir -p "$CACHED/Contents/MacOS"
  lipo -create "${binaries[@]}" -output "$CACHED/Contents/MacOS/$NAME"
  cp "$HERE/Info.plist" "$CACHED/Contents/Info.plist"
  printf 'APPL????' > "$CACHED/Contents/PkgInfo"

  sign=(--force --sign "$IDENTITY")
  if [[ "$HARDENED" == "YES" ]]; then
    sign+=(--options runtime --entitlements "$HERE/Reader.entitlements")
    [[ "$IDENTITY" == "-" ]] || sign+=(--timestamp)
  elif [[ "$IDENTITY" != "-" ]]; then
    sign+=(--timestamp=none)
  fi
  # shellcheck disable=SC2206  # Xcode's extra flags are space-separated on purpose
  [[ -z "${OTHER_CODE_SIGN_FLAGS:-}" ]] || sign+=(${OTHER_CODE_SIGN_FLAGS})
  codesign "${sign[@]}" "$CACHED"
  codesign --verify --strict "$CACHED"
  printf '%s\n' "$stamp" > "$WORK/stamp"
fi

rm -rf "$OUT"
mkdir -p "$(dirname "$OUT")"
ditto "$CACHED" "$OUT"
