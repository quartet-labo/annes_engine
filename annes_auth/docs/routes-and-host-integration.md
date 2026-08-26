# AnnesAuth Routes and Host Integration

AnnesAuth is an isolated Engine. Mount it to use its default controllers and
views, or inherit selected controllers in the host when existing route names
must remain stable.

## Mounting the Engine

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount AnnesAuth::Engine => "/"
end
```

Mounting at `/auth` instead prefixes every path below with `/auth`. The route
helpers remain Engine helpers and can be reached through the mount proxy or
`AnnesAuth::Engine.routes.url_helpers`, depending on the calling context.

The install generator creates `config/routes/annes_auth.rb` as a reviewed
example; it does not modify the host's main route file automatically.

## Engine Routes

Paths in this table assume the Engine is mounted at `/`.

| Method | Path | Helper | Controller action |
| --- | --- | --- | --- |
| GET | `/login` | `account_login_path` | `accounts/sessions#new` |
| POST | `/account_session` | `account_session_path` | `accounts/sessions#create` |
| GET, POST | `/auth/:provider/callback` | `account_omniauth_callback_path` | `accounts/omniauth_callbacks#create` |
| GET, POST | `/auth/failure` | none | `accounts/omniauth_callbacks#failure` |
| GET | `/invitation?token=...` | `account_invitation_path` | `accounts/invitations#show` |
| GET | `/invitation/edit` | `edit_account_invitation_path` | `accounts/invitations#edit` |
| PATCH, PUT | `/invitation` | `account_invitation_path` | `accounts/invitations#update` |
| GET | `/password_reset/new` | `new_account_password_reset_path` | `accounts/password_resets#new` |
| POST | `/password_reset` | `account_password_reset_path` | `accounts/password_resets#create` |
| GET | `/password_reset/edit` | `edit_account_password_reset_path` | `accounts/password_resets#edit` |
| PATCH, PUT | `/password_reset` | `account_password_reset_path` | `accounts/password_resets#update` |
| GET | `/logout/confirm` | `account_logout_confirm_path` | `accounts/sessions#confirm` |
| DELETE | `/logout` | `account_logout_path` | `accounts/sessions#destroy` |
| GET | `/signup` | `new_account_registration_path` | `accounts/registrations#new` |
| POST | `/account_registration` | `account_registration_path` | `accounts/registrations#create` |
| GET | `/email_verification/pending` | `account_email_verification_pending_path` | `accounts/email_verifications#pending` |
| GET | `/email_verification` | `account_email_verification_path` | `accounts/email_verifications#show` |
| POST | `/email_verification` | none | `accounts/email_verifications#create` |
| POST | `/email_verification/verify` | `account_email_verification_verify_path` | `accounts/email_verifications#verify` |
| POST | `/email_verification/resend` | `account_email_verification_resend_path` | `accounts/email_verifications#resend` |

Use the named helpers instead of hard-coded paths. The private `auth_route`
helper used by Engine concerns looks for a helper on the current controller,
then `main_app`, and finally the Engine route set.

## Invitation Activation

Invitation issuance is not an Engine route. A trusted host job or management
operation calls `AnnesAuth::Accounts::InvitationDelivery.call(account)`, which
sends a URL for the token-bearing `GET /invitation` entry.

The entry request validates the token without consuming it, stores only the
invitation record ID in the encrypted Rails session, and returns `303 See Other`
to `GET /invitation/edit`. The edit URL and form do not contain the plaintext
token. Password validation errors return `422 Unprocessable Entity` and keep the
same invitation session available for correction.

Successful `PATCH /invitation` changes the password, marks the email verified,
and invalidates outstanding invitation, password-reset, verification, and
account-session credentials in one transaction. It redirects to login with
`303 See Other` and does not automatically authenticate the account.

When the Engine is mounted at `/auth`, these paths become
`/auth/invitation`, `/auth/invitation/edit`, and `/auth/invitation` respectively.
Keep the configured `account_invitation_url` aligned with the actual mount path.

## Initial Account Bootstrap

Bootstrap does not add an Engine route. A trusted host setup path calls
`AnnesAuth::Accounts::BootstrapInvitation.call(email:)`; the service creates the
first unverified account when no active account exists and then uses the same
invitation activation route described above.

