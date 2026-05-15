# Be Honest Starter v0.2

旅行中に友達だけで使う「Be Honest」MVPスターターです。

添付XAPKは**仕組みの参考**としてだけ確認しました。BeRealのコード・UI・ロゴ・文言・画像・音源はコピーしていません。

## v0.2でブラッシュアップしたこと

- 通知タップから該当旅行の画面へ遷移
- 投稿前に合成写真をプレビューして、撮り直し or 投稿を選べる
- 「投稿した人だけフィードを見られる」制限をアプリ側とFirestore/Storage Rulesに追加
- 通知音をグループ共通ではなく、**ユーザーごとに選べる**設計へ変更
- 名前設定を追加し、投稿カードに表示
- 招待コードのコピー導線を追加
- Momentの残り時間カウントダウンを追加
- Functions側で重複Moment作成を防止
- 無効なFCMトークンを自動削除
- Firestore / Storage RulesをMVP向けに締めた
- ランダム通知時刻をJST基準で生成

## できること

- 旅行グループを作成
- 招待コードで友達が参加
- Firebase Cloud Messagingで「Be Honest time」を通知
- 通知をタップして旅行画面へ
- 外カメ → インカメの順で撮影
- 2枚を1枚に合成し、投稿前に確認
- Firebase Storageへアップロード
- 投稿した人だけグループフィードを閲覧
- ユーザーごとに通知音を `honest_ping` / `travel_bell` / `camera_pop` から選択
- Cloud Functionsで「今すぐ通知」と「毎日ランダム通知」

## 大事な設計判断

iOS/Androidでは、通知が来た瞬間にバックグラウンドで勝手にカメラ撮影する設計は避けています。MVPは以下です。

```txt
通知が来る → 友達がタップ → アプリが開く → 外カメ/インカメ撮影 → 投稿
```

これはプライバシー面でもストア審査面でも安全です。

## ディレクトリ

```txt
lib/                       Flutterアプリ本体
functions/                 Firebase Cloud Functions
firestore.rules            Firestore Security Rules
storage.rules              Cloud Storage Rules
firebase.json              Firebase設定
native/                    iOS/Androidで必要な手動設定メモ
assets/sounds/             通知音ファイル置き場
scripts/create_flutter_project.sh
```

## 1. Flutterプロジェクトを作る

このスターターは `lib/` と Firebase 周辺ファイル中心です。ローカルでFlutterプロジェクトを生成してください。

```bash
unzip be_honest_brushedup.zip
cd be_honest_brushedup
./scripts/create_flutter_project.sh ../be_honest_app
cd ../be_honest_app
```

## 2. Firebaseを接続する

```bash
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
flutter pub get
```

`flutterfire configure` を実行すると、`lib/firebase_options.dart` があなたのFirebaseプロジェクト用に上書きされます。

## 3. Firebase機能を有効化

Firebase Consoleで以下を有効化します。

- Authentication: Anonymous sign-in
- Firestore Database
- Cloud Storage
- Cloud Messaging
- Cloud Functions

## 4. iOS通知設定

iOSでFCM通知を受けるには、Xcodeで以下を有効化してください。

- Push Notifications
- Background Modes → Remote notifications
- Firebase ConsoleにAPNs Auth Keyをアップロード

通知音を使う場合は、`honest_ping.caf` などを `ios/Runner` のBundleに追加します。詳しくは `native/ios/Runner-sounds/README.md` を見てください。

## 5. Android通知音設定

Androidで通知音を使う場合は、以下のように音源を配置します。

```txt
android/app/src/main/res/raw/honest_ping.wav
android/app/src/main/res/raw/travel_bell.wav
android/app/src/main/res/raw/camera_pop.wav
```

Android 8以降は通知チャンネルごとに音が固定されます。このスターターでは音ごとに別チャンネルIDを使います。

## 6. 権限を追加

`native/android/AndroidManifest.additions.xml` の内容を、生成された `android/app/src/main/AndroidManifest.xml` に反映してください。

iOSは `ios/Runner/Info.plist` に以下を追加します。

```xml
<key>NSCameraUsageDescription</key>
<string>Be Honestで友達と旅行中の写真を共有するためにカメラを使います。</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>撮影した写真を保存するために写真ライブラリへアクセスします。</string>
```

## 7. Functionsをデプロイ

```bash
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions,firestore:rules,firestore:indexes,storage
```

## 8. 実行

```bash
flutter run
```

## 最初の動作確認

1. アプリ起動
2. 名前と通知音を設定
3. 旅行を作成
4. 招待コードをコピー
5. 別端末で参加
6. 幹事端末から「今すぐBe Honest」
7. 通知をタップ
8. 外カメ → インカメ → プレビュー → 投稿
9. 投稿後にフィードが見えることを確認

## 次に作ると良い機能

1. 投稿へのリアクション
2. 2分以内投稿バッジ
3. 旅行終了後の自動アルバム
4. コメントや一言メモ
5. 位置情報を任意で添付
6. Apple/Googleログイン
7. 旅行ごとの思い出PDF/動画生成
