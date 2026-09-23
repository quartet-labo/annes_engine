# Changelog

## 0.1.0

- 新規フォーム・フローと初版を同一transaction内で認可し、権限外の保存を取り消す。
- 管理履歴・項目一覧・プレビュー・フロー詳細に子定義の閲覧scopeを適用する。

- Introduce an independent intake Engine with owned forms, versioned flows, branches and read-only value mappings.
- Add authorized drafts, attachment retention, resume and atomic response finalization.
- Provide standalone and combined installation checks and explicit portable schema import.
