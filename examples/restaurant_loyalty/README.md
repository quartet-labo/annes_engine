# Restaurant Loyalty Example

飲食店の紙のポイントカードを置き換えるdemo appです。

- `anne_loyalty`: ポイント制度、会員、ledger、point lot、特典、redemption token
- `anne_auth`: スタッフ・管理者ログイン
- `anne_access`: admin / manager / staff / viewer のRBAC
- `anne_admin`: ポイントプログラム、店舗、特典の管理CRUD
- host app: 顧客、receipt、顧客画面、スタッフ付与・特典利用画面

詳細な設計背景は[技術構想](docs/technical_concept.md)を参照してください。

## Requirements

- Ruby 3.4.9
- Rails 8.1.x
- PostgreSQL 16以降
- repository内の`anne_auth`、`anne_access`、`anne_admin`、`anne_loyalty`

## Setup

repository rootから次を実行します。

```sh
cd examples/restaurant_loyalty
bundle install
bin/rails db:setup
bin/rails test
bin/rails server
```

ブラウザで <http://localhost:3000/customer> を開いてください。

clean DBから手順を確認する場合は次を使います。

```sh
bin/rails db:drop db:create db:schema:load
bin/rails db:seed
bin/rails db:seed
bin/rails test
```

`db:seed`は再実行可能です。2回実行してもaccount、role、permission、program、location、reward、customer、member、receipt、ledger entryは重複しません。

### Database URL

環境変数を設定しない場合、developmentは`anne_restaurant_loyalty_development`、testは`anne_restaurant_loyalty_test`を使用します。

example専用の接続先を指定する場合は`RESTAURANT_LOYALTY_DATABASE_URL`を使います。

```sh
RESTAURANT_LOYALTY_DATABASE_URL=postgresql://postgres:password@127.0.0.1:5432/anne_restaurant_loyalty_development bin/rails db:setup
```

CIなど複数アプリで共通化する場合は`DATABASE_URL`も利用できます。両方が設定された場合は`RESTAURANT_LOYALTY_DATABASE_URL`を優先します。

## Seed Accounts

以下はローカル開発・動作確認専用の固定資格情報です。本番環境では使用しないでください。

| Role | Email | Password | 主な権限 |
| --- | --- | --- | --- |
| admin | `admin@example.com` | `password-1234` | program、location、rewardの管理、会員閲覧、付与、利用確定 |
| manager | `manager@example.com` | `password-1234` | location/reward管理、program確認・更新、会員閲覧、付与、利用確定 |
| staff | `staff@example.com` | `password-1234` | 会員閲覧、ポイント付与、特典利用確定 |
| viewer | `viewer@example.com` | `password-1234` | 会員閲覧のみ |

Seed customer:

- `C-DEMO-001`: 初期25 pt、coffee交換可能
- `C-DEMO-002`: 初期0 pt

## Main Screens

| URL | 用途 |
| --- | --- |
| `/customer` | 顧客ホーム。現在ポイントと次の特典を表示 |
| `/customer/card` | 会員QR payload表示 |
| `/customer/rewards` | 特典一覧とredemption token発行 |
| `/customer/history` | ledger履歴 |
| `/admin/login` | staff/adminログイン |
| `/staff` | 会員検索 |
| `/staff/earn` | 会計金額からポイント付与 |
| `/staff/redemptions` | redemption tokenの利用確定 |
| `/admin/loyalty_programs` | ポイントプログラム管理 |
| `/admin/loyalty_locations` | 店舗管理 |
| `/admin/loyalty_rewards` | 特典管理 |

## Demo Workflow

1. `/customer`で`C-DEMO-001`の残高25 ptを確認します。
2. `/admin/login`で`staff@example.com`としてログインします。
3. `/staff/earn`でmember key `C-DEMO-001`、receipt number `R-DEMO-UI-001`、amount `1500`を入力し、15 ptを付与します。
4. `/customer/rewards`で`コーヒー無料`を交換し、表示された`redemption:<token>`のtoken部分を控えます。
5. `/staff/redemptions`でtokenを入力し、特典利用を確定します。
6. 同じtokenをもう一度送信すると二重利用として拒否されます。
7. `/admin/loyalty_rewards`を`admin@example.com`で開き、特典CRUDを確認します。

## Test

```sh
bin/rails db:test:prepare
bin/rails test
```

主な受け入れテスト:

- seedから顧客画面、スタッフ付与、顧客交換、スタッフ利用確定、二重利用拒否を確認
- adminはrewardを作成でき、viewerはadmin write操作とstaff付与を拒否されることを確認
- seedを2回読み込んでも主要データ数が増えないことを確認

## MVP Boundaries

今回のdemoはMVPです。以下は未実装です。

- campaign evaluator
- point expiration batch
- rank / tier
- 集計report
- POS / receipt import adapter
- camera QR scan、PWA、offline対応
- push通知、メール通知

スタッフ画面のscanは、MVPではQR payloadまたはtokenを手入力する形で確認します。

## Security Notes

- `config/initializers/anne_loyalty.rb`ではtoken digest secretに`secret_key_base`を使います。本番では安定したsecretを設定してください。
- QRには`member:<member_key>`または`redemption:<token>`だけを表示し、残高や個人情報は含めません。
- ポイントの付与・利用は`anne_loyalty` service経由で行い、ledgerを直接更新しません。
- demo seedの固定パスワードは開発用です。本番環境では使用しないでください。
