# SAML behind a load balancer / multiple nodes

Things to configure:

1. **Shared data protection keys** (ASP.NET Core): persist to a shared location (DB, Redis, blob) with `PersistKeysTo...` and a common application name, so cookies/state work across nodes.
2. **Shared signing keys**: all nodes must use the same signing certificate (or shared key store) so SPs see consistent signatures/metadata.
3. **Shared state store**: SAML request state (e.g. AuthnRequest ID / RelayState, logout state, replay cache) must not be in-memory per node. Use a persistent/distributed store (EF operational store or distributed cache).
4. **Forwarded headers**: `UseForwardedHeaders` with `X-Forwarded-Proto/Host`, and set `IssuerUri`/public origin consistently so URLs in metadata and `Destination` checks match the external URL.
5. **Shared SP configuration store** (database, not in-memory) with consistent caching.
6. **Sticky sessions** shouldn't be needed if all of the above is shared. Make sure cookie settings (SameSite=None; Secure) are suitable for POST bindings.
