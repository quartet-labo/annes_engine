# Changelog

## Unreleased

## 1.0.0

- Rename the gem from `anne_access` to `annes_access` and the Ruby namespace from `AnneAccess` to `AnnesAccess`.
- Rename generated initializer and seed files, public API examples, and runtime table names to the `annes_access` prefix; old require paths and constants are not retained.
- Add a forward migration that renames roles, permissions, role permissions, assignments, and their branded indexes while retaining rows and foreign-key relationships.

- Add a role and permission template guide for host-scoped RBAC matrix design.
- Restructure the generated seed example around a `role_permissions` matrix and
  clarify that tenant, owner, and membership record scopes remain host-app
  responsibilities.

## 0.1.2

- Add RBAC setup, configuration/API, record-scoping, AnnesAdmin integration, and
  security guides, and expand the README into a complete allow/deny quick start.

## 0.1.1

- Add configurable authorization principal resolution for controller helpers.
- Clarify that record-level scopes and business visibility rules belong in the
  host application.

## 0.1.0

- Initial lightweight RBAC engine with roles, permissions, assignments, Ability API, controller helpers, and install generator.
