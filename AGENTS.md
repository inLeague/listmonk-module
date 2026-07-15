# Listmonk ColdBox module — agent instructions

Typed Hyper HTTP client for [Listmonk](https://listmonk.app). WireBox IDs: `ListmonkClient@listmonk`, optional `ListmonkHyperClient@listmonk`.

## Hyper client registration (boot order)

**Do not** inject `ListmonkHyperClient@listmonk` onto `ListmonkClient` with WireBox `inject=` (even `required=false`). In ColdBox/BoxLang, a missing alias still throws during interceptor/singleton construction when host apps resolve consumers before this module finishes mapping.

| Piece | Convention |
|-------|------------|
| `ModuleConfig.configure()` | `binder.map("ListmonkHyperClient@listmonk")` → `hyper.models.HyperBuilder` with `initWith(baseUrl, timeout, bodyFormat, headers)` using merged `settings` |
| `ListmonkClient.hyperBuilder` | **No** `inject=` — set via `init()` / `setHyper()`, or lazily in `getHyper()` from `moduleSettings` |
| Host apps (optional) | May also map `ListmonkHyperClient@listmonk` early in their WireBox binder; module `map()` on configure keeps settings/token in sync |
| Host consumers (e.g. EmailService) | Prefer **lazy** `wirebox.getInstance("ListmonkClient@listmonk")` when the host constructs those consumers before modules activate |

Use standard `binder.map()` in `configure()` — not `forceMap()` in `onLoad()`. `map()` already overwrites existing mappings and matches the convention used by other inleague modules (vendorIntegration, etc.).

Avoid `afterAspectsLoad()` solely for this Hyper mapping — it is too late for common interceptor boot paths.

## Defaults

- `subscriberMode` default: **`fallback`** (prefer DB subscribers; still send if missing during rollout).
- `defaultTemplateId` / `contentType` applied in `sendTransactional()` when omitted from the payload.

## Settings

Host override via `moduleSettings.listmonk` (`baseUrl`, `apiToken`, `timeout`, `subscriberMode`, `contentType`, `defaultTemplateId`, `listId`).

## Multi-league architecture

Each league (inLeague instance) is gated by `clientID` (uniqueidentifier). Listmonk is shared; isolation is achieved through lists and local template tracking.

### Storage model

| Layer | Owns | Example |
|-------|------|---------|
| `qClient.listmonk_list_id` | League's Listmonk mailing list | `1` |
| Module settings | System-wide defaults | `defaultTemplateId = 5` |
| `listmonk_templates` table | Which templates belong to which league | Region 76 has templates 10, 11, 12 |

### Listmonk templates table

```sql
listmonk_templates (
    id                integer PK,
    clientID          uniqueidentifier FK → clients,
    listmonkTemplateId integer,       -- ID in Listmonk
    name              varchar(255),   -- template name
    createdAt         timestamp,
    updatedAt         timestamp,
    UNIQUE (clientID, listmonkTemplateId)
)
```

### Flow

1. **League boot** — if `qClient.listmonk_list_id` is null, create a Listmonk list and store the ID
2. **Template management** — stub for now; only `defaultTemplateId` is available
3. **Subscriber sync** — `upsertSubscriber()` passes league's `listId` from `qClient.config`
4. **Send email** — use template from `listmonk_templates` or fall back to `defaultTemplateId`

### Template isolation

Templates are NOT isolated in Listmonk (it has no per-list template concept). Instead:
- `listmonk_templates` table tracks which templates belong to which league (via `clientID`)
- API endpoints filter templates by `clientID` before returning to the league
- Leagues see only their own templates in the UI

## Tests

Module harness: `cd test-harness && box testbox run` (see `box.json` scripts). When changing Hyper registration or `getHyper()`, cover lazy construction without a WireBox Hyper alias.
