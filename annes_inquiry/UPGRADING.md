# Upgrading AnnesInquiry

## 0.2.0: flow intake and follow-up questions

条件・引継ぎを利用する更新では `bin/rails railties:install:migrations FROM=annes_inquiry` と `db:migrate` を実行してください。追加の `CreateAnnesInquiryFlowRules` は既存の直列フロー・下書き・正式回答を変更しません。条件のない既存フローは従来どおり動作します。

Install the additional Engine migrations with `bin/rails railties:install:migrations FROM=annes_inquiry` and migrate normally. Existing five migrations and standalone receipts remain unchanged; no backfill is needed. Register a flow adapter and explicitly enable `flow_endpoints_enabled` only when using the new participant endpoints. Existing form adapters are not invoked for each flow step. Configure identity, context, authorization, run expiry and same-primary-DB persistence as described in README. Flow receipts appear in flow administration, not the standalone inbox. Schedule flow notification recovery and draft cleanup separately from existing standalone jobs.

### 0.1.0からの導入

`bin/rails railties:install:migrations FROM=annes_inquiry`で4件の追加migrationをコピーし、
`bin/rails db:migrate`を実行します。Engineのmigrationは合計9件です。既存5件は変更せず、
既存回答・添付・通知およびPlan 1/2のフロー保存データへのbackfillは不要です。
通常の単独フォームadapterには変更がありません。フロー設定の既定は無効で、adapter未登録時は拒否します。

追加質問を使うホストは初回adapterに`persist_follow_up!`、管理actionの認可とscopeを実装し、
期限・通知・清掃の運用を設定してください。既存のprimary DB以外への書き込みや外部通知を
保存callbackへ含めないでください。詳しい契約と実行可能な接続例はREADMEとpackage hostを参照してください。

公開済み版は2026-09-21確認時点で0.1.0です。この変更は後方互換の追加機能として0.2.0を準備します。
依存するexampleのlockfileはありません。リリースは`Publish Gems` GitHub Actions workflowで行い、
この実装作業ではgem公開・手動tag pushを行いません。

## 0.1.0

This is the first GitHub Packages release of the former local
`engines/annes_inquiry` Engine in anne-mark. It retains its 0.1.0 version,
public namespace, API, table names, and migration sources.

To replace the local Engine:

1. Replace the local path dependency with `gem "annes_inquiry", "~> 0.1.0"`
   under the Quartet Labo GitHub Packages source, and update the lockfile.
2. Keep host business adapters, authentication callbacks, route mounts, domain links,
   and the five already installed inquiry migrations. Do not reinstall or renumber
   those migrations, recreate tables, or backfill existing answers.
3. Replace relative imports of Engine source CSS with the packaged
   `annes_inquiry/forms` asset. Ensure it is loaded consistently across host layouts
   when using Turbo. Remove Docker COPY instructions for the local Engine.
4. Keep host-owned database contract and business integration tests in the host.
   The package does not ship the Engine's test files. Engine-only tests now run here.
5. Remove the local Engine directory and update CI/coverage paths. Verify the host's
   regular and browser tests, production assets, migrations, and container build.

No data migration or adapter API changes are required. Active Storage setup and
configuration, the same-primary-DB transaction boundary, notifications, and cleanup
schedules remain the host's responsibility. For a new installation, follow README.

The runtime gemspec excludes JSON 3, which is incompatible with Rails 8.1's JSON
decoder. Update the host lockfile through Bundler so the constraint is included;
the Engine's development lockfile is not used by consuming applications.

The first package also hardens validation boundaries found during extraction review:
public controllers stop after a context hook sends a response, and excessive
attachment counts return a count error without inspecting individual files.
Allowed context hooks and in-limit uploads keep their existing behavior.
Text input containing NUL characters, including adapter-enriched values, now
returns a field error with HTTP 422 instead of raising during PostgreSQL persistence.
Raw text is checked before normalization so trimming cannot silently remove NUL.
