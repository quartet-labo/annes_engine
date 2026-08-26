# AnnesAccess Requirements

> Status: internal design reference for AnnesAccess maintainers. Host application
> developers should use [README.md](README.md) and the guides under
> [docs/](docs/) as the supported usage documentation. Future ideas in this file
> are not public API commitments.

## 目的

`annes_access` は、`annes_engine` 標準の軽量 RBAC engine として、認証済みユーザーが「どの resource に対して、どの action を実行できるか」を共通化する。

`annes_auth` はログインとセッションを扱い、`annes_admin` は管理画面 CRUD を扱う。`annes_access` はその間にある認可判定を担当し、host app ごとに `user.role == "admin"` のような判定が散らばる状態を避ける。

## 基本方針

- CanCanCan 風の Ability 中心 API に寄せる。
- 最初は DB-backed な軽量 RBAC に絞る。
- `annes_admin` から呼びやすい resource key / action ベースの判定を主 API にする。
- 業務固有の複雑な条件は host app 側の hook / rule class に逃がせるようにする。
- record-level ownership / tenant scope / customer-specific visibility は host app が担当する。
- index / list のように `record: nil` で判定する処理では、`annes_access` は一覧 scope を自動生成しない。
- `annes_auth` には認可の知識を持ち込まない。
- engine runtime から host app の domain model 定数を直接参照しない。

## スコープ

MVP で扱うもの:

- role 定義
- permission 定義
- role と permission の対応
- principal への role 付与
- `can?` / `authorize!` 判定 API
- controller concern
- `annes_admin` の `authorize_with` 連携例
- install generator
- migrations
- README
- `examples/customer_management` での利用例

## 非スコープ

MVP では扱わないもの:

- ログイン、セッション、パスワード管理
- deny rule
- 条件付き permission
- 部署階層、組織ツリー
- 顧客別、案件別の細かい ACL
- 所有者だけ編集可などの record ownership 判定
- 承認状態や業務ステータスごとの複雑な制御
- collection の閲覧範囲を SQL / relation として自動生成する scope resolver
- policy scope / `accessible_by` 相当の高度な SQL 生成
- UI 付きの本格的な権限管理画面

これらは必要になった段階で host app 側の rule / hook として実装し、複数案件で繰り返し出てきたものだけを `annes_access` に戻す。

## 用語

- principal: 権限を付与される主体。`Account`, `User`, host app 独自モデルを想定する。
- role: `admin`, `staff`, `viewer` などの役割。
- permission: `customers.read`, `projects.update` などの実行可能な操作。
- resource: `customers`, `projects`, `accounts` などの対象名。
- action: `read`, `create`, `update`, `destroy`, `manage` などの操作名。
- ability: principal が持つ permission をもとに `can?` を判定する object。

## データモデル

### `annes_access_roles`

- `id`
- `key`
- `name`
- `description`
- `system`
- `created_at`
- `updated_at`

制約:

- `key` は unique。
- `key` は英小文字、数字、underscore を基本とする。
- `system` は seed / generator が作る標準 role の保護に使う。

例:

- `admin`
- `staff`
- `viewer`

### `annes_access_permissions`

- `id`
- `key`
- `resource`
- `action`
- `description`
- `created_at`
- `updated_at`

制約:

- `key` は unique。
- `resource` と `action` の組み合わせは unique。
- `key` は原則として `"#{resource}.#{action}"` にする。

例:

- `customers.read`
- `customers.create`
- `customers.update`
- `customers.destroy`
- `projects.manage`

### `annes_access_role_permissions`

- `id`
- `role_id`
- `permission_id`
- `created_at`
- `updated_at`

制約:

- `role_id`, `permission_id` の組み合わせは unique。

### `annes_access_assignments`

- `id`
- `principal_type`
- `principal_id`
- `role_id`
- `created_at`
- `updated_at`

制約:

- `principal_type`, `principal_id`, `role_id` の組み合わせは unique。
- principal は polymorphic にする。

