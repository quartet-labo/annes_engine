# Changelog

## Unreleased

- Ship namespaced primary and secondary action styles from the Engine so button
  contrast no longer depends on the host Tailwind build scanning gem templates.
- Add explicit hover and keyboard-focus states to standard action controls.

## 0.2.1

- Hide standard `new` and `edit` links and member custom action buttons when
  the configured authorization hook rejects the action, while preserving
  server-side authorization for direct requests.
- Keep controller authorization enforcement independent from the view helper
  used to decide action visibility.
- Add Resource DSL, authentication/authorization, host customization,
  query/action/audit, and security guides, and expand the README quick start.
- Add GitHub Packages metadata, release instructions, and a host upgrade guide.

## 0.2.0

- Align release version with AnneAuth 0.2.0 for the monorepo tag.

## 0.1.0

- Initial reusable admin engine skeleton.
- Added resource registration DSL, typed fields, generic CRUD screens, custom actions, audit notifications, and install generator.
- Prepared gem metadata and package-boundary checks for private git gem extraction.
