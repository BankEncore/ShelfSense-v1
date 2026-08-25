# Development guide

ShelfSense uses a Docker-only local development workflow. Ruby, Rails, Bundler, PostgreSQL, gems, and project utilities run in containers; they do not need to be installed on the host.

## Supported host environment

The current development setup targets:

- Mac with Apple Silicon
- Docker Desktop for Mac
- VS Code on the host
- Git

The images are multi-platform. Do not force `platform: linux/amd64` on Apple Silicon, because doing so replaces native ARM execution with slower emulation.

## Development services

Docker Compose defines two services:

| Service | Purpose |
|---|---|
| `web` | Ruby 3.4, Rails, gems, and application commands |
| `db` | PostgreSQL 17 |

Named volumes persist:

| Volume | Purpose |
|---|---|
| `bundle` | Installed Ruby gems |
| `postgres-data` | PostgreSQL data |

The source repository is bind-mounted at `/app`, so edits made in VS Code are immediately visible to Rails.

## Initial setup

From the repository root:

```sh
docker compose build
docker compose run --rm web bin/setup --skip-server
docker compose up
```

Open <http://localhost:3000>. Verify application health at <http://localhost:3000/up>.

Use `docker compose up -d` to run in the background and `docker compose down` to stop the services without deleting their data volumes.

## Run application commands

Use the project-local helper:

```sh
./dev/rails-docker COMMAND [ARGUMENTS...]
```

If the `web` service is running, the helper executes the command in that container. Otherwise, it starts a temporary `web` container and removes it afterward.

Examples:

```sh
./dev/rails-docker ruby --version
./dev/rails-docker bundle install
./dev/rails-docker bin/rails console
./dev/rails-docker bin/rails routes
./dev/rails-docker bin/rails db:prepare
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails db:rollback
```

Prefer committed `bin/` executables, such as `bin/rails` and `bin/rubocop`, when they exist.

## Database configuration

Docker Compose supplies these development values:

| Variable | Value |
|---|---|
| `DATABASE_HOST` | `db` |
| `DATABASE_PORT` | `5432` |
| `DATABASE_USERNAME` | `postgres` |
| `DATABASE_PASSWORD` | `postgres` |
| `DATABASE_NAME` | `shelfsense_development` |
| `TEST_DATABASE_NAME` | `shelfsense_test` |

The `db` hostname is the Compose service name and is reachable from the `web` container. From the Mac host, the published PostgreSQL port is `localhost:5432`, but host-side Ruby and Rails commands are not part of the supported workflow.

The PostgreSQL image applies `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB` only when initializing an empty data volume. Changing those values in `compose.yml` does not rewrite an existing database volume.

Do not commit production credentials. Production values must come from the deployment environment. The ERB in `config/database.yml` must not use strict `ENV.fetch` calls without defaults for production-only variables, because Rails evaluates the entire file before selecting an environment; strict production lookups would also break development and CI startup.

Optional catalog enrichment (Phase 9) reads `ISBNDB_API_KEY` from the environment. Leave it unset in CI; tests stub the HTTP client. For local live lookups, copy `.env.example` to `.env` (gitignored) and set the key. Docker Compose interpolates it into the `web` service. Recreate that service after changing `.env` (`docker compose up -d --force-recreate web`). Never commit the key, a filled `.env`, or `compose.override.yml`; never log the key or store it in audit events.

## Identifiers and migrations

Phase 1 domain tables use UUID primary keys without a PostgreSQL default. Rails assigns RFC 9562 UUIDv7 values in a shared `before_validation` callback (`SecureRandom.uuid_v7`) when `id` is blank. Prefer the migration helper:

```ruby
create_uuid_table :example_records do |t|
  t.references :store, null: false, type: :uuid, foreign_key: true
  t.timestamptz :created_at, null: false
  t.timestamptz :updated_at, null: false
end
```

Callback-bypassing APIs such as `insert_all` must supply IDs explicitly.

