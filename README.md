# AnneAuth

AnneAuth is a Rails Engine for reusable account authentication. It provides account models, session handling, email verification, password resets, Google OAuth support, controller concerns, and host hooks.

This engine is currently developed inside the host application as a path gem:

```ruby
gem "anne_auth", path: "engines/anne_auth"
```

Run the engine-focused test suite from the host application:

```sh
bin/rails test engines/anne_auth/test
```

## Installation

Add the engine to the host app:

```ruby
gem "anne_auth", git: "git@example.com:org/anne_auth.git"
```

For in-repository development, use the path gem form shown above.

Run the installer:

```sh
bin/rails generate anne_auth:install
```

The generator copies:

- `config/initializers/anne_auth.rb`
- `config/routes/anne_auth.rb`
- authentication migrations under `db/migrate`

Review the route example and either mount the Engine or keep thin host
controllers that inherit the Engine controllers when existing path helper names
must be preserved.

## Host Hooks

Use `AnneAuth.configure` to keep application-specific behavior outside the
Engine:

```ruby
AnneAuth.configure do |config|
  config.after_account_login_path = ->(controller, _account) { controller.root_path }
  config.account_profile_path = ->(controller, _account) { controller.root_path }
  config.profile_complete = ->(account) { true }
  config.after_account_created = ->(account, controller) {}
end
```

The host app should keep domain models such as customers, projects, orders, or
quotes outside this Engine and connect them through hooks or thin host
controllers.

## Google OAuth

Set these environment variables when Google login is enabled:

- `GOOGLE_OAUTH_CLIENT_ID`
- `GOOGLE_OAUTH_CLIENT_SECRET`

The callback path is `/auth/google_oauth2/callback` when the Engine is mounted
at `/`.
