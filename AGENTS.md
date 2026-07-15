# Listmonk ColdBox module — agent instructions

Typed Hyper HTTP client for [Listmonk](https://listmonk.app). WireBox IDs: `ListmonkClient@listmonk`, optional `ListmonkHyperClient@listmonk`.

## Hyper client registration (boot order)

**Do not** inject `ListmonkHyperClient@listmonk` onto `ListmonkClient` with WireBox `inject=` (even `required=false`). In ColdBox/BoxLang, a missing alias still throws during interceptor/singleton construction when host apps resolve consumers before this module finishes mapping.

| Piece | Convention |
|-------|------------|
| `ModuleConfig.onLoad()` | `binder.forceMap( "ListmonkHyperClient@listmonk" )` → `hyper.models.HyperBuilder` with `initWith( baseUrl, timeout, bodyFormat, headers )` using merged `settings` |
| `ListmonkClient.hyperBuilder` | **No** `inject=` — set via `init()` / `setHyper()`, or lazily in `getHyper()` from `moduleSettings` |
| Host apps (optional) | May also map `ListmonkHyperClient@listmonk` early in their WireBox binder; module `forceMap` on load keeps settings/token in sync |
| Host consumers (e.g. EmailService) | Prefer **lazy** `wirebox.getInstance( "ListmonkClient@listmonk" )` when the host constructs those consumers before modules activate |

Avoid `afterAspectsLoad()` solely for this Hyper mapping — it is too late for common interceptor boot paths.

## Defaults

- `subscriberMode` default: **`fallback`** (prefer DB subscribers; still send if missing during rollout).
- `defaultTemplateId` / `contentType` applied in `sendTransactional()` when omitted from the payload.

## Settings

Host override via `moduleSettings.listmonk` (`baseUrl`, `apiToken`, `timeout`, `subscriberMode`, `contentType`, `defaultTemplateId`).

## Tests

Module harness: `cd test-harness && box testbox run` (see `box.json` scripts). When changing Hyper registration or `getHyper()`, cover lazy construction without a WireBox Hyper alias.
