# Upgrading AnnesInquiry

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
