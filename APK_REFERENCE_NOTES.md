# 添付XAPK参照メモ

添付された `BeReal. Your friends for real._3.80.1_APKPure.xapk` は、アイデア整理の参考としてのみ確認しました。アプリのコード・UI・画像・音源はコピーしていません。

## 確認できた参考ポイント

- APK内にFirebase Messaging、Firebase Auth、Crashlytics系モジュールが含まれていました。
- `bereal.app.push.BeRealMessagingService` というFCM系サービス名が文字列として確認できました。
- `MomentForegroundService` というMoment通知まわりと思われるサービス名が確認できました。
- `androidx.camera` / CameraX系のモジュールが含まれていました。
- `res/raw/bereal.mp3`、`res/raw/moment.mp3` のような通知音らしきファイルが含まれていました。

## Be Honest側に反映した設計

- Firebase Cloud Messagingで全員に通知する
- Androidは通知チャンネルを使う
- カメラはFlutter公式 `camera` パッケージで実装する
- 通知後に撮影画面を開く
- ユーザーごとに通知音を選べるようにする
- 投稿済みユーザーだけフィードを見られるようにする
- バックグラウンドで勝手に撮らない

## 反映しなかったもの

- BeRealの画面UI
- BeRealのロゴ、文言、音源
- BeRealの内部コード
- 連絡先や広告SDKなど、MVPに不要な権限・機能
