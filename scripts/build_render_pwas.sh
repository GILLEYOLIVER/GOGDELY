#!/usr/bin/env bash
set -euo pipefail

# Homologation builds. Cliente and Gestão use the reviewed online API when
# configured; Entregador still has no online assignment flow.
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

for app in cliente gestao entregador master; do
  (
    cd "apps/$app"
    flutter pub get
    if [[ "$app" == "cliente" ]]; then
      flutter build web --release --no-wasm-dry-run --base-href "/$app/" \
        --dart-define="GOGDELY_HOSTED_PWA=true" \
        --dart-define="GOGDELY_API_BASE_URL=${GOGDELY_API_BASE_URL:-}"
    elif [[ "$app" == "gestao" && -n "${GOGDELY_API_BASE_URL:-}" ]]; then
      flutter build web --release --no-wasm-dry-run --base-href "/$app/" \
        --dart-define="GOGDELY_API_BASE_URL=$GOGDELY_API_BASE_URL"
    elif [[ "$app" == "master" ]]; then
      flutter build web --release --no-wasm-dry-run --base-href "/$app/" \
        --dart-define="GOGDELY_HOSTED_MASTER=true" \
        --dart-define="GOGDELY_API_BASE_URL=${GOGDELY_API_BASE_URL:-}"
    else
      flutter build web --release --no-wasm-dry-run --base-href "/$app/"
    fi
  )
done

python3 scripts/stamp_pwa_version.py "$(git rev-parse HEAD)"
python3 scripts/prepare_hosted_pwas.py
