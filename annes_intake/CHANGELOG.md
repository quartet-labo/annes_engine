# Changelog

## 0.1.0

- Introduce an independent intake Engine with owned forms, versioned flows, branches and read-only value mappings.
- Add authorized drafts, attachment retention, resume and atomic response finalization.
- Provide standalone and combined installation checks and explicit portable schema import.

- 同一受付への追加質問、案件専用の質問編集、発行・取消・期限・回答履歴を追加。
- 初回adapterの`persist_follow_up!`へ原子的に保存し、各回のResponse原本を独立して保持。
- root/responseのscope確認、専用定義の編集境界、発行時digest競合検知、並行操作の直列化を追加。
- Plan5の配布gemから追加migrationだけで更新し、既存回答・添付を保持する検証を追加。