Do not mount a public bootstrap controller that accepts arbitrary email
addresses. If a host wants an operator-facing setup screen, keep authentication,
authorization, CSRF protection, rate limiting, and audit behavior in the host
app and call the service from that protected action.

## Adding Authentication to Host Controllers

Include the concern in the host controller that owns protected actions:

```ruby
class ApplicationController < ActionController::Base
  include AnnesAuth::AccountAuthentication
end

class ProjectsController < ApplicationController
  before_action :require_verified_account

  def index
    @projects = Project.all
  end
end
```

The concern exposes these helpers to controllers and views:

- `current_account`
- `account_authenticated?`
- `account_profile_complete?`

It also provides controller methods for filters and authentication flows:

- `require_account_authentication`
- `require_verified_account`
- `start_new_account_session_for(account)`
- `terminate_account_session`

These methods are private controller APIs. Call them as filters or from
controller code, not on controller instances from unrelated objects.

## Protection Levels

Choose the protection level deliberately:

| Filter | Requires session | Requires verified email | Requires complete host profile |
| --- | --- | --- | --- |
| `require_account_authentication` | yes | no | no |
| `require_verified_account` | yes | yes | yes, through `profile_complete` |

`require_verified_account` performs the checks in order. An unauthenticated
request is redirected to login, an unverified account is redirected to the
pending verification page, and an incomplete profile is redirected to
`account_profile_path`. It returns false after a redirect so a filter chain can
stop the action.

Use the session-only filter only for screens that intentionally allow an
unverified account, such as an onboarding or verification support screen.

## Redirect Behavior

- Successful password login creates a session. Verified accounts go to
  `after_account_login_path`; unverified accounts go to the pending page.
- An already authenticated verified account visiting login, signup, or pending
  verification is redirected to `after_account_login_path`.
- Successful code verification uses `after_account_email_verification_path`.
- Host profile completion can use `after_account_profile_completion_path`.

All path hooks receive the controller and account. Use `controller.main_app`
for host route helpers from a mounted Engine.

## Thin Host Controllers

Use host controllers when an existing application must preserve controller
names, route helper names, or selected overrides:

```ruby
class Accounts::SessionsController < AnnesAuth::Accounts::SessionsController
  private
    def after_account_authentication_url
      dashboard_path
    end
end
```

Route only the required endpoints to the host subclass. Keep the inherited
flow thin and prefer configuration hooks when a path or lifecycle callback is
the only difference. Test both route resolution and redirects because Engine
controllers and host controllers have different helper lookup contexts.

## Overriding the Login View or Layout

The standard credential login form is protected from repeated submissions by a
small package-local script. If the host overrides
`annes_auth/accounts/sessions/new`, keep the
`data-annes-auth-submit-guard` attribute on the email/password form. Do not add
it to OAuth, registration, password-reset, invitation, or host-specific forms
unless the host intentionally owns their submission behavior.

If the host overrides `layouts/annes_auth`, render the guard once:

```erb
<%= render "layouts/annes_auth/submit_guard" %>
```

The partial emits a CSP nonce-bearing inline script. It listens for the
constraint-validation-aware `submit` event, allows the initial request, and
blocks later submits while the form is busy. It also restores only the state it
changed on `pageshow` and `turbo:submit-end`. Re-evaluating the partial does not
register duplicate listeners.

## Host Account Classes

The default `AnnesAuth::Account` owns generic authentication behavior. A host can
subclass it to add profile behavior while retaining the default tables:

```ruby
class Account < AnnesAuth::Account
  has_one :account_profile, dependent: :destroy
end

AnnesAuth.configure do |config|
  config.account_class_name = "Account"
  config.profile_complete = ->(account) { account.account_profile.present? }
  config.account_profile_path = ->(controller, _account) {
    controller.main_app.new_account_profile_path
  }
end
```

Keep customers, projects, orders, roles, and other domain concepts in the host.
AnnesAuth runtime code must not reference host constants. See the
[configuration reference](configuration.md) before changing table or token
model mappings.

## Testing an Integration

At minimum, cover:

- unauthenticated requests preserve the return path and redirect to login;
- unverified accounts cannot reach verified-only screens;
- profile-incomplete accounts use the configured profile path;
- mounted and host-owned routes resolve the expected helpers;
- login, logout, verification, and password-reset redirects use host hooks.
- bootstrap is exercised from trusted host code and does not expose a public route.
