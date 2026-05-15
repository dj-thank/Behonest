#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${1:-../be_honest_app}"
STARTER_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter CLIが見つかりません。先にFlutterをインストールしてください。" >&2
  exit 1
fi

flutter create --org app.behonest --project-name be_honest "$APP_DIR"

rm -f "$APP_DIR/test/widget_test.dart"

rsync -a "$STARTER_DIR/lib/" "$APP_DIR/lib/"
rsync -a "$STARTER_DIR/assets/" "$APP_DIR/assets/"
rsync -a "$STARTER_DIR/functions/" "$APP_DIR/functions/"
cp "$STARTER_DIR/pubspec.yaml" "$APP_DIR/pubspec.yaml"
cp "$STARTER_DIR/analysis_options.yaml" "$APP_DIR/analysis_options.yaml"
cp "$STARTER_DIR/firebase.json" "$APP_DIR/firebase.json"
cp "$STARTER_DIR/firestore.rules" "$APP_DIR/firestore.rules"
cp "$STARTER_DIR/storage.rules" "$APP_DIR/storage.rules"
cp "$STARTER_DIR/firestore.indexes.json" "$APP_DIR/firestore.indexes.json"
cp "$STARTER_DIR/README.md" "$APP_DIR/README.md"
cp "$STARTER_DIR/APP_SPEC.md" "$APP_DIR/APP_SPEC.md"
cp "$STARTER_DIR/CHANGELOG.md" "$APP_DIR/CHANGELOG.md"
mkdir -p "$APP_DIR/native" "$APP_DIR/docs"
rsync -a "$STARTER_DIR/native/" "$APP_DIR/native/"
rsync -a "$STARTER_DIR/docs/" "$APP_DIR/docs/"

cat <<MSG

作成しました: $APP_DIR

次に実行:
  cd $APP_DIR
  flutter pub get
  dart pub global activate flutterfire_cli
  flutterfire configure
  flutter run

Android/iOSの権限と通知音は native/ のREADMEを見て手動反映してください。
MSG
