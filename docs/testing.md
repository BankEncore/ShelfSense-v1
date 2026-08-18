# Testing and CI

ShelfSense uses GitHub Actions to run the checks that the application currently supports. The active CI workflow performs:

- Rails security analysis with Brakeman
- Ruby dependency auditing with Bundler Audit
- JavaScript dependency auditing with `bin/importmap audit`
- Ruby style checks with RuboCop
- The Rails test suite with PostgreSQL
- Register workspace system tests with headless Chrome

## System tests

System tests live under `test/system/` and use Selenium with headless Chrome. Locally they must run inside Docker:

```sh
docker compose build
./dev/rails-docker bin/rails test:system
./dev/rails-docker bin/ci
```

`Dockerfile.dev` installs Chromium and chromedriver and sets `SE_CHROMEDRIVER` so Selenium uses that binary instead of downloading Google Chrome (which is unavailable on Linux ARM64). `./dev/rails-docker` starts a throwaway `web` container for `test:system` and `bin/ci` even when the app server is already up, so those commands see the image packages rather than a stale server container. Rebuild after pulling Dockerfile changes: `docker compose build`. Chrome runs as the `rails` user with `--no-sandbox`. The minimum viewport is `1280×720`.

CI runs system tests as a separate job after installing Chrome:

```sh
bin/rails db:test:prepare test:system
```

## JavaScript dependency audit

Importmap pins live in `config/importmap.rb`. CI runs:

```sh
bin/importmap audit
```

Ruby dependency security remains covered by `bin/bundler-audit`.

## Maintenance rule

CI should only contain checks that can execute against committed project configuration and that validate something the application actually uses. When adding a framework-generated CI job, first verify its executable, configuration files, dependencies, and at least one meaningful test or audit target are present in the repository.
