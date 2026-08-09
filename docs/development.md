# Development guide

This guide describes the development workflow supported by the current ShelfSense repository. The project does not currently include Docker Compose or a development-container definition, so the documented setup runs Ruby and Rails directly on the development machine.

## Prerequisites

Install:

- Ruby 3.4.9
- Bundler
- PostgreSQL
- PostgreSQL client libraries and development headers required by the `pg` gem
- libvips for image processing

Confirm Ruby and PostgreSQL are available:

```sh
ruby --version
bundle --version
psql --version
```

## Database configuration

Development defaults to these local values:

| Variable | Default |
|---|---|
| `DATABASE_HOST` | `localhost` |
| `DATABASE_PORT` | `5432` |
| `DATABASE_USERNAME` | `postgres` |
| `DATABASE_PASSWORD` | `postgres` |
| `DATABASE_NAME` | `shelfsense_development` |
| `TEST_DATABASE_NAME` | `shelfsense_test` |
| `RAILS_MAX_THREADS` | `5` |

The defaults are conveniences for a local PostgreSQL installation only. Override them when your local role, password, host, port, or database names differ:

```sh
export DATABASE_HOST=localhost
export DATABASE_PORT=5432
export DATABASE_USERNAME=postgres
export DATABASE_PASSWORD=postgres
```

Do not commit local or production credentials. ShelfSense does not currently provide an `.env` loader or an `.env.example`; configure variables through your shell, development environment, or secret manager.

The configured PostgreSQL role must be able to connect and, for automatic setup, create the development and test databases.

## Initial setup

From the repository root:

```sh
bin/setup --skip-server
```

This command:

1. Installs missing gems with Bundler.
2. prepares the development database;
3. clears old logs and temporary files.

To prepare the application and immediately start the server, run `bin/setup` without `--skip-server`.

## Run the application

```sh
bin/dev
```

Open <http://localhost:3000>. Verify application health at <http://localhost:3000/up>.

Stop the server with Ctrl+C.

## Rails console and database tasks

```sh
bin/rails console
bin/rails db:prepare
bin/rails db:migrate
bin/rails db:rollback
```

Use `bin/rails db:reset` only when it is safe to discard and rebuild your local development data. The setup script also supports `bin/setup --reset`.

Create schema changes through Rails migrations. Do not edit `db/schema.rb` directly.

## Tests and validation

Run the Rails test suite:

```sh
bin/rails test
```

Run the other checks used by CI:

```sh
bin/rubocop
bin/brakeman --no-pager
bin/bundler-audit
```

GitHub Actions supplies a PostgreSQL `DATABASE_URL` and prepares the test database before running tests. See [Testing and CI](testing.md) for the active workflow and intentionally deferred checks.

## Production database configuration

Production must supply its database connection values through the deployment environment:

- `DATABASE_NAME`
- `DATABASE_USERNAME`
- `DATABASE_PASSWORD`
- `DATABASE_HOST`
- optionally `DATABASE_PORT` and `RAILS_MAX_THREADS`

Do not use the local defaults in production. Missing production values should fail deployment or connection rather than silently selecting a development database.

## Troubleshooting

### Rails cannot connect to host `localhost`

Confirm PostgreSQL is running and listening on the configured port. If Rails runs inside a container or remote environment, `localhost` refers to that environment; set `DATABASE_HOST` to the reachable PostgreSQL hostname.

### PostgreSQL authentication fails

Confirm `DATABASE_USERNAME`, `DATABASE_PASSWORD`, and the server's authentication rules agree. Test the same connection with `psql`.

### Rails cannot create the database

Create `shelfsense_development` and `shelfsense_test` manually, or grant the configured local role permission to create databases.

### Native gem installation fails

Install the PostgreSQL client development package for your operating system before installing the `pg` gem. Install libvips before using image-processing features.

### CI and local behavior differ

Use Ruby 3.4.9, run `bin/rails db:prepare`, and verify that the same database-related environment variables are present. CI details are recorded in [Testing and CI](testing.md).
