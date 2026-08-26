# Listmonk ColdBox module — agent instructions

Hyper HTTP client for [Listmonk](https://listmonk.app). WireBox IDs from `autoMapModels` + `modelNamespace`: `ListmonkClient@listmonk`, `ListmonkResponse@listmonk`.

## Hyper client (boot order)

**Do not** inject a HyperBuilder onto `ListmonkClient` with WireBox `inject=` (even `required=false`). In ColdBox/BoxLang, a missing alias still throws during interceptor/singleton construction when host apps resolve consumers before this module finishes mapping.

| Piece | Convention |
|-------|------------|
| `ModuleConfig` | `autoMapModels` + `modelNamespace = "listmonk"`; no extra Hyper WireBox alias |
| `ListmonkClient.hyperBuilder` | **No** `inject=` — set via `init()` / `setHyper()`, or lazily in `getHyper()` from `moduleSettings` |
| Host consumers (e.g. EmailService) | Prefer **lazy** `wirebox.getInstance("ListmonkClient@listmonk")` when the host constructs those consumers before modules activate |

## Defaults

- `subscriberMode` default: **`fallback`** (prefer DB subscribers; still send if missing during rollout).
- `defaultTemplateId` / `contentType` applied in `sendTransactional()` when omitted from the payload.

## Settings

Host override via `moduleSettings.listmonk` (`baseUrl`, `apiToken`, `timeout`, `subscriberMode`, `contentType`, `defaultTemplateId`).

## Tests

Top-level TestBox specs live in `tests/specs/` (not `test-harness`). The test app is a normal ColdBox app: `tests/modules/listmonk` is a symlink to this checkout, so WireBox aliases from `ModuleConfig` (`ListmonkClient@listmonk`, etc.) load by convention. Specs extending `tests.ColdboxBase` can `getInstance( "ListmonkClient@listmonk" )`.

```bash
./run-tests.sh          # docker compose up Listmonk + BoxLang; writes tests/results/
docker compose --project-directory tests/docker build   # after Dockerfile / start-script changes
box run-script test     # same TestBox runner, assumes server already up
act -j tests            # GitHub Actions workflow on the host (see .actrc)
```

Listmonk (`tests/docker/`) starts from `run-tests.sh` (`up`, not `--build`). Override port/creds with `cp tests/docker/.env.example tests/docker/.env`. Defaults: `http://localhost:9002`, dashboard user `admin` / `listmonktest`, API user `listmonk-api`. First install writes `tests/docker/creds/api.json.env` (`LISTMONK_URL`, `LISTMONK_API_USER`, `LISTMONK_API_TOKEN`). Recreate with `docker compose --project-directory tests/docker down -v` and remove `tests/docker/creds`.

CI (`.github/workflows/tests.yml`) runs on `ubuntu-latest` so the job can use Docker. Do not wrap the job in the CommandBox container image — that blocks `docker compose`. Local `act -j tests` uses `-P ubuntu-latest=-self-hosted` (`.actrc`). The workflow always `docker compose down -v` at the end (GitHub and act).

Browser (HTML reporter, `writeDump()` works): start `box run-script start:boxlang`, open http://127.0.0.1:60299/runner.cfm

When changing `getHyper()`, cover lazy construction from `moduleSettings`.
