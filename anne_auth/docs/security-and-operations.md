# AnneAuth Security and Operations

Use this guide when preparing a host application for production. AnneAuth
provides secure defaults, but the host owns cache, mail delivery, URL host,
credentials, monitoring, and deployment configuration.

## Sessions and Cookies

Successful authentication creates an `AnneAuth::AccountSession` and a signed
cookie containing the session ID. Defaults are:

- database and cookie expiry: two weeks;
- `httponly: true`;
- `same_site: :lax`;
- `secure: true` for SSL requests or production;
- user agent and remote IP stored on the session;
- `last_used_at` refreshed as the session is used.

Expired sessions and sessions belonging to disabled accounts are rejected,
deleted, and removed from the browser on the next request. Configure HTTPS in
production and do not disable secure cookies to work around a proxy problem;
fix forwarded-protocol handling instead.

```ruby
config.account_session_expires_in = 2.weeks
config.account_session_cookie_secure = ->(request) {
  request.ssl? || Rails.env.production?
}
```

Password reset destroys the account's active sessions and expires outstanding
reset tokens. Treat that behavior as part of credential rotation when testing
custom account or session classes.

## Controller Rate Limits

Authentication endpoints use Rails controller rate limits. Current limits
include both request-level and normalized-email keys where applicable:

| Flow | Limit |
| --- | --- |
| Password login | 10 attempts per 3 minutes, and 5 per normalized email per 15 minutes |
| Registration | 5 attempts per 10 minutes, and 3 per normalized email per 30 minutes |
| Password-reset request | 5 attempts per 10 minutes, and 3 per normalized email per 30 minutes |
| Verification resend/create | 3 attempts per normalized account/email key per 10 minutes |

Rails stores these counters in `Rails.cache`. A process-local memory store does
not coordinate limits across workers or servers. Configure a shared
`ActiveSupport::Cache` store, such as Redis or Solid Cache, before horizontally
scaling the host.

Monitor rate-limit responses without logging passwords, reset tokens,
verification codes, OAuth credentials, or full session cookies.

## Email Verification Codes

Verification codes are six digits, expire after 15 minutes, and allow at most
five failed attempts for the active token. Codes are stored as an HMAC digest,
not plaintext. Issuing a new code marks earlier active codes used.

The digest key is derived from the Rails application key generator and
`account_verification_digest_salt`. Rotating the Rails secret or the configured
salt invalidates outstanding verification codes.

Successful verification marks the token used and sets `email_verified_at` on
the account. Host screens that require verified email should use
`require_verified_account`.

## Password Reset Tokens

Password-reset tokens are generated from 32 random bytes, stored as SHA-256
digests, and expire after one hour. Issuing a new token expires previous active
tokens for the account. A successful reset marks all active reset tokens used
and destroys the account's sessions.

Set the correct URL host and protocol for mailers:

```ruby
# config/environments/production.rb
config.action_mailer.default_url_options = {
  host: "app.example.com",
  protocol: "https"
}
```

If the host uses custom password-reset routes, configure
`account_password_reset_url` to return the absolute URL sent in mail.

## Account Invitation Tokens

Invitation tokens are generated from 32 random bytes, stored only as SHA-256
digests, and expire after one hour. Issuing or retrying an invitation marks the
previous active invitation used. Only persisted, active, unverified accounts are
eligible. The trusted `InvitationDelivery` service returns only `:delivered`,
`:invalid_account`, or `:delivery_failed`; it never returns the plaintext token.

Following the token-bearing GET validates but does not consume the invitation,
so automated email-link scanners cannot complete activation. After that entry,
only the invitation record ID is stored in the encrypted Rails session and the
browser is redirected to a URL without the token. Activation success updates
the password and email-verification state in one transaction, invalidates all
outstanding invitation/reset/verification tokens and account sessions, and does
not create a replacement login session.

Invitation responses set `Referrer-Policy: no-referrer`, and AnneAuth adds
`token` to the Rails parameter filter. These controls protect Rails request
parameters and downstream navigation, but they cannot sanitize logs written
upstream before Rails handles the request.

Reverse proxies, ingress controllers, load balancers, CDNs, and platforms such
as Cloud Run may record the original request URL, including its query string.
For the token-bearing invitation entry:

- disable, exclude, or sanitize request-URL logging at every upstream layer
  where the platform supports it;
- avoid copying query strings into analytics, tracing, error reports, or audit
  payloads;
- use the shortest operationally acceptable retention period for unavoidable
  request logs;
- grant log access with least privilege and review that access periodically;
- verify the deployed logging path with a disposable invitation before launch.