## Bootstrap a development installation

After `db:prepare` / `db:migrate`, initialize once:

```sh
./dev/rails-docker env \
  ORGANIZATION_NAME="Example Books" \
  STORE_NUMBER=1 \
  STORE_CODE=main \
  STORE_NAME="Main Store" \
  STORE_LEGAL_NAME="Example Books LLC" \
  STORE_TIMEZONE=America/New_York \
  STORE_COUNTRY_CODE=US \
  ADMIN_USERNAME=admin \
  ADMIN_DISPLAY_NAME="Admin User" \
  ADMIN_PASSWORD='ChangeMe123!' \
  bin/rails shelfsense:bootstrap
```

Do not commit real passwords. Bootstrap is concurrency-safe and sets `system_settings.initialized_at` only on success.

After pulling catalog changes (for example Phase 2 permission keys), re-seed permissions and system role grants on an already-initialized database:

```sh
./dev/rails-docker bin/rails shelfsense:seed_permissions
```

## Tests and validation

Run the Rails test suite:

```sh
./dev/rails-docker bin/rails test
./dev/rails-docker bin/rails test:system
./dev/rails-docker bin/ci
```

System tests and `bin/ci` start a throwaway `web` container so they use Chromium from the image even when `docker compose up` is already serving. Rebuild after pulling Dockerfile changes: `docker compose build`. If system tests still fail with “Linux arm64 is not supported yet by chrome”, the running image is stale — rebuild, then rerun `./dev/rails-docker bin/rails test:system`.

Run the other checks enforced by CI:

```sh
./dev/rails-docker bin/rubocop
./dev/rails-docker bin/brakeman --no-pager
./dev/rails-docker bin/bundler-audit
```

GitHub Actions uses its own Ruby runner and PostgreSQL service, then invokes the same committed `bin/` commands directly. See [Testing and CI](testing.md) for the active jobs.

## Rebuild and dependency changes

Rebuild the image after changing `Dockerfile.dev`, system packages, Ruby, or build arguments:

```sh
docker compose build
```

After changing the Gemfile or lockfile, either rebuild or install into the named gem volume:

```sh
./dev/rails-docker bundle install
```

Commit `Gemfile.lock` whenever dependency resolution changes.

## Reset local data

Ordinary shutdown preserves data:

```sh
docker compose down
```

To rebuild the development database through Rails while retaining the PostgreSQL volume:

```sh
./dev/rails-docker bin/rails db:reset
```

Deleting volumes permanently removes local PostgreSQL data and the cached gem volume. Use this only when that loss is intended:

```sh
docker compose down --volumes
```

After deleting volumes, rebuild and rerun the initial setup commands.

## Troubleshooting

### Rails cannot connect to PostgreSQL

Confirm both services exist and inspect their status:

```sh
docker compose ps
docker compose logs db
```

Inside the `web` container, `DATABASE_HOST` must be `db`, not `localhost`.

### PostgreSQL settings changed but nothing happened

The existing `postgres-data` volume retains the database initialized under the old settings. Either migrate or update that database deliberately, or delete the volume if the local data is disposable.

### Gems are missing after a Gemfile change

Run:

```sh
./dev/rails-docker bundle install
```

Rebuild the image when native packages or image-level dependencies changed.

### A stale server PID prevents startup

The Compose command removes `tmp/pids/server.pid` before starting Rails. If startup still fails, stop the services with `docker compose down`, inspect `tmp/pids`, and restart.

### File ownership is unexpected

The development image creates a non-root `rails` user with configurable `APP_UID` and `APP_GID`, both defaulting to 1000. If host permissions require different IDs, supply matching build arguments and rebuild the image.

### CI and local behavior differ

Confirm the committed Ruby version, Gemfile lockfile, and database schema are current. Local commands run in Docker, while CI provisions Ruby and PostgreSQL on the GitHub runner; both should use the repository's committed executables and configuration.
