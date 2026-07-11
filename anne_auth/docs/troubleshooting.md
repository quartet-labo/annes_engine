# AnneAuth Troubleshooting

## Route Helper Is Missing

**Symptom:** A controller or view raises `undefined method account_login_path`.

**Checks:**

1. Confirm `AnneAuth::Engine` is mounted in `config/routes.rb`.
2. Confirm whether the caller is inside the Engine or the host application.
3. Inspect the mount prefix and named mount proxy.

Use the Engine route proxy or `AnneAuth::Engine.routes.url_helpers` when calling
from a context that does not include Engine helpers. In configuration hooks,
use `controller.main_app` for host routes.

## Redirect Goes to the Wrong Host or Path

**Symptom:** Login or verification returns to `/`, or a mail link points at the
wrong domain.

**Checks:**

- Configure `after_account_login_path` and
  `after_account_email_verification_path` for browser redirects.
- Configure `account_password_reset_url` when using host-owned reset routes.
- Set `config.action_mailer.default_url_options` in each deployed environment.
- Include the Engine mount prefix in the OAuth provider callback URL.

## Login Works but the Next Request Is Logged Out

**Symptom:** A session row is created but the browser does not retain login.

**Checks:**

- Verify the request is HTTPS in production and forwarded-protocol headers are trusted.
- Inspect whether `account_session_cookie_secure` sets a secure cookie on an HTTP development URL.
- Confirm the `account_sessions.expires_at` migration is installed and populated.
- Confirm the account is not disabled and the session is not expired.
- Confirm every process uses the same Rails secret key base.

Do not disable secure cookies in production. Correct TLS termination and proxy
configuration instead.

## Rate Limits Differ Between Servers

**Symptom:** Repeated attempts are blocked only when they reach the same worker.

Configure a shared `Rails.cache` backend. Memory stores are process-local and
cannot enforce a global limit across workers, hosts, or rolling deployments.

## Verification Code Is Always Invalid

**Checks:**

- Only the newest issued code remains active.
- Codes expire after 15 minutes and stop after five failed attempts.
- The Rails secret key base and `account_verification_digest_salt` must be stable
  between issuance and verification.
- Copying a code with spaces or hyphens is supported, but other characters are not.

Issue a new code after secret rotation rather than attempting to recover an old
plaintext value; plaintext codes are not stored.

## Password-Reset Link Is Invalid

Password-reset tokens expire after one hour, are single-use, and are replaced
when a newer token is issued. Confirm the complete token survives URL encoding
and that the link reaches the same environment and database that issued it.

## Install Generator Skips a Migration

The generator skips a migration when a host migration with the same suffix
already exists. Compare the existing host migration with the current file under
`anne_auth/db/migrate` before continuing. A skipped filename does not prove the
schemas are equivalent.

Use the relevant section of [UPGRADING.md](../UPGRADING.md), then inspect the
host schema after `bin/rails db:migrate`.

## Custom Account Class Fails to Load

Model and association mappings are read when AnneAuth model classes load.
Configure custom class/table names during boot, define loadable constants, and
keep all related foreign keys and inverse associations consistent. See the
[configuration reference](configuration.md) and test every token/session flow.
