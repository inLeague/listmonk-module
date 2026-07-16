# Listmonk Subscriber Sync — Remaining Risks

## Implemented

- **ListmonkSubscriberService**: syncSubscriber, syncIsActive, getActiveSubscriberIds
- **Email verification hooks**: verifyByToken/createVerified → syncSubscriber
- **isActive hooks**: processOptOut, AwsService.handleEmailReturn → syncIsActive
- **ID-scoped send**: EmailService resolves subscriber IDs scoped to qClient.clientID
- **Webhook endpoint**: POST /api/public/listmonk/webhook with HMAC-SHA256 validation

## Remaining Risks

### 1. Multi-tenant Listmonk vs per-league lists

**Current state**: Each league has its own Listmonk list (`clients.listmonk_list_id`). Subscribers are scoped to their league's list.

**Risk**: Listmonk is a single instance shared by all leagues. If a subscriber exists in multiple leagues (e.g., a coach in Region 76 and Region 100), they'll have separate Listmonk subscriber records per league. This is correct behavior — each league manages their own subscribers independently.

**Mitigation**: Already handled by design. Each league's list is isolated. No cross-league subscriber sharing.

### 2. Subscriber ID drift

**Risk**: If a subscriber is deleted from Listmonk (manually or via API), the `emailSubscriberID_*` on the user becomes stale. Subsequent sends will fail with "subscriber not found" errors.

**Mitigation**: The `subscriber_mode: "fallback"` setting handles this — Listmonk falls back to sending via email if the subscriber ID isn't found. The stale ID will be overwritten on next verification.

**Future**: Add a periodic cleanup job that validates subscriber IDs against Listmonk.

### 3. Email address changes without re-verification

**Risk**: If a user changes their email address (email, email2, email3) without going through the verification flow, the old subscriber ID remains on the user record. The new address won't have a subscriber ID until verified.

**Mitigation**: The `emailSubscriberID_*` fields are only populated after verification. Address changes that bypass verification won't have subscriber IDs, so sends will use `subscriber_emails` fallback.

**Future**: Clear subscriber IDs when email addresses change (before verification).

### 4. Webhook re-entrancy

**Risk**: The webhook endpoint updates `isActive` in the DB, which could trigger `processOptOut`, which calls `syncIsActive`, which could trigger another webhook.

**Mitigation**: The re-entrancy guard in `syncIsActive` (`_syncingUserIDs` struct) prevents this loop. The guard is per-request only — subsequent requests will process normally.

**Future**: Use a more robust idempotency key (e.g., webhook event ID) instead of in-memory guard.

### 5. Listmonk downtime during user operations

**Risk**: If Listmonk is down when a user verifies their email or opts out, the sync will fail silently.

**Mitigation**: All sync methods soft-fail — errors are logged but never thrown. User operations complete successfully regardless of Listmonk status.

**Future**: Add a retry queue for failed syncs.

### 6. Template management stub

**Current state**: Only `defaultTemplateId` is available. Leagues cannot manage their own templates yet.

**Risk**: All leagues use the same template. Leagues that want custom templates cannot do so.

**Mitigation**: The `listmonk_templates` table is in place for future template management. For now, all leagues use the default template.

### 7. Webhook secret rotation

**Risk**: If the webhook secret is rotated in Listmonk, the old secret must be updated in `moduleSettings.listmonk.webhookSecret` before the next webhook delivery. Otherwise, all webhooks will fail signature validation.

**Mitigation**: The webhook endpoint returns 401 for invalid signatures, so Listmonk will retry. Update the secret promptly.

### 8. No rate limiting on webhook endpoint

**Risk**: The public webhook endpoint has no rate limiting, making it vulnerable to abuse.

**Mitigation**: The HMAC signature validation prevents unauthorized access. Rate limiting can be added later if needed.

## Testing

Run tests on `http://testinleague.localtest.me/`:
```
box testbox run --directory=tests/specs/integration/system/ListmonkSubscriberServiceSpec.cfc
```

After singleton changes, run `fwreinit` to clear WireBox cache.
