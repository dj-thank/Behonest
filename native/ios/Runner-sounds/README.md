# iOS notification sounds

通知音を使う場合、生成後のFlutterプロジェクトで `ios/Runner` のBundleに以下を追加してください。

```txt
honest_ping.caf
travel_bell.caf
camera_pop.caf
```

注意:

- iOS通知音は30秒未満にしてください。
- `.caf`, `.aiff`, `.wav` などを利用できます。
- Xcode上で Runner target に含める必要があります。
