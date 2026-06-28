# Changelog

## Unreleased

- Default admin sessions to `AnneAuth::AdminSession` so host apps no longer need a top-level `Session` wrapper.
- Keep `config.admin_session_class_name = "Session"` available for host apps that intentionally retain a custom wrapper.

## 0.1.0

- Initial in-repository Rails Engine extraction.
- Prepared gem metadata and package-boundary checks for private git gem extraction.
