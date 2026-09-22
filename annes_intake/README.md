# AnnesIntake

独立したRails Engineです。質問テンプレートを組み合わせ、途中保存・再開・条件分岐を含む受付全体を一度に送信できます。単独のお問い合わせフォームにはAnnesInquiryを使用してください。両Engineの設定、テーブル、通知は独立しています。

## Installation

Ruby 3.4.9、Rails 8.1.3.1以降の8.1系列、PostgreSQLを使用します。`annes_form_kit ~> 0.1.0`を依存解決します。Inquiryは不要です。

```ruby
# Gemfile — GitHub Packagesの認証設定はリポジトリREADMEを参照
source "https://rubygems.pkg.github.com/quartet-labo" do
  gem "annes_form_kit", "~> 0.1.0"
  gem "annes_intake", "~> 0.1.0"
end
```

```sh
bin/rails active_storage:install # 未導入の場合のみ
bin/rails railties:install:migrations FROM=annes_intake
bin/rails db:migrate
```

```ruby
mount AnnesIntake::Engine => "/intake"
```

## Host configuration

公開入力は既定で無効です。認証と業務ルールはホストが提供します。設定不足やtrue以外の認可結果は拒否します。

```ruby
AnnesIntake.configure do |config|
  config.endpoints_enabled = true
  config.admin_authenticator = ->(controller) { controller.current_user }
  config.admin_authorizer = ->(controller, user) { user.admin? }
  config.definition_authorizer = IntakeDefinitionAuthorizer.new
  config.adapters["application"] = ApplicationIntakeAdapter.new
  config.operation_token_ttl = 2.hours
end
```

定義authorizerは`prepare_context(controller, admin:)`、`scope_definitions(relation, context:)`、`authorize!(action:, record:, context:)`を実装します。作成時のrecordはnil、閲覧は`admin_view_definition`、変更・公開・取込は`admin_define`です。各定義モデルのrelationを同じモデルのrelationとして絞り込み、作成した定義も所有scopeへ含めてください。サービス単体で呼ぶ場合もcontextと認可が必要です。

受付adapterは次のメソッドを実装します。

| Method | Responsibility |
|---|---|
| `prepare_context(controller)` | ログイン済み本人と業務context。redirect/renderした場合は処理を中断 |
| `identity(context)` / `context_key(context)` | 信頼できる安定した識別文字列 |
| `authorize!(action:, run:, step:, context:)` | 許可時にtrue |
| `scope_runs(relation, context:)` | 閲覧可能なRun relation |
| `run_expires_at(context)` | 有限の未来Time。再開しても延長しない |
| `validate_step(step, values, context)` | 任意。項目key→エラー配列 |
| `validate_run(run, answers, context)` | 任意。全体エラー配列 |
| `persist!(run, answers, context)` | 同じDB transactionで業務行を保存 |
| `deliver(notification_request)` | 任意。commit後の配送。sent/failed/unknownを返す |

操作actionは`start/view/save/complete/finalize/resume/cancel/attachment`と`admin_list/admin_view/admin_attachment`です。管理一覧はadapterごとのscopeを対応flowへ限定して集約します。フローごとに1つのadapterを登録すれば、質問ごとの設定は不要です。

`answers`はstep key→field key→型付き値です。Reviewとpersist!/validate_runの添付は`RunPayload::Attachment(filename, byte_size, content_type)`です。一時IOは外へ渡しません。原本のファイル参照は`run.response.step_responses`からホスト側で取得できます。`validate_step`は検証中のUpload値を受け取り、その場だけで参照してください。

`persist!`で外部通信を行わないでください。transactionが失敗して再試行されるとcallbackは再実行され得ます。確定したResponse・業務行・通知要求は1つです。通知例外は結果不明となり、自動再送しません。

## Authoring and participant journey

`/intake/admin/forms`で名前から質問テンプレートを作成し、項目を追加して公開します。`/intake/admin/flows`で受付名を指定し、公開テンプレートを順に追加して公開します。内部キーは自動生成され、詳細設定で指定できます。adapter登録にはフローの詳細設定に表示されるキーを使用してください。

条件と引継ぎは任意です。条件は前方stepの回答だけを参照し、同じグループはAND、複数グループはORです。引継ぎは読み取り専用です。前段の変更で後段は再確認が必要になります。対象外の下書きは保持し、全体確認・送信・通知から除外します。

利用者は`/intake/flows/:key`から開始します。「途中保存」は正式送信を行わず、「保存して次へ」は次の対象質問へ進みます。最後は全体確認へ進み、正式送信で全ての回答と業務行を原子的に保存します。再開には同じ本人の認証が必要で、古い操作tokenは失効します。添付リンクでも毎回認可します。

## Portable definition copy

`Definitions::ImportSchema.call(document:, context:)`はFormKit schema v1を検証し、常に新規Formと下書きを作ります。公開・上書き・同期は行いません。併用ホストの任意bridgeだけがInquiryの`Definitions::ExportSchema`を呼びます。書き出し元と取り込み先の両方で認可してください。`test/forms_coexistence_host`にCSRF付きの例があります。

## Public operations and maintenance

`Runs::Start/SaveDraft/CompleteStep/Resume/Review/Finalize/Cancel`と`OperationToken.issue`を公開します。SaveDraftはraw入力と`retained_attachment_ids`を受け、CompleteStepには保存結果の`expected_revision`を渡します。Reviewは型付き回答と確定token、Finalizeはrun/response/replayedを返します。古いtoken・版・revision・actionは409、scope外は404、操作拒否は403、不正入力は422です。

```sh
bin/rails annes_intake:recover_notifications
bin/rails annes_intake:cleanup_drafts # 取消/期限切れ候補の表示
EXECUTE=true bin/rails annes_intake:cleanup_drafts
bin/rails annes_intake:cleanup_uploads # 1日以上経過した未参照blobのみ
EXECUTE=true bin/rails annes_intake:cleanup_uploads
```

確定原本は削除しません。blobの物理削除は全ActiveStorage参照を確認し、commit後の削除キューで行います。バックアップ・保持期間・通知内容/宛先はホストが管理してください。

## Development

```sh
bin/test --prepare
bundle exec rake test
bin/test --schema-round-trip
bin/test --system
bundle exec brakeman --force-scan --no-pager
```

リポジトリルートで`ruby script/check_intake_package`、`ruby script/check_forms_coexistence`を実行できます。専用の`annes_intake_package_test`と`forms_coexistence_test`だけを再作成します。
