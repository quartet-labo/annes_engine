# Reservation Management Example

スタッフが顧客、予約対象、予約を管理する社内向け予約管理アプリのexampleです。

- `anne_auth`: スタッフ認証とセッション
- `anne_access`: admin / operator / viewerのロール別認可
- `anne_admin`: 顧客・予約対象の標準CRUD
- host app: 日別スケジュール、予約CRUD、状態遷移、競合制御

詳細は[要件定義](docs/requirements.md)と[基本設計](docs/design.md)を参照してください。

## Requirements

- Ruby 3.4.9
- Rails 8.1.x
- PostgreSQL 16以降
- repository内の`anne_auth`、`anne_access`、`anne_admin`

## Setup

repository rootから次を実行します。

```sh
cd examples/resavation_management
bundle install
bin/rails db:setup
bin/rails test
bin/rails server
```

ブラウザで <http://localhost:3000/admin/login> を開いてください。

`bin/setup`を使う場合は、依存関係の確認、DB準備、seed投入をまとめて実行できます。

```sh
cd examples/resavation_management
bin/setup
bin/rails server
```

### Database URL

環境変数を設定しない場合、developmentは`anne_reservation_management_development`、testは`anne_reservation_management_test`を使用します。

example専用の接続先を指定する場合は`RESERVATION_MANAGEMENT_DATABASE_URL`を使います。

```sh
RESERVATION_MANAGEMENT_DATABASE_URL=postgresql://postgres:password@127.0.0.1:5432/anne_reservation_management_development bin/rails db:setup
```

この変数はdevelopmentとtestの両方で参照されるため、testではtest専用DBを指定してください。

```sh
RAILS_ENV=test RESERVATION_MANAGEMENT_DATABASE_URL=postgresql://postgres:password@127.0.0.1:5432/anne_reservation_management_test bin/rails db:test:prepare
RAILS_ENV=test RESERVATION_MANAGEMENT_DATABASE_URL=postgresql://postgres:password@127.0.0.1:5432/anne_reservation_management_test bin/rails test
```

CIなど複数アプリで共通化する場合は`DATABASE_URL`も利用できます。両方が設定された場合は`RESERVATION_MANAGEMENT_DATABASE_URL`を優先します。

## Seed Accounts

以下はローカル開発・動作確認専用の固定資格情報です。本番環境では使用しないでください。

| Role | Email | Password | 主な権限 |
| --- | --- | --- | --- |
| admin | `admin@example.com` | `password-1234` | 顧客・予約対象・予約の全操作 |
| operator | `operator@example.com` | `password-1234` | 顧客作成・更新、予約作成・更新・状態操作 |
| viewer | `viewer@example.com` | `password-1234` | 顧客・予約対象・予約の閲覧 |

seedは再実行可能です。実行日のTokyo時刻を基準に、active / inactiveなマスタ、全予約状態、同一予約対象の連続予約を投入します。

```sh
bin/rails db:seed
```

## Authorization Matrix

このexampleのAnneAccess matrixは、社内向け予約管理の実装例です。`admin`は顧客・予約対象・予約を管理し、`operator`は顧客作成/更新と予約作成/更新、`confirm` / `cancel` / `complete` / `no_show` のような予約状態操作を許可されます。`viewer`は閲覧のみです。

`manage`は標準CRUD actionだけをまとめるため、予約状態操作は明示的なcustom action permissionとしてseedしています。tenant、担当者、予約対象ごとの参照範囲が必要なhost appでは、AnneAccess runtimeではなくcontroller、query、model scope、serviceで絞り込んでください。

共通の考え方はAnneAccessの[role and permission templates](../../anne_access/docs/role-and-permission-templates.md)を参照してください。

## Main Screens

| URL | 用途 |
| --- | --- |
| `/admin/login` | スタッフログイン |
| `/admin/reservations/schedule` | 日別予約スケジュールと複合filter |
| `/admin/reservations` | 予約一覧 |
| `/admin/reservations/new` | 予約登録 |
| `/admin/customers` | 顧客管理 |
| `/admin/reservation_resources` | 予約対象管理 |

root、`/dashboard`、`/admin/home`は日別予約スケジュールへ遷移します。

## Reservation Workflow

通常の新規登録は`confirmed`を作成します。`provisional`はseedと状態遷移確認用です。

```text
provisional -> confirmed
provisional -> canceled
confirmed -> completed / canceled / no_show
```

状態遷移はAASMで管理し、画面の専用操作からのみ実行します。`completed`、`canceled`、`no_show`は終端状態です。

## Reservation Constraints

- 1予約は1顧客と1予約対象に紐づきます。
- 予約はTokyo時間で同一業務日内に収め、日跨ぎを禁止します。
- 人数は予約対象の定員以下にします。
- `provisional`と`confirmed`は同一予約対象で時間重複できません。
- 時間範囲は`[開始, 終了)`として扱うため、終了時刻と次の開始時刻が同じ連続予約は可能です。
- `canceled`、`completed`、`no_show`は予約枠を占有しません。
- 予約の物理削除は提供せず、取消日時・実行者・理由を保持します。
- 通常重複は入力エラー、並行登録のDB競合と古い画面からの更新はHTTP 409として扱います。

## Test

```sh
bin/rails db:test:prepare
bin/rails test
bin/rails zeitwerk:check
```

PostgreSQLのexclusion constraintと別connectionの同時予約テストを含むため、test DBへ接続できる状態で実行してください。

## Authorization UI

AnneAdminの顧客・予約対象画面では、現在のroleに許可されていない新規登録・編集リンクを表示しません。画面上の表示制御とは別にserver-side認可も実行し、権限のないURLへの直接アクセスはHTTP 403になります。

## Repository Path

directory名は依頼時の指定どおり`examples/resavation_management`を維持しています。アプリケーション名とRuby namespaceは`Reservation Management` / `ReservationManagement`です。