## 権限アクション

MVP の標準 action:

- `read`
- `create`
- `update`
- `destroy`
- `manage`

`manage` は同一 resource の全操作許可として扱う。

`annes_admin` の action との対応:

- `index` -> `read`
- `show` -> `read`
- `new` -> `create`
- `create` -> `create`
- `edit` -> `update`
- `update` -> `update`
- `destroy` -> `destroy`
- custom action -> action 名そのまま、または `manage`

## 公開 API

### 判定 API

```ruby
AnnesAccess.can?(principal, :read, :customers)
AnnesAccess.can?(principal, :update, :projects)
AnnesAccess.can?(principal, :destroy, :customers, record: customer)
```

`record:` は MVP では判定本体に使わなくてもよい。ただし将来の host rule 連携のため、API には最初から含める。

### 例外 API

```ruby
AnnesAccess.authorize!(principal, :update, :projects, record: project)
```

許可されない場合は `AnnesAccess::NotAuthorizedError` を raise する。

### Ability API

```ruby
ability = AnnesAccess.ability_for(principal)

ability.can?(:read, :customers)
ability.can?(:update, :projects)
ability.can?(:destroy, :customers, record: customer)
```

`AnnesAccess.can?` は内部的に `ability_for(principal).can?` へ委譲する。

## `annes_admin` 連携

host app の `config/initializers/annes_admin.rb` では、次の形で接続できることを目標にする。

```ruby
AnnesAdmin.configure do |config|
  config.authorize_with do |context|
    AnnesAccess.can?(
      context[:user],
      context[:action],
      context[:resource].name,
      record: context[:record]
    )
  end
end
```

最初の完成条件は、`examples/customer_management` にある次の判定を `annes_access` 経由に置き換えられること。

```ruby
context[:user]&.role == "admin"
```

## Controller concern

host controller では次のように使えること。

```ruby
class Admin::ProjectsController < ApplicationController
  include AnnesAccess::Authorization

  def update
    @project = Project.find(params[:id])
    authorize_access! :update, :projects, record: @project
  end
end
```

提供候補:

- `current_ability`
- `can_access?(action, resource, record: nil)`
- `authorize_access!(action, resource, record: nil)`

`current_access_principal` は host app で上書き可能にし、default は `current_account`、`current_user` の順で探す。

## 設定

```ruby
AnnesAccess.configure do |config|
  config.principal_class_names = ["Account"]
  config.super_admin_role_keys = ["admin"]
  config.default_role_key = "viewer"
end
```

MVP で必要な設定:

- `principal_class_names`
- `super_admin_role_keys`
- `default_role_key`
- `action_aliases`
- `custom_rule`

`super_admin_role_keys` に含まれる role を持つ principal は常に許可する。

`action_aliases` の default:

```ruby
{
  index: :read,
  show: :read,
  new: :create,
  edit: :update
}
```

## Host rule 拡張

DB 権限だけで判定できない条件は host app に逃がす。

```ruby
AnnesAccess.configure do |config|
  config.custom_rule = ->(principal:, action:, resource:, record:, allowed:) {
    allowed
  }
end
```

MVP では `allowed` を受け取って最終判定を返す block で十分とする。

### Record scope の責務分担

`annes_access` は「principal が resource/action を実行できるか」という RBAC の permission 判定を担当する。host app は「その principal がどの record を閲覧・操作できるか」という業務固有の scope を担当する。

例:

```ruby
# Controller / query layer in host app
@products = Product.visible_to_customer(current_user).ordered

@product = Product.visible_to_customer(current_user).find(params[:id])
```

index / list のような collection 処理では `record: nil` で `read` などを判定し、`annes_access` は `Product.visible_to_customer(...)` のような SQL scope を自動生成しない。`AccountMembership`, `ProductParticipant` など、host app 固有の domain model に依存する絞り込みは host app の query layer に置く。

