# Privacy and Store Notes

## カメラ

Be Honestは、ユーザーが撮影ボタンを押したときだけカメラを使います。
通知を受けただけでバックグラウンド撮影する設計は入れていません。

## 写真

写真は旅行グループのメンバーだけが閲覧できます。
さらに、Momentごとのフィードは自分も投稿したあとだけ閲覧できます。

## 通知

通知はFirebase Cloud Messagingで送信します。
通知音はユーザーごとに選択できます。

## 最小権限

MVPでは以下を使います。

- Camera
- Push Notifications
- Internet

連絡先・常時位置情報・広告IDなどは使いません。

## ストア申請メモ

審査用説明では以下を明記してください。

```txt
This app is a private travel photo app for friends. The camera is only activated after the user opens the app and taps the capture button. The app never captures photos in the background or without user interaction.
```
