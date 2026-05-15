# Be Honest: TermuxからGitHub ActionsでAPKを作る手順

Termux単体にFlutter SDKを入れてAndroid APKをビルドするのは不安定です。
このパッケージにはGitHub Actions用のワークフローを同梱しています。
スマホからGitHubへpushすると、GitHub上のLinux環境でFlutterをセットアップし、APKを生成します。

## 1. Termuxで必要パッケージを入れる

```bash
pkg update -y
pkg install git gh unzip -y
```

## 2. GitHubにログイン

```bash
gh auth login
```

選択の目安:

- GitHub.com
- HTTPS
- Login with a web browser

表示されたコードをブラウザで入力してログインします。

## 3. このフォルダをGitリポジトリ化してpush

```bash
cd ~/storage/downloads/be_honest_brushedup

git init
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git add .
git commit -m "Initial Be Honest MVP"

gh repo create be-honest --private --source=. --remote=origin --push
```

## 4. GitHub ActionsでAPKを取る

GitHubアプリまたはブラウザで以下を開きます。

- 作成した `be-honest` リポジトリ
- Actions
- Build Android Debug APK
- 最新の実行結果
- Artifacts
- `be-honest-debug-apk` をダウンロード

中に `app-debug.apk` が入っています。

## 5. Firebaseについて

このAPKはまず「ビルド確認用」です。
Firebase通知・Firestore・Storageを本番動作させるには、PCまたはCI上で `flutterfire configure` を通し、
`lib/firebase_options.dart` を本物のFirebase設定に置き換えてください。

## 6. よくあるエラー

### flutter: command not found

Termux内にFlutterがありません。GitHub Actionsでビルドしてください。

### flutterfire: command not found

FlutterFire CLIがありません。CIで本番Firebase設定まで行う場合は追加設定が必要です。
まずはdebug APKのビルドを通してください。

### Permission denied: scripts/create_flutter_project.sh

このワークフローでは `bash scripts/create_flutter_project.sh` として実行するため、実行権限がなくても大丈夫です。
