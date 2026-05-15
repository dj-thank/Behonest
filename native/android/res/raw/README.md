# Android notification sounds

ここに置く音源を、生成後のFlutterプロジェクトへコピーしてください。

```txt
android/app/src/main/res/raw/honest_ping.wav
android/app/src/main/res/raw/travel_bell.wav
android/app/src/main/res/raw/camera_pop.wav
```

注意:

- ファイル名は小文字英数字とアンダースコアにしてください。
- 拡張子を除いた名前が `RawResourceAndroidNotificationSound` の指定名です。
- Android 8以降は通知チャンネル作成後に音が固定されます。音を差し替えたらチャンネルIDのバージョンも更新してください。
