#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

flutter build apk --release --split-per-abi "$@"

apk_dir="build/app/outputs/flutter-apk"
shopt -s nullglob
for apk in "$apk_dir"/app-*-release.apk "$apk_dir"/app-release.apk; do
  filename="${apk##*/}"
  if [[ "$filename" == "app-release.apk" ]]; then
    target="$apk_dir/workhub-mobile-release.apk"
  else
    abi="${filename#app-}"
    abi="${abi%-release.apk}"
    target="$apk_dir/workhub-mobile-${abi}-release.apk"
  fi
  mv -f -- "$apk" "$target"
  printf 'Created %s\n' "$target"
done
