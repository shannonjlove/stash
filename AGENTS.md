# AGENTS.md

## Cursor Cloud specific instructions

Stash is a single product: a Go backend (module `github.com/stashapp/stash`) that
serves a React/Vite UI (`ui/v2.5`). Standard commands live in
[`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) and the root `Makefile`; prefer those
rather than duplicating them. Notes below are the non-obvious, durable gotchas for
this environment.

### Services

- Backend server — `make server-start`. Runs `go run ./cmd/stash` from the
  gitignored `.local/` dir with `STASH_CONFIG_FILE=config.yml`; listens on
  `http://localhost:9999` (GraphQL at `/graphql`, playground at `/playground`).
- UI dev server — `make ui-start`. Vite dev server on `http://localhost:3000`
  with hot reload. It talks **directly** to the backend at `http://localhost:9999`
  (no proxy), so the backend must be running too. Point it elsewhere with
  `VITE_APP_PLATFORM_URL`.

### Lint / test / build

- Backend lint: `make lint` (golangci-lint). UI lint+typecheck+format:
  `make validate-ui`.
- Tests: `make test` (unit) or `make it` (adds the `integration` build tag; heavier).
  There is no separate UI test suite — `make validate-ui` is the UI check.
- Build the app binary with `make build` / a full release with `make` (see
  DEVELOPMENT.md). Building is not required just to run the dev servers above.

### Non-obvious gotchas

- `golangci-lint` must be **v2** (config `.golangci.yml` is `version: "2"`, CI pins
  v2.11.4). The startup update script installs that version to `/usr/local/bin`; a
  v1 binary will fail against this config.
- Generated code is **gitignored** and must exist before the project builds/lints/
  tests: `internal/api/generated_*.go` and `ui/v2.5/src/core/generated-graphql.ts`.
  They are produced by `make generate` (run by the startup update script). After
  changing GraphQL schema/`.graphql` files, re-run `make generate`.
- Backend code changes require a **server restart** (`Ctrl-C` then `make server-start`);
  there is no Go hot reload. UI changes hot-reload in the browser.
- Dev state (config, SQLite db, generated media, blobs) lives under `.local/`
  (gitignored). `make server-clean` wipes it to re-trigger the first-run Setup Wizard.
- Cross-origin caveat: because the UI dev server (`:3000`) and backend (`:9999`) are
  different origins, session auth cookies won't be sent from the dev UI. Keep auth
  disabled during development, or use the backend-served UI on `:9999` (run
  `make ui` first) when testing authenticated flows.
- First-run: the Setup Wizard's folder-browser "Add Directory" control can be
  finicky. You can instead set library paths via `Settings > Library`, or via the
  GraphQL `configureGeneral` mutation (`stashes: [{ path: "..." }]`).
