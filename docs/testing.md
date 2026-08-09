# Testing and CI

ShelfSense uses GitHub Actions to run the checks that the application currently supports. The active CI workflow performs:

- Rails security analysis with Brakeman
- Ruby dependency auditing with Bundler Audit
- Ruby style checks with RuboCop
- The Rails test suite with PostgreSQL

Two Rails-generated checks have been removed from CI because the application does not yet contain the code or configuration they require. They should be restored when the corresponding features are introduced.

## System tests

### Why the CI job was removed

The generated system-test job ran:

```sh
bin/rails db:test:prepare test:system
```

ShelfSense does not currently have a `test/system/` directory or any browser-based system tests. Rails therefore attempted to load the nonexistent `test/system` path and failed with a `LoadError`. Keeping that job would make CI fail without testing any application behavior.

This removal does not disable the regular Rails test suite. CI continues to run:

```sh
bin/rails db:test:prepare test
```

### When to restore it

Restore a separate system-test job when ShelfSense has user workflows that require browser-level verification and at least one real system test has been added. Before restoring the job:

1. Add `test/application_system_test_case.rb`.
2. Add at least one test under `test/system/`.
3. Select and configure a supported browser driver, such as Selenium with headless Chrome.
4. Confirm the tests pass locally with `./dev/rails-docker bin/rails test:system`.
5. Ensure the CI runner installs any browser or operating-system packages required by the driver.

The restored CI command can then be:

```sh
bin/rails db:test:prepare test:system
```

A separate job is preferable because browser tests usually require additional dependencies and run more slowly than unit, model, request, and integration tests.

## JavaScript dependency audit

### Why the CI job was removed

The generated JavaScript audit job ran:

```sh
bin/importmap audit
```

ShelfSense does not currently have the files produced by installing and configuring Importmap for Rails, including `bin/importmap` and `config/importmap.rb`. It also has no pinned importmap dependencies to audit. The job consequently failed with “No such file or directory” before performing a security check.

Ruby dependency security remains covered by `bin/bundler-audit`.

### When to restore or replace it

Add JavaScript dependency auditing when the application adopts a JavaScript dependency mechanism.

If ShelfSense adopts Importmap:

1. Install and configure `importmap-rails`.
2. Confirm `bin/importmap` and `config/importmap.rb` are committed.
3. Add the application's JavaScript pins.
4. Verify `./dev/rails-docker bin/importmap audit` locally.
5. Restore a CI job that runs `bin/importmap audit`.

If ShelfSense instead adopts npm, Yarn, pnpm, Bun, or another package manager, do not restore the importmap command. Add the audit command appropriate to the chosen package manager and ensure CI installs dependencies from the committed lockfile.

## Maintenance rule

CI should only contain checks that can execute against committed project configuration and that validate something the application actually uses. When adding a framework-generated CI job, first verify its executable, configuration files, dependencies, and at least one meaningful test or audit target are present in the repository.
