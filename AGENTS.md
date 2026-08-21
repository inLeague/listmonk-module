# Listmonk ColdBox module — agent instructions

Typed Hyper HTTP client for [Listmonk](https://listmonk.app). WireBox IDs from `autoMapModels` + `modelNamespace`: `ListmonkClient@listmonk`, `ListmonkResponse@listmonk`.

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
./run-tests.sh          # starts BoxLang if needed; writes tests/results/
box run-script test     # same runner, assumes server already up
```

Listmonk for integration tests (`tests/docker/`): `cp tests/docker/.env.example tests/docker/.env` if you need non-default port or creds, then `docker compose --project-directory tests/docker up -d`. Defaults: `http://localhost:9002`, dashboard user `admin` / `listmonktest`, API user `listmonk-api`. First install writes `tests/docker/creds/api.json.env` (`LISTMONK_URL`, `LISTMONK_API_USER`, `LISTMONK_API_TOKEN`). Recreate with `docker compose --project-directory tests/docker down -v` and remove `tests/docker/creds`.

Browser (HTML reporter, `writeDump()` works): start `box run-script start:boxlang`, open http://127.0.0.1:60299/tests/runner.cfm

When changing `getHyper()`, cover lazy construction from `moduleSettings`.
