# 実装チェックリスト: AnnesAccessへのgem・名前空間移行

## 対応Plan / PR

- Plan: `./plan-2.md`
- Topic: `20260826_1_annes-engine-rename`
- PR単位: Plan 2全体で1 PR

## PR / stack記録

| 項目 | 計画 | 実績 |
|---|---|---|
| headブランチ | `refactor/annes-access` | `refactor/annes-access` |
| baseブランチ | `refactor/annes-auth` | `refactor/annes-auth` |
| 直下の依存Plan | Plan 1 |  |
| stack位置 | middle |  |
| PR | 未作成 | GitHub CLI認証トークンが無効のため未作成 |
| マージ順 | 2番目 |  |

## ステータス定義

- `planned`: 計画済み（未着手）
- `done`: 計画どおり完了
- `changed`: 計画から変更して実施（理由を記載）
- `skipped`: 未実施 / 不要化（理由を記載）

## Task別チェック

### Task 1: Access改名とlegacy schema upgrade契約をテストで固定する

| ID | 種別 | 内容 | 対応コミット（予定） | 実績コミット | 状態 | メモ |
|---|---|---|---|---|---|---|
| 1-1 | test | load・constant・Engine契約 | `test(access): define AnnesAccess package contract` |  | planned |  |
| 1-2 | test | installer生成契約 | `test(access): define AnnesAccess installer contract` |  | planned |  |
| 1-3 | test | legacy RBAC schema移行 | `test(access): cover AnnesAccess schema migration` |  | planned |  |
| 1-4 | verify | 改名前コードに対する失敗確認 | - | - | planned |  |

### Task 2: Access package・namespace・DB識別子を改名する

| ID | 種別 | 内容 | 対応コミット（予定） | 実績コミット | 状態 | メモ |
|---|---|---|---|---|---|---|
| 2-1 | impl | package・namespace・autoload path改名 | `refactor(access): rename package and namespace to AnnesAccess` |  | planned |  |
| 2-2 | impl | generator・設定・公開識別子改名 | `refactor(access): rename generated and public identifiers` |  | planned |  |
| 2-3 | impl | RBAC table・index・FK rename migration | `feat(access): migrate RBAC schema to AnnesAccess prefix` |  | planned |  |
| 2-4 | verify | package・model・migration test | - | - | planned |  |

### Task 3: example appのRBAC統合をAnnesAccessへ移行する

| ID | 種別 | 内容 | 対応コミット（予定） | 実績コミット | 状態 | メモ |
|---|---|---|---|---|---|---|
| 3-1 | test | host RBAC integration test | `test(examples): define AnnesAccess host integration` |  | planned |  |
| 3-2 | impl | gem・initializer・policy・seed移行 | `refactor(examples): migrate authorization to AnnesAccess` |  | planned |  |
| 3-3 | impl | example migration・schema更新 | `refactor(examples): apply AnnesAccess schema transition` |  | planned |  |
| 3-4 | verify | 3 example・seed test | - | - | planned |  |

### Task 4: Access文書・CI・公開設定を更新して検証する

| ID | 種別 | 内容 | 対応コミット（予定） | 実績コミット | 状態 | メモ |
|---|---|---|---|---|---|---|
| 4-1 | test | CI・release・policy契約 | `test(repo): define AnnesAccess automation contract` |  | planned |  |
| 4-2 | impl | CI・publish・release metadata切替 | `ci(access): switch automation to annes_access` |  | planned |  |
| 4-3 | docs | README・CHANGELOG・UPGRADING更新 | `docs(access): document AnnesAccess migration` |  | planned |  |
| 4-4 | verify | Engine・examples・root tests・gem build | - | - | planned |  |

## 計画差分ログ

| 日時 | 変更内容 | 理由 | 承認者 |
|---|---|---|---|
| 2026-08-26 | 初版作成 | Annes Engine全面改名のPlan 2 |  |
| 2026-08-26 | 実装を `1cb297f` に統合 | package/namespace rename、DB transition、example migrationを常時load可能な状態でまとめて適用 | Codex |
| 2026-08-26 | generatorに旧initializer・seedとの重複防止を追加 | 1.0.0移行時に旧設定を上書き・二重生成しないため | Codex |
| 2026-08-26 | レビュー指摘を反映 | release文書の旧package履歴を明示し、RBAC複合unique indexを回帰テスト化 | Codex |

## 実施結果

- Task 1〜4: `1cb297f` で完了。旧require非提供、installer、RBAC table/index/FKのup/down、3つのexample migration、CI/release/docsを更新した。
- 検証: AnnesAccess 30 runs / 120 assertions、customer 18 / 72、reservation 92 / 650、restaurant 30 / 238、repository docs/release tests、gem buildが成功。
- レビュー: 独立レビューでRBAC migration・example schema・旧require非提供を確認し、指摘3件を解消済み。
- PR: GitHub CLI認証トークンが無効のため、push/PR作成は認証復旧後に実施する。

## 最終確認

- [x] 全Taskの結果を実施結果に記録した
- [x] `changed / skipped` の理由を記載した
- [x] 変更を伴うサブタスクの実績コミットを記録した
- [x] 必要なテスト、gem build、license検査を完了した
- [x] Plan内の全Taskが同じheadブランチに含まれている
- [x] baseが `refactor/annes-auth` である
- [ ] このPlanに対応するPRが1つだけ作成または更新されている（GitHub CLI認証の復旧待ち）
- [ ] 実施内容、テスト結果、stack依存をPR要約に反映した（PR作成時に実施）
