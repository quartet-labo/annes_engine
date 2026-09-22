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

## Follow-up questions and history

初回の受付詳細から「追加質問を準備」を選び、公開済みの受付フロー、質問タイトル、回答期限を指定します。そのまま使う場合は公開版を固定します。「この依頼専用に複製して編集する」を選ぶと、フォーム・項目・条件・引継ぎを専用の下書きへコピーします。プレビュー後に明示的に発行すると、回答待ちとして初回受付の履歴に表示されます。

専用定義は通常のテンプレート一覧・新規開始・clone/export/import経路に出しません。専用editorは初回受付の現在の閲覧・追加質問権限を毎回確認し、発行後の編集を拒否します。初回の定義、公開版、回答原本は変更しません。追加質問から更に追加質問を作ることはできません。

初回フローのadapterに`admin_follow_up`、`admin_cancel_follow_up`の認可と、次のcallbackを実装してください。追加回答用フローに別のadapterを登録する必要はありません。

```ruby
def persist_follow_up!(request, run, answers, context)
  original = BusinessRequest.find_by!(intake_run_id: request.root_run_id)
  original.additional_answers.create!(intake_run_id: run.id,
    follow_up_request_id: request.id, answers: answers)
end
```

このcallbackはResponse・回答・質問のanswered状態・通知要求と同じtransaction内です。初回の`persist!`は呼びません。rollback時には全て戻るため、外部通信を行わずrun_id/request_idにDB一意制約を設けてください。

`scope_runs`には許可した追加回答runも含めます。Engineはrootとresponseの両方のscope/actionを検証します。たとえばホストが受付権限と追加回答権限を別に管理する場合は、次のように許可済みIDのrelationを合成します。

```ruby
def scope_runs(relation, context:)
  roots = context.user.visible_business_requests.select(:intake_run_id)
  responses = context.user.visible_additional_answers.select(:intake_run_id)
  relation.where(id: roots).or(relation.where(id: responses))
end
```

回答前から追加runを許可するには、発行済みrequestとホストの案件権限をjoinしたrelationを使ってください。通知リンクは本人認証の代わりになりません。`prepare_context`でログインし、初回と同じidentity/contextを返します。初回Flow/Formまたは質問Flow/Formを停止した場合、発行・回答を拒否します。

サービスは`FollowUps::Prepare(root:, version:, context:, definition_context:, request_key:, title:, due_at:, custom:)`、`Issue(request:, context:, definition_context:, expected_lock_version:, expected_definition_digest:)`、`Cancel(request:, context:)`です。definition_contextはテンプレート定義の認可用、contextは初回adapterの実行用です。省略時は同じcontextを用います。専用editorをサービスから使う場合は`DefinitionPolicy::Context.new(definition_context:, run_context:, follow_up_id:)`を渡してください。rootの権限検証は省略されません。

Issueには画面で提示したrequest.lock_versionと`FollowUps::DefinitionDigest.call(request)`を送ります。途中で定義が変われば409です。発行・回答通知はそれぞれ`follow_up:<request_id>:issued`（rootの通知）、`answered`（response runの通知）となり、`notification.follow_up_request`から回次や期限を参照できます。通知はcommit後で、結果不明の配送を自動再試行しません。

`FollowUps::Reader.call(root:, context:, action: :view)`は許可された回次を返します。利用者には未発行draftを返しません。`Flows::AnswerReader.call(run:, context:)`で初回と各追加runの回答を別々に読みます。正式な原本はそれぞれの`run.response`です。

期限は操作時に評価し、再開で延長しません。未回答だけ取消でき、期限切れ・取消後も初回と確定済み回答は履歴に残します。`cleanup_drafts`は取消/期限切れの下書きを対象にし、正式回答が参照する添付は削除しません。管理一覧には追加runを重ねて表示せず、初回詳細に回次・日時・状態をまとめます。
