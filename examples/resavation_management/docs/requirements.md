# 予約管理 example 要件定義

- Type: requirements
- Date: 2026-07-13
- Status: Implemented
- Target: `examples/resavation_management`
- Scope: 社内向け予約管理アプリの MVP

## 1. 目的

紙、表計算、個人カレンダー等に分散した予約情報を一元管理し、スタッフが顧客、予約対象、当日の予定を安全に管理できるようにする。

同時に、Anne Engine の3エンジンを組み合わせる example として、次の責務分担を示す。

- `annes_auth`: スタッフ認証とセッション
- `annes_access`: role と permission による認可
- `anne_admin`: 顧客・予約対象の標準 CRUD
- ホストアプリ: 予約固有の画面、状態遷移、重複防止

## 2. 対象利用者

| ロール | 目的 |
| --- | --- |
| 管理者 `admin` | マスタ設定を含む全運用 |
| 担当者 `operator` | 顧客登録と日々の予約受付・更新 |
| 閲覧者 `viewer` | 当日の予定確認 |

顧客自身がログインする公開予約機能は MVP に含めない。

## 3. MVP の前提

- 一つの事業者で利用する。tenant 分離は行わない。
- 業務タイムゾーンは `Asia/Tokyo` とする。
- 予約は1人の顧客と1つの予約対象に紐づく。
- 予約対象は施設、部屋、設備、担当者、その他を表現できる。
- 一つの予約対象は同じ時間帯に1件だけ予約できる。
- 予約時間は任意の開始・終了日時とする。
- MVP では日跨ぎ予約を禁止する。
- 定員は1予約内の参加人数上限を表し、同時予約可能数ではない。
- 通常の新規予約は `confirmed` で登録する。
- 予約は物理削除せず、取消状態として履歴を残す。

## 4. ユースケース

### UC-01 ログイン

スタッフはメールアドレスとパスワードでログインする。無効化された Account はログインできない。未認証で管理画面へアクセスした場合はログイン画面へ遷移する。

### UC-02 顧客管理

スタッフは顧客の氏名、連絡先、メモを登録・更新する。システムは顧客番号を自動採番する。予約履歴がある顧客は削除せず、無効化する。

### UC-03 予約対象管理

管理者は予約対象の名称、種別、定員、利用可否を登録・更新する。無効な予約対象は新規予約の選択肢へ表示しない。

### UC-04 予約登録

担当者は顧客、予約対象、開始・終了日時、人数、受付経路、メモを入力する。時間重複や定員超過がなければ予約番号を採番して保存する。

### UC-05 予約変更

担当者は確定前または確定中の予約を変更する。日時・予約対象を変更した場合は重複を再検証する。他スタッフによる先行更新がある場合は上書きしない。

### UC-06 予約取消

担当者は予約を削除せず `canceled` へ変更する。取消日時、実行者、任意の理由を記録する。取消済みの時間枠には新しい予約を登録できる。

### UC-07 日別確認

スタッフは指定日の予約を開始時刻順で確認する。予約対象、状態、顧客・予約番号キーワードを組み合わせて絞り込める。

### UC-08 利用結果

開始時刻を過ぎた確定予約を `completed` または `no_show` に変更できる。

## 5. 機能要件

| ID | 要件 | 優先度 |
| --- | --- | --- |
| FR-001 | スタッフの login/logout と無効 Account の拒否 | P0 |
| FR-002 | admin/operator/viewer の RBAC | P0 |
| FR-003 | 顧客の一覧、検索、詳細、登録、編集、無効化 | P0 |
| FR-004 | 予約対象の一覧、検索、詳細、登録、編集、無効化 | P0 |
| FR-005 | 予約の一覧、詳細、登録、編集 | P0 |
| FR-006 | 予約の取消、完了、無断キャンセル | P0 |
| FR-007 | 日別スケジュールと複合 filter | P0 |
| FR-008 | 同一予約対象の blocking 予約の時間重複防止 | P0 |
| FR-009 | 時刻順、定員、必須関連、状態遷移の入力検証 | P0 |
| FR-010 | optimistic locking による上書き防止 | P0 |
| FR-011 | 3ロールと業務データの冪等 seed | P0 |
| FR-012 | setup、URL、seed account、制約を説明する README | P0 |

## 6. 業務ルール

### 6.1 予約状態

