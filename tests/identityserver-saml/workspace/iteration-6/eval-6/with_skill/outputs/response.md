# SAML across multiple nodes

1. **Shared SAML state stores** — most important. Without them SSO/SLO state is lost when a request lands on a different node.
   - `ISamlSigninStateStore` (sign-in request state, `SigninStateLifetime` default 15 min)
   - `ISamlLogoutSessionStore` (SLO tracking, `LogoutSessionLifetime` default 5 min)
   ```csharp
   builder.Services.AddIdentityServer()
       .AddSaml()
       .AddConfigurationStore(o => o.ConfigureDbContext = b => b.UseSqlServer(cs))
       .AddOperationalStore(o => o.ConfigureDbContext = b => b.UseSqlServer(cs)); // registers both SAML stores
   ```
   (or implement them on Redis). If you customize `ISamlSigninStateSerializer`, remember the default one ignores `Extensions`.
2. **Persistent SP store** — EF Core or custom `ISamlServiceProviderStore` with `AddSamlServiceProviderStoreCache` (HybridCache; use a distributed L2 cache). Not in-memory.
3. **Same signing certificate/keys** on all nodes (X.509 with private key, or shared Automatic Key Management store), so signatures and metadata agree. Metadata is cached 12h, so plan rotation.
4. **ASP.NET Core data protection keys** shared across nodes, and forwarded headers configured so the external host/scheme are used in metadata/endpoints.
5. Consistent `SamlOptions.EntityId` on all nodes.
6. Keep clock skew small but sane (default 5 min) and nodes time-synced.
