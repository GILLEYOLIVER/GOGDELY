#!/usr/bin/env bash
set -euo pipefail

# Homologation previews only. This builds fictional, standalone Flutter data;
# it does not connect a browser to the local SQLite pilot or to Supabase.
flutter_dir="${RENDER_CACHE_DIR:-/tmp}/gogdely-flutter-3.47.0"
flutter_sha=4cf24164269a5ebf0c16a028a00727d0e77bbb05

if [[ ! -d "$flutter_dir/.git" ]]; then
  git clone --depth 1 --branch 3.47.0 https://github.com/flutter/flutter.git "$flutter_dir"
fi
actual_sha="$(git -C "$flutter_dir" rev-parse HEAD)"
if [[ "$actual_sha" != "$flutter_sha" ]]; then
  echo "Unexpected Flutter SDK commit: $actual_sha" >&2
  exit 1
fi
export PATH="$flutter_dir/bin:$PATH"
flutter config --enable-web

for app in cliente gestao entregador; do
  (
    cd "apps/$app"
    flutter pub get
    flutter build web --release --no-wasm-dry-run --base-href "/$app/"
  )
done

python3 scripts/stamp_pwa_version.py "$(git rev-parse HEAD)"
python3 scripts/prepare_hosted_pwas.py