If an invitation URL may have been exposed, resend the invitation to invalidate
the old token and review access to the affected logs. Do not rely on Rails
parameter filtering or `Referrer-Policy` as protection for proxy/platform logs.

## Initial Account Bootstrap

`AnneAuth::Accounts::BootstrapInvitation.call(email:)` is for trusted setup
code only. It creates one unverified account with a random temporary password,
records an `anne_auth_bootstrap_claims` row for the `initial_account` purpose,
and sends the standard invitation activation email. The person still sets their
real password through the scanner-safe invitation flow.

Operational rules:

- run the bootstrap claim migration before using the service;
- call the service from a protected job, console command, or seed task, not from
  a public route;
- use `after_account_bootstrapped` for host-owned role or assignment setup;
- let hook failures roll back account creation before email delivery;
- retry `:delivery_failed` after fixing mail delivery; the same bootstrap
  account is reused and the previous invitation token is invalidated;
- treat `:already_bootstrapped` as terminal unless the host intentionally resets
  the environment.

The bootstrap claim prevents duplicate initial accounts. It does not manage
administrator status, roles, permissions, organizations, or audit storage.

## Account Event Notifications

AnneAuth emits `anne_auth.account_event` notifications for successful sign in,
sign out, password reset request/completion, email verification, invitation
sent, and invitation accepted events. Invalid login attempts, missing password
reset emails, and invalid tokens do not emit account-specific events.

Payloads exclude passwords, reset tokens, invitation tokens, verification
codes, session cookies, and OAuth credentials. They can include account email,
IP address, and user agent, so hosts should decide retention, access control,
and redaction before writing them to durable storage.

Subscribers run inline under Rails notification semantics. Keep them fast or
enqueue a job. If durable audit persistence is mandatory, decide explicitly
whether a subscriber error should fail the authentication request; do not treat
the notification stream alone as a complete audit ledger without testing that
failure mode.

## MFA and TOTP Boundary

AnneAuth 0.4.0 does not implement MFA/TOTP runtime behavior. A future minimal
implementation should be planned separately because it affects session
assurance, recovery, enrollment, and login UX. The expected follow-up design
scope is:

- step-up verification after primary sign in;
- session metadata for MFA completion time and assurance level;
- TOTP secret and recovery-code storage with rotation;
- remember-device policy, if needed by the host;
- account events that expose non-secret assurance metadata.

## Mail Delivery

Replace the default sender and verify the host's delivery adapter:

```ruby
AnneAuth.configure do |config|
  config.mailer_from = "accounts@example.com"
end
```

Production smoke tests should verify delivery and links for verification,
password reset, and invitation activation. Do not include plaintext codes or
tokens in application logs, error reports, analytics, or audit payloads.

## Google OAuth

Credentials alone do not enable OAuth. AnneAuth requires the feature flag,
client ID, and client secret. Keep OmniAuth request validation enabled:

```ruby
OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.request_validation_phase = AnneAuth::OmniauthTokenVerifier.new

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    ENV.fetch("GOOGLE_OAUTH_CLIENT_ID"),
    ENV.fetch("GOOGLE_OAUTH_CLIENT_SECRET")
end
```

Start OAuth with a POST request. The Engine accepts GET or POST at the callback
route for provider compatibility, but the request phase should remain POST-only
and protected by OmniAuth validation. When OAuth is disabled or incompletely
configured, the callback returns to login without creating a session.

Review the provider console whenever the Engine mount path or application host
changes. The callback is `/auth/google_oauth2/callback` when mounted at `/` and
inherits the mount prefix otherwise.

## Account Disablement

`AnneAuth::Account.active` excludes rows with `disabled_at`, and session loading
rejects a disabled account. A host operation that disables an account should
also consider explicitly destroying existing sessions for immediate cleanup,
rather than waiting for each cookie to be presented.

## Production Checklist

- Use HTTPS and verify proxy SSL headers.
- Set a real `mailer_from` and production mailer URL options.
- Use a shared cache for rate limits in multi-process deployments.
- Store OAuth secrets in the deployment secret store.
- Verify the session expiration migration is installed.
- Verify the account invitation-token migration is installed.
- Verify the bootstrap claim migration is installed before running bootstrap.
- Exercise login, logout, verification, password reset, invitation activation, and disabled-account flows.
- Confirm sensitive parameters are filtered from logs.
- Confirm upstream request logs do not retain invitation query strings, or use minimal retention and access.
- Confirm account event subscribers do not store secrets and handle PII according to host policy.
- Monitor delivery failures and unusual rate-limit volume without storing secrets.
