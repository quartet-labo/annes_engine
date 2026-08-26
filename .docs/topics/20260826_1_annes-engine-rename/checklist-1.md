# 実装チェックリスト: AnnesAuthへのgem・名前空間移行

## 対応Plan / PR

- Plan: `./plan-1.md`
- Topic: `20260826_1_annes-engine-rename`
- PR単位: Plan 1全体で1 PR

## PR / stack記録

| 項目 | 計画 | 実績 |
|---|---|---|
| headブランチ | `refactor/annes-auth` | `refactor/annes-auth` |
| baseブランチ | `main` | `main` |
| 直下の依存Plan | なし |  |
| stack位置 | bottom |  |
| PR | 未作成 | GitHub CLI認証トークンが無効のため未作成 |
| マージ順 | 1番目 |  |

## ステータス定義

- `planned`: 計画済み（未着手）
- `done`: 計画どおり完了
- `changed`: 計画から変更して実施（理由を記載）
- `skipped`: 未実施 / 不要化（理由を記載）

## Task別チェック

### Task 1: 改名契約とDB移行をテストで固定する

| ID | 種別 | 内容 | 対応コミット（予定） | 実績コミット | 状態 | メモ |
|---|---|---|---|---|---|---|
| 1-1 | test | load・constant・Engine package契約 | `test(auth): define AnnesAuth package contract` | `b0f2622` | changed | 実装と同一コミットで追加。旧require非提供も明示的に検証。 |
| 1-2 | test | installer生成契約 | `test(auth): define AnnesAuth installer contract` | `b0f2622` | changed | legacy initializerがある場合の二重生成防止も追加。 |
| 1-3 | test | event・legacy schema移行契約 | `test(auth): cover AnnesAuth event and schema migration` | `b0f2622` | changed | 既存bootstrap claimと認証コードの互換性も回帰テスト化。 |
| 1-4 | verify | 改名前コードに対する失敗確認 | - | - | skipped | 改名前の作業ツリーを再構成せず、変更後の公開契約を直接検証。 |

### Task 2: gem・Ruby名前空間・Engine内部識別子を改名する

| ID | 種別 | 内容 | 対応コミット（予定） | 実績コミット | 状態 | メモ |
|---|---|---|---|---|---|---|
| 2-1 | impl | package・namespace・autoload path改名 | `refactor(auth): rename package and namespace to AnnesAuth` | `b0f2622` | done |  |
| 2-2 | impl | generator・設定・event改名 | `refactor(auth): rename generated and public identifiers` | `b0f2622` | done |  |
| 2-3 | impl | bootstrap claim tableのforward migration | `feat(auth): migrate bootstrap claims to AnnesAuth prefix` | `b0f2622` | done |  |
| 2-4 | impl | audit mapperを新eventへ追従 | `refactor(audit): follow AnnesAuth event rename` | `b0f2622` | done |  |

### Task 3: 3つのexample appをAnnesAuthへ移行する

| ID | 種別 | 内容 | 対応コミット（予定） | 実績コミット | 状態 | メモ |
|---|---|---|---|---|---|---|
| 3-1 | test | host integration・schema upgrade test | `test(examples): define AnnesAuth host integration` | `b0f2622` | changed | 既存統合テストを新名前空間へ移行し、3 appのmigrationを実適用。 |
| 3-2 | impl | gem・initializer・mount・code参照移行 | `refactor(examples): migrate authentication to AnnesAuth` | `b0f2622` | done |  |
| 3-3 | impl | example migration・schema更新 | `refactor(examples): apply AnnesAuth schema transition` | `b0f2622` | done | `annes_auth_bootstrap_claims` 作成migrationとschema snapshotを追加。 |
| 3-4 | verify | 3 example app test | - | - | done | customer 18/72、reservation 92/650、restaurant 30/238。 |

### Task 4: Auth文書・CI・公開設定を更新して検証する

| ID | 種別 | 内容 | 対応コミット（予定） | 実績コミット | 状態 | メモ |
|---|---|---|---|---|---|---|
| 4-1 | test | CI・release・policy契約 | `test(repo): define AnnesAuth automation contract` | `b0f2622` | done |  |
| 4-2 | impl | CI・publish・release metadata切替 | `ci(auth): switch automation to annes_auth` | `b0f2622` | done |  |
| 4-3 | docs | README・CHANGELOG・UPGRADING更新 | `docs(auth): document AnnesAuth migration` | `b0f2622` | done | 旧0.x履歴はAnneAuth表記のまま保存。 |
| 4-4 | verify | Engine・examples・root tests・gem build | - | - | done | AnnesAuth 109/944、root検査、3 example、gem buildが成功。 |

## 計画差分ログ

| 日時 | 変更内容 | 理由 | 承認者 |
|---|---|---|---|
| 2026-08-26 | 初版作成 | Annes Engine全面改名のPlan 1 |  |
| 2026-08-26 | 複数予定コミットを `b0f2622` に統合 | package/namespace renameを常時load可能な中間状態で行うため | Codex |
| 2026-08-26 | 旧認証コードsaltを維持し、exampleにbootstrap table作成migrationを追加 | 独立レビューで確認された実データ互換性とfresh example schemaの不足を解消 | Codex |

## 最終確認

- [x] 全Taskの状態を更新した
- [x] `changed / skipped` の理由を記載した
- [x] 変更を伴うサブタスクの実績コミットを記録した
- [x] 必要なテスト、gem build、license検査を完了した
- [x] Plan内の全Taskが同じheadブランチに含まれている
- [x] head/baseブランチが計画どおりである
- [ ] このPlanに対応するPRが1つだけ作成または更新されている（GitHub CLI認証の復旧待ち）
- [ ] 実施内容、テスト結果、stack内の依存関係をPR要約に反映した（PR作成時に実施）
