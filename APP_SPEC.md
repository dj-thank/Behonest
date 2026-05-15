# Be Honest MVP Spec v0.2

## コンセプト

旅行中だけ使う、身内限定の正直写真アプリ。

## MVP体験

1. ユーザーが名前と通知音を設定する
2. 幹事が旅行グループを作る
3. 招待コードをLINEなどで共有する
4. 友達がコード入力で参加する
5. ランダム時間または幹事の手動トリガーで通知が届く
6. 通知をタップして旅行画面へ
7. 外カメで1枚、インカメで1枚撮る
8. 合成写真をプレビューして投稿する
9. 投稿した人だけフィードを見られる

## MVPで意図的にやらないこと

- バックグラウンドで勝手に撮影
- BeRealのロゴ、UI、文言、音源、コードのコピー
- 連絡先の自動アップロード
- 位置情報の常時取得
- 公開SNS化

## コレクション設計

```txt
users/{uid}
  displayName: string
  selectedSoundKey: honest_ping | travel_bell | camera_pop
  createdAt: timestamp
  updatedAt: timestamp

users/{uid}/tokens/{tokenDocId}
  token: string
  platform: ios | android | unknown
  updatedAt: timestamp

trips/{tripId}
  name: string
  ownerId: string
  inviteCode: string
  memberIds: string[]
  active: bool
  startDate: timestamp
  endDate: timestamp
  timezone: string
  dailyMomentCount: number
  captureWindowMinutes: number
  createdAt: timestamp
  updatedAt: timestamp

trips/{tripId}/moments/{momentId}
  tripId: string
  status: scheduled | active | expired
  startsAt: timestamp
  expiresAt: timestamp
  createdBy: uid | cloud
  plannedDateKey: YYYY-MM-DD
  captureWindowMinutes: number
  createdAt: timestamp

trips/{tripId}/moments/{momentId}/posts/{uid}
  uid: string
  displayName: string
  frontImageUrl: string
  backImageUrl: string
  combinedImageUrl: string
  captureOrder: back_then_front
  createdAt: timestamp
  createdAtClient: timestamp
```

## 通知音キー

```txt
honest_ping
travel_bell
camera_pop
```

Androidは通知チャンネルID、iOSはBundle内の音源ファイル名で音を指定します。v0.2ではユーザーごとに通知音を選び、Functions側で音ごとにFCM送信を分けます。

## セキュリティ方針

- `users/{uid}` は本人だけ読める/編集できる
- 旅行はメンバーだけ読める
- Moment作成はCloud Functions経由
- 投稿は本人だけ作成/更新
- フィード閲覧は「自分も投稿済み」の場合のみ
- Storageも同じく「投稿済みゲート」をかける
