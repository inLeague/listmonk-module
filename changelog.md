# Changelog

## Unreleased

### Changed

- Module WireBox / settings namespace is now `listmonk` (`ListmonkClient@listmonk`, `moduleSettings.listmonk`)
- Replaced `writeLog` diagnostics with LogBox (`logbox:logger:{this}`)
- Hyper client mapped as `ListmonkHyperClient@listmonk` via WireBox `initWith` (no mutation of `HyperBuilder@hyper`)
- `sendTransactional()` applies module `subscriberMode` / `contentType` when omitted from the payload
- Removed unimplemented Tier-3 stub methods that only threw `ListmonkNotImplemented`
- Aligned packaging and tooling with Ortus module-template conventions (ignore rules, CFLint, EditorConfig, DocBox build, CI, format scripts)

## 0.1.0

### Features

- Initial release
- Transactional email (`sendTransactional`)
- Subscriber CRUD (`getSubscribers`, `createSubscriber`, `updateSubscriber`, `patchSubscriber`, `getSubscriber`, `deleteSubscriber`)
- List management (`getLists`, `getList`, `createList`, `updateList`, `deleteList`)
- Template management (`getTemplates`, `getTemplate`)
- Subscriber list membership management
- Opt-in sending
- Blocklist management
- Subscriber export
- Health check
- Built on Hyper HTTP client
- BoxLang-only (no Lucee/ACF support)