show / update / destroy のように record がある処理では、必要に応じて `custom_rule` で host app 固有の最終判定を行う。

```ruby
AnnesAccess.configure do |config|
  config.custom_rule = ->(principal:, action:, resource:, record:, allowed:) {
    return false unless allowed

    if resource == "products" && action == "read" && record.present?
      Product.visible_to_customer(principal).where(id: record.id).exists?
    else
      allowed
    end
  }
end
```

将来的には rule class を追加できる余地を残す。

```ruby
class ProjectAccessRule < AnnesAccess::Rule
  def update?
    allowed_by_role? || record.owner_id == principal.id
  end
end
```

### 将来の scope hook 検討

複数の host app で同じ需要が出る場合は、汎用 hook として `scope_resolver` を追加する余地を残す。

```ruby
AnnesAccess.configure do |config|
  config.scope_resolver = ->(principal:, action:, resource:, relation:) {
    case resource.to_s
    when "products"
      relation.visible_to_customer(principal)
    else
      relation
    end
  }
end
```

ただしこの hook を追加する場合も、`annes_access` runtime は `AccountMembership` や `ProductParticipant` のような host app 固有 model を直接参照しない。`scope_resolver` は relation を受け取って relation を返す汎用 extension point に留める。

## Generator 要件

`bin/rails generate annes_access:install` で以下を生成する。

- `config/initializers/annes_access.rb`
- migrations
- seed helper または initializer コメント

標準 seed 例:

- `admin`: 全 resource の `manage`
- `staff`: customer / project の read, create, update
- `viewer`: customer / project の read

ただし resource は host app ごとに異なるため、generator が domain-specific permission を勝手に作りすぎないこと。

## Package boundary

`annes_access` runtime は、host app の `Customer`, `Project`, `Quotation` などを直接参照しない。

resource は string / symbol key として受け取り、host app 側で `annes_admin` resource name や controller 名から渡す。

## セキュリティ要件

- default は deny。
- principal が nil の場合は deny。
- role がない principal は deny。ただし `default_role_key` の自動利用を有効にした場合だけ例外。
- unknown action は deny。
- unknown resource は deny。
- `manage` は明示的に定義された resource にだけ効く。
- `manage` を全 resource ワイルドカードとして扱う機能は MVP に入れない。
- deny rule は MVP に入れない。

## テスト要件

最低限のテスト:

- role / permission / assignment の validation
- principal が role 経由で permission を持つ場合に `can?` が true
- permission がない場合に `can?` が false
- `manage` が同一 resource の標準 action を許可する
- nil principal は false
- unknown action / resource は false
- `authorize!` が unauthorized で例外を raise
- `annes_admin` context からの action mapping
- controller concern
- generator
- package boundary

`examples/customer_management` で確認すること:

- admin account は admin 画面に入れる
- viewer account は read だけできる
- 権限がない操作は forbidden になる

## 実装順序

1. `annes_access` gem skeleton を追加する。
2. configuration と error class を追加する。
3. models / migrations を追加する。
4. `Ability`, `can?`, `authorize!` を追加する。
5. action mapping を追加する。
6. controller concern を追加する。
7. install generator を追加する。
8. `annes_admin` 連携ドキュメントを追加する。
9. `examples/customer_management` を `annes_access` 経由の認可へ移行する。
10. README / CHANGELOG / version を整える。

## 将来拡張

- 権限管理 UI
- permission matrix import / export
- resource ごとの action 定義 DSL
- rule class
- record ownership helper
- tenant / customer scope
- policy scope / accessible records
- audit 連携
- feature flag 連携

## 未決事項

- `default_role_key` を自動適用するか、明示 assignment 必須にするか。
- `manage` を custom action にも効かせるか。
- `annes_admin` custom action の permission key を `resource.action` にするか、`resource.custom_action` にするか。
- 権限管理 UI を `annes_access` に持たせるか、`annes_admin` resource として設定例だけ用意するか。
- host app が既存 role column を持つ場合の移行導線。
