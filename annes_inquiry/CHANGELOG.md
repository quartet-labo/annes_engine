# Changelog

## Unreleased

- 条件グループによる複数分岐、読み取り専用の回答引継ぎ、経路変更時の再確認、管理editorと共通previewを追加。

- Add versioned multi-form intake flows with authenticated draft/resume, retained attachments, and atomic finalization.
- Add participant and admin flow screens, scoped answer access, and per-flow notification recovery.
- Preserve standalone adapters; exclude flow receipts from standalone administration.

## 0.1.0

- Extract the inquiry engine from anne-mark into this repository as an independent package.
- Preserve the AnnesInquiry API, table names, five migration sources, and host adapter contracts.
- Include versioned form administration, typed answers, validation, submission replay protection,
  shared attachments, notification requests, and cleanup services.
- Add standalone PostgreSQL and browser tests, package metadata, and GitHub Packages release support.
- Stop public submission processing when the context hook renders or redirects a denial.
- Reject excessive attachment counts before inspecting or hashing file contents.
- Constrain the runtime JSON dependency below 3 so fresh hosts can verify submission tokens with Rails 8.1.
- Test the built package in a fresh host without the development lockfile, including installed migrations and public submissions.
- Reject NUL characters in text input and adapter-enriched text with a field error and HTTP 422 before persistence.