| 状態 | 意味 | 枠を占有するか |
| --- | --- | --- |
| `provisional` | 仮予約 | はい |
| `confirmed` | 予約確定 | はい |
| `completed` | 利用完了 | いいえ |
| `canceled` | 取消 | いいえ |
| `no_show` | 無断キャンセル | いいえ |

許可する遷移:

- provisional → confirmed / canceled
- confirmed → completed / canceled / no_show
- completed / canceled / no_show は終端状態

通常の新規登録画面は confirmed を作る。provisional の新規登録 UI は MVP の必須範囲に含めない。

### 6.2 時間重複

予約 A と B は次の場合に重複する。

```text
A.starts_at < B.ends_at AND B.starts_at < A.ends_at
```

終了時刻と次の開始時刻が同じ連続予約は許可する。provisional と confirmed だけを blocking 状態とする。

### 6.3 変更と削除

- provisional / confirmed の予約情報だけ編集できる。
- terminal 状態の予約情報は編集できない。
- 予約の destroy route は提供しない。
- 予約がある顧客・予約対象の物理削除を拒否する。
- inactive な顧客・予約対象は既存予約では表示を維持する。

## 7. 権限要件

| 操作 | admin | operator | viewer |
| --- | --- | --- | --- |
| 顧客の閲覧 | ✓ | ✓ | ✓ |
| 顧客の作成・更新 | ✓ | ✓ |  |
| 予約対象の閲覧 | ✓ | ✓ | ✓ |
| 予約対象の作成・更新 | ✓ |  |  |
| 予約の閲覧 | ✓ | ✓ | ✓ |
| 予約の作成・更新 | ✓ | ✓ |  |
| 確定・取消・完了・no-show | ✓ | ✓ |  |

画面上の button 非表示だけに依存せず、すべての request で server-side authorization を行う。

## 8. 非機能要件

### Security

- 全 `/admin` 業務画面で認証を必須にする。
- deny-by-default の認可を適用する。
- CSRF protection を維持する。
- password、session ID、顧客連絡先を不用意に log 出力しない。
- 本番の login rate limit は共有 cache store を使用する。

### Data Integrity

- 必須、FK、一意性、既知 enum、正の人数を DB 制約でも保護する。
- 予約重複は model validation と PostgreSQL exclusion constraint の二段階で防止する。
- 同時更新は `lock_version` で検出する。
- seed は再実行可能にする。

### Performance

- 日別 query は期間条件を必須にする。
- customer と reservation resource を eager load する。
- 開始日時、終了日時、状態、関連 ID に index を設定する。
- 一覧は pagination し、1ページ最大100件とする。

### Maintainability

- 予約ドメインを共通エンジンへ追加しない。
- engine と host app の責務を README と設計書へ明記する。
- 既存 `examples/customer_management` の setup・統合パターンに揃える。

## 9. MVP 対象外

- 公開予約、顧客アカウント
- 予約確認・リマインド通知
- 決済、返金、キャンセル料
- 外部カレンダー、POS、CRM 連携
- 複数店舗、tenant 分離
- 座席在庫型予約
- 複数予約対象の同時確保
- 営業時間、休業日、複雑なシフト
- 繰り返し予約、キャンセル待ち
- 永続監査ログ画面
- CSV import/export

## 10. 受け入れ条件

- README の手順で DB setup、test、server 起動ができる。
- seed account でログインできる。
- admin/operator/viewer の許可・拒否が権限表どおり動作する。
- 顧客と予約対象を登録・更新・無効化できる。
- 日別予約を filter して確認できる。
- 同一予約対象の重複予約を、通常操作と並行操作の両方で防止できる。
- 連続予約、別予約対象、取消済み枠への登録は成功する。
- 古い画面からの更新が HTTP 409 相当で拒否される。
- 予約取消後も予約、取消日時、実行者が残る。
- `db:schema:load` で exclusion constraint を再現できる。
- 全 Minitest が成功する。

## 11. 実装時の決定

- 代表業種は会議室・設備予約とする。
- provisionalはseedと状態遷移確認に利用し、新規登録UIではconfirmedを作成する。
- 取消理由は任意入力とする。
- terminal状態の訂正機能はMVPに含めない。
- 永続監査履歴はMVPに含めず、取消actor・日時・理由を予約へ保持する。
- AnneAdmin標準画面は`authorize_with`の判定に従って権限のない操作リンクを非表示にし、server-side認可も別途実行する。
