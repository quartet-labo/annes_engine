# 実装チェックリスト: AnnesAdminへのgem・名前空間移行

## 対応Plan / PR

- Plan: `./plan-3.md`
- Topic: `20260826_1_annes-engine-rename`
- PR単位: Plan 3全体で1 PR

## PR / stack記録

| 項目 | 計画 | 実績 |
|---|---|---|
| headブランチ | `refactor/annes-admin` | `refactor/annes-admin` |
| baseブランチ | `refactor/annes-access` | `refactor/annes-access` |
| 直下の依存Plan | Plan 2 |  |
| stack位置 | middle |  |
| PR | 未作成 |  |
| マージ順 | 3番目 |  |

## ステータス定義

- `planned`: 計画済み（未着手）
- `done`: 計画どおり完了
- `changed`: 計画から変更して実施（理由を記載）
- `skipped`: 未実施 / 不要化（理由を記載）

## Task別チェック

### Task 1: Admin改名の公開契約をテストで固定する

| ID | 種別 | 内容 | 対応コミット（予定） | 実績コミット | 状態 | メモ |
|---|---|---|---|---|---|---|
| 1-1 | test | load・constant・Engine契約 | `test(admin): define AnnesAdmin package contract` | `45dcf70` | done | 新gem・定数・旧load path非公開を確認 |
| 1-2 | test | installer・mount契約 | `test(admin): define AnnesAdmin installer contract` | `45dcf70` | done | legacy initializerがある場合の二重生成も防止 |
| 1-3 | test | extension path・event契約 | `test(admin): cover AnnesAdmin host extension points` | `45dcf70` | done | asset、route、audit eventを更新 |
| 1-4 | verify | 改名前コードに対する失敗確認 | - | `45dcf70` | done | package-boundary testで旧契約を拒否 |

### Task 2: Admin package・namespace・公開extension pointを改名する

| ID | 種別 | 内容 | 対応コミット（予定） | 実績コミット | 状態 | メモ |
|---|---|---|---|---|---|---|
| 2-1 | impl | package・namespace・autoload path改名 | `refactor(admin): rename package and namespace to AnnesAdmin` | `45dcf70` | done | `annes_admin` / `AnnesAdmin` に統一 |
| 2-2 | impl | route・resource・view・asset・generator改名 | `refactor(admin): rename host extension points` | `45dcf70` | done | CSS class、initializer、host override pathを移行 |
| 2-3 | impl | audit event・mapper追従 | `refactor(audit): follow AnnesAdmin event rename` | `45dcf70` | done | mapper file名もレビュー指摘により整合 |
| 2-4 | verify | Engine・UI・DSL・notification test | - | `45dcf70` | done | AnnesAdmin 68 runs、AnnesAudit 28 runsが成功 |

### Task 3: 3つのexample appをAnnesAdminへ移行する

| ID | 種別 | 内容 | 対応コミット（予定） | 実績コミット | 状態 | メモ |
|---|---|---|---|---|---|---|
| 3-1 | test | host admin integration test | `test(examples): define AnnesAdmin host integration` | `45dcf70` | done | 既存統合テストを新契約へ更新 |
| 3-2 | impl | gem・routes・initializer・resource移行 | `refactor(examples): migrate administration to AnnesAdmin` | `45dcf70` | done | 3 example appの依存・route・initializerを切替 |
| 3-3 | impl | host extension path移行 | `refactor(examples): migrate AnnesAdmin extension paths` | `45dcf70` | done | layouts と asset logical pathを移行 |
| 3-4 | verify | 3 example app test | - | `45dcf70` | done | 18/72、92/650、30/238 assertionsで成功 |

### Task 4: Admin文書・CI・公開設定を更新して検証する

| ID | 種別 | 内容 | 対応コミット（予定） | 実績コミット | 状態 | メモ |
|---|---|---|---|---|---|---|
| 4-1 | test | CI・release・policy契約 | `test(repo): define AnnesAdmin automation contract` | `45dcf70` | done | CI target と publish workflow testを更新 |
| 4-2 | impl | CI・publish・release metadata切替 | `ci(admin): switch automation to annes_admin` | `45dcf70` | done | release helper、workflow、selectorを切替 |
| 4-3 | docs | README・CHANGELOG・UPGRADING更新 | `docs(admin): document AnnesAdmin migration` | `45dcf70` | done | 1.0.0 breaking change手順を記載 |
| 4-4 | verify | Engine・examples・root tests・gem build | - | `45dcf70` | done | root checksと `annes_admin-1.0.0.gem` build成功 |

## 計画差分ログ

| 日時 | 変更内容 | 理由 | 承認者 |
|---|---|---|---|
| 2026-08-26 | 初版作成 | Annes Engine全面改名のPlan 3 |  |
| 2026-08-26 | AnnesAdmin asset pathをPropshaft初期化前に登録 | engine configにはassets APIが常に存在しないため | Codex |
| 2026-08-26 | AnnesAdmin audit mapperのファイル名を追従 | 独立レビューでrequire不一致を検出 | Codex |

## 最終確認

- [x] 全Taskの状態を更新した
- [x] `changed / skipped` の理由を記載した
- [x] 変更を伴うサブタスクの実績コミットを記録した
- [x] 必要なテスト、gem build、license検査を完了した
- [x] Plan内の全Taskが同じheadブランチに含まれている
- [x] baseが `refactor/annes-access` である
- [ ] このPlanに対応するPRが1つだけ作成または更新されている
- [ ] 実施内容、テスト結果、stack依存をPR要約に反映した
