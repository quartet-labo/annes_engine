# AnnesInquiry

An isolated Rails Engine for configurable inquiry forms, typed answers,
attachments, versioned definitions, administration, and notification adapters.
It has no dependency on other Annes engines or host domain models.

## Installation

Use Ruby 3.4 or later, Rails 8.1.3.1 or later in the 8.1 series, and PostgreSQL.
Configure GitHub Packages credentials as described in the [repository README](https://github.com/quartet-labo/annes_engine#installation).

```ruby
source "https://rubygems.pkg.github.com/quartet-labo" do
  gem "annes_inquiry", "~> 0.1.0"
end
```

Install Active Storage in the host if it is not already installed, then run
`bin/rails railties:install:migrations FROM=annes_inquiry` and `bin/rails db:migrate`.
Keep the installed migrations in the host. Mount the Engine where appropriate:

```ruby
mount AnnesInquiry::Engine => "/inquiry", as: :annes_inquiry
```

Public endpoints default to disabled. Configure the admin authentication and
authorization callbacks before using its administration screens. Hosts can use
the renderer and submission service through their own URLs and business adapters.
See [UPGRADING.md](UPGRADING.md) when replacing the former local Engine.

## Development

Use Ruby 3.4.9, matching CI. From `annes_inquiry/`:

```sh
bundle install
bin/test --prepare
bin/test
bundle exec rake test
bin/test test/engine_test.rb
COVERAGE=true bin/test --schema-round-trip
bin/test --system
```

The runner respects Bundler's configured install location and an explicit
`BUNDLE_PATH`. The dummy uses a separate PostgreSQL `annes_inquiry_test` database.
Set `INQUIRY_DATABASE_URL` to a separate database ending in `_test` when needed.
Only PostgreSQL URLs with `sslmode` and `connect_timeout` query options are accepted;
connection overrides such as `database` are rejected. The runner ignores the host
`DATABASE_URL` and forces `RAILS_ENV=test`. `--prepare` creates or prepares this
dedicated test database; do not point it at a database containing valuable data.

Tests are discovered by `test/run.rb`. `--system` selects the Chrome tests and
fails if no tests exist. Coverage is written to `annes_inquiry/coverage`.
The tests, runner, dummy, and development dependencies are repository-only files;
the published gem contains runtime code, migrations, assets, and package documents.

## Boundaries

Engine classes use `AnnesInquiry` and must not reference host domain models,
authentication initializers, or the host ApplicationController/ApplicationRecord.
Configure host integration through registered callables. Loading the Engine
must not query its tables, seed data, or publish forms.

Engine-owned migration sources belong in `db/migrate`. Install them into the host using the Rails Engine migration task
and commit the installed copies. Do not also append Engine migration paths
to the host. Published migrations are changed through new migrations.
The dummy must exercise those same migration sources and PostgreSQL constraints.

Keep runtime assets inside the Engine and namespaced; do not depend on host
Tailwind source discovery. The standalone dummy checks the host integration boundary.

## Definitions and publishing

`Form` owns versions. `FormVersion` owns ordered fields, and each field owns
options and allowed file types. Settings such as placeholder, required, bounds,
normalizer and format are explicit columns; no JSON settings column is used.
Use the definition services as the write boundary:

```ruby
draft = AnnesInquiry::Definitions::DraftEditor.call(version, expected_lock_version: version.lock_version) do |record|
  record.fields.create!(key: "quantity", label: "数量", value_type: "integer", widget: "number", min_numeric: 1)
end
published = AnnesInquiry::Definitions::PublishVersion.call(draft, expected_lock_version: draft.lock_version)
next_draft = AnnesInquiry::Definitions::CloneVersion.call(published)
```

Editors and publishers lock the same Form row. Every edit increments the version
lock counter, including edits that change only child fields. Stale edits fail;
publishing validates all settings and the registered host adapter before retiring
the previous version. Only one draft and one published version may exist per form.
Published content is immutable through these services and model save/destroy;
direct SQL/update_columns are not supported editing APIs.

The same published field key cannot change type, and a removed key cannot be
reintroduced later. Labels and option labels may change in a new version.
Preserve the semantic meaning of keys and option values when editing definitions.
Types and widgets are listed in `AnnesInquiry::TypeRegistry`; only registered
normalizers and format rules are accepted. Host adapters can implement
`validate_definition!(version)` and be registered in
`AnnesInquiry.configuration.adapters[form.key]` from an initializer.

Install new Engine migrations into the host with
`bin/rails railties:install:migrations FROM=annes_inquiry`, then use the normal
host migration process. The standalone dummy reads the Engine migration source
directly; the host only executes its installed copies.

## 回答の保存モデル

`Submission` は受付番号(UUID)と版内で一意な送信キーを持ちます。`Answer` は項目ごとに1行で、スカラー型は対応する列だけに値を格納します。任意項目の未回答は行を作らず、false/0は回答として保持します。選択・添付型は子表に保存し、必須や子行数は受付サービスが検証します。

複合外部キーで回答と項目の版・型、選択肢の所属を保証し、単一選択はDBでも最大1件です。小数はdecimal(25,6)、整数はbigintです。`AnswerReader.new(submission)["field_key"]` は型付き値を返し、`choice_labels(key)` は受付当時の表示名を返します。添付値は `AnswerAttachment` の配列です。

Active Storageはホスト側でインストールしてください（dummyには独立migrationがあります）。回答添付の関連削除はblobをpurgeしません。共有先を含む参照を確認してから、専用の削除処理で未参照blobを清掃します。

`bin/test --schema-round-trip` は専用テストDBのschema dump/load後にDB制約を含む全テストを実行します。複合FK・CHECK・部分一意索引をschema.rbで往復できるため、SQL形式への変更は不要です。

## 入力検証と標準フォーム

`Input.new(version, raw_values: hash, adapter: nil, context: nil, time_zone: "UTC")` の `valid?` で検証します。`raw_values` は再表示用、`values` は型付きの値、`errors` は項目キー付きActiveModelエラーです。未知キーと配列/ハッシュ等の不正形状はホストの処理を呼ぶ前に拒否します。アダプターは `validate_raw_input`、`enrich_input`、`validate_input` を任意に実装できます。補完は信頼済みの型付き値を返し、標準検証も受けます。

数値は厳格変換し、bigintの範囲とdecimal(25,6)の精度を超える入力は丸めず拒否します。datetimeは `time_zone` のローカル時刻をUTCへ変換し、存在しない/曖昧な夏時間は拒否します。booleanの必須はfalseを許可し、同意必須はtrueのみ許可します。

添付はmultipartのUploadedFileだけを受け付けます。選択数・許可拡張子・内容から判定したMIME（互換性のある形式はファイル名でCSV・Office等へ細分化）・ファイルの実サイズを検証し、内容のSHA-256を計算します。検証だけではblobも受付も保存しません。

ホストのcontrollerで `helper AnnesInquiry::FormHelper` を指定し、`annes_inquiry/forms/form` に `version`、`input`、`scope`、`submit_url` を渡すとフォームを表示できます。既存のform内では `annes_inquiry/forms/fields` を利用し、`excluded_keys` で認証済み補完項目などの表示を省略できます（必須検証は省略しません）。CSSは `stylesheet_link_tag "annes_inquiry/forms"` で読み込みます。ホストの同一パスのpartialを配置するとRails標準のview探索で差し替えられます。ラベル・説明・選択肢・入力値はエスケープして表示します。

JavaScriptに依存せず全widgetを使用できます。数値・日付・日時のエラー時は元の不正文字列を保持するテキスト入力へ切り替えます。添付はブラウザの制約により再選択を案内します。独立dummyの `/preview/:id` は表示・検証のみでDBへ保存せず、製品側の公開ルートではありません。

テキスト形式は64 KiBずつUTF-8としての妥当性とNULなしを検証します。内容の署名が不明な場合はテキスト拡張子のみ補完し、PDFや画像を拡張子だけで許可しません。署名を識別できない独自形式はMIMEを未設定として拡張子で制限できます。

## 受付・重複防止・通知

`SubmissionToken.issue(version, identity: trusted_identity)` で2時間有効の送信情報を作り、`SubmissionService.call(form:, token:, identity:, raw_values:, adapter:, context:, time_zone:)` へ渡します。結果は `success?`、`submission`、`input.errors`、`status`、`replayed?` を持ちます。identityはホストがセッション/ログイン情報から決定し、クライアント入力のIDを使わないでください。

公開中の版だけで新規受付できます。署名不正・期限切れ・本人不一致・旧版は409、入力エラーは422です。同じ送信キー・同内容は200で元の受付を返し、内容変更は409です。保存済み受付は版の退役後も有効な署名と本人確認を経て再取得できます。選択配列・値・ファイル内容チェックサム・identity・ホストの業務コンテキストから安定したdigestを作ります。

アダプターの `enrichment_keys(context)` は認証情報から補完するキーを返します。再POSTではそのキーに限り保存時の回答を使い、現在のプロフィール変更で重複判定が変わらないようにします。`digest_context(context)` は業務に影響する安定したID等のHashを返します。クライアント入力項目とリピート元などは今回の値と比較します。検証メソッドは副作用を持たせないでください。

入力検証とアップロードはフォームロックの外側で行います。フォーム行のロック取得後に版と重複を再確認し、受付・回答・アダプターの `persist!`・通知要求を同じprimary DB接続で保存します。ホストは `prepare_context(controller)` で権限を検証してからServiceを呼びます。保存アダプターでメール/APIを実行しないでください。

標準公開controllerは `public_endpoints_enabled = true` のときだけ使用できます。`GET/POST forms/:key` と `GET complete/:receipt_id` を提供し、CSRF保護とセッション本人確認を併用します。完了画面は同じセッションで送信した最近20件だけ閲覧できます。ホスト固有URLはこのcontrollerを使わずServiceへ接続できます。

通知可能なアダプターは必ず `configuration.adapters[form.key]` に登録してください。`deliver(notification_request)` は :sent / :failed / :unknown を返し、保存済み関連から送信します。例外は送信後の可能性があるためunknownにします。`pending → processing` を排他取得し、最外側commit後に実行します。再POSTでは通知要求を増やしません。通知/状態更新の失敗で受付を巻き戻しません。

- `bin/rails annes_inquiry:recover_notifications`: pendingを実行し、1時間以上中断したprocessingをunknownにします。failed/unknownは自動再送しません。
- `bin/rails annes_inquiry:cleanup_uploads`: Engineが作った未参照blobの候補を表示します。`BEFORE=ISO8601`で期限、`EXECUTE=true`で削除を明示します。最低1日の猶予を必要とし、共有添付は対象外です。

上記コマンドの定期実行や本番実行は導入側で設定します。失敗時に残るアップロードは回答データとは別に清掃されます。結果不明の通知は外部の送信履歴を確認してから判断してください。

外側transactionがrollbackした新規アップロードは、rollback callbackでストレージから削除します。ストレージの削除が失敗した場合は、未参照blob行を復元し猶予付き清掃の候補を保持します。ホストがActiveRecord::Rollbackで保存を取り消した場合も、成功結果を返しません。

未参照blob清掃は開いたDB transactionの外で実行します。ストレージ削除後にDBだけをrollbackする呼び出しを拒否します。

## 管理画面

Engineのrootと `/admin/forms` は定義一覧、`/admin/versions/:id` は版詳細です。管理controllerはAdminAccess concernを共有し、ホストの基底controllerには依存しません。`admin_authenticator(controller)` が管理者を返し、`admin_authorizer(controller, user)` が許可する場合だけ使用できます。どちらか未設定なら拒否します。任意の `admin_home_path` でホスト管理トップへ戻せます。

管理の書き込みはDraftEditor/PublishVersion/CloneVersionを通します。lock_versionは子定義の変更でも更新します。全型に対応する設定を編集し、表示順は整数で指定できます。プレビューは標準検証のみで保存しません。公開/退役版では入力欄を無効にし、選択肢や添付許可形式も閲覧だけにします。型変更で適用不能な設定と子定義が削除されることを編集画面に表示します。

## 受付管理と運用

`/admin/submissions` はフォーム/版/UTC日付範囲/最大5つの型付き条件で検索できます（画面は3条件）。回答条件はフォーム指定が必要で、項目キーを版横断で検索します。数値/日付/日時の一致・上下限、文字列の一致/部分一致、真偽値・選択値の一致を提供します。EXISTSで複数条件を組み合わせ、50件ずつ日時/IDの降順で表示します。詳細は当時の版/項目/選択肢を使い、編集は提供しません。

添付は `/admin/submissions/:submission_id/attachments/:id` で管理認可と所属を確認し、attachmentとしてダウンロードします。通常のActive Storage URLを画面に出しません。

- `admin_submission_link(controller, submission)` → `{ label:, path: }` でホスト業務詳細への導線を返せます。
- `admin_notification_action(controller, request)` → `{ label:, path:, method: :get/:post }` で確認/再送導線を返せます。POSTはfailedだけに表示し、unknownはGETで送信履歴確認へ誘導します。
- フックは許可された場合だけ導線を返し、ホストの遷移先でも認証・認可してください。ローカル絶対パスのみを表示します。未登録時は操作を表示しません。

`retention_days` はホストが正の整数を設定します。`bin/rails annes_inquiry:retention_candidates` は期間を過ぎた受付ID/日時を表示するだけです。初期値は未設定で、自動削除しません。

削除は運用者が候補・案件/メール履歴の保持要件を確認し、処理中通知を止めたうえで実施します。ホスト関連表と共有/リピート添付の扱いを先に決定し、同一transactionで対象通知・回答選択・添付関連・回答・許可されたホスト関連・受付の順に整理してください。回答の個別削除画面はありません。公開した定義は残します。ストレージの削除はcommit後、未参照blobの候補を確認して `EXECUTE=true` の清掃コマンドで実行します。案件を無条件にcascade削除しません。

現時点の実行計画/取得テストでは既存の項目キー・回答一意索引とEXISTSを利用でき、一覧の関連取得は件数によらず3クエリです。実運用で遅い数値/日付条件が確認された場合に限り対応する索引を追加します。
### 添付清掃の再試行

期限を過ぎた未参照BlobのDB削除と同じトランザクションで `annes_inquiry_blob_deletions` に削除要求を保存し、commit後にストレージを削除します。ストレージ障害やプロセス中断で残った要求は次の清掃実行で再試行し、ファイルと画像派生物の削除に成功した場合だけ要求を削除します。削除要求はJSONBを使わず、キー・サービス名・画像フラグを保持します。
