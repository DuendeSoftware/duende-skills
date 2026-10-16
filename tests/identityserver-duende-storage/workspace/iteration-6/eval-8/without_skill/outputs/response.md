I can't verify the "Duende Storage" details, so this is a general migration plan from the EF Core stores.

1. **Assess**: read the target's docs for schema, supported databases, and any official migration tool.
2. **Staging rehearsal**: restore a production backup, migrate, and run your full flow tests.
3. **Configuration data (clients, resources, scopes)**: export via `ConfigurationDbContext` or the admin API and import into the new store. Preserve IDs and names.
4. **Secrets**: client secrets are stored hashed (SHA-256/512), so copy the hashes as-is, since they can't be re-derived. Shared secrets for external IdPs or signing keys must be copied with the same Data Protection or encryption keys, or they become unreadable.
5. **Signing keys**: migrate them so issued tokens still validate and JWKS stays continuous.
6. **Active grants/sessions**: refresh tokens, consents and authorization codes in `PersistedGrants` are keyed by hashed values. Either copy the rows (if the format is compatible) or accept that users must re-login and apps must re-authenticate on refresh failure. Reference tokens are invalidated if not copied.
7. **Cutover**: maintenance window or dual-write; short-lived items such as codes can be dropped.
8. **Rollback**: keep the old DB and config untouched until verified.
9. **Cleanup**: remove EF packages and run token cleanup in the new store.
