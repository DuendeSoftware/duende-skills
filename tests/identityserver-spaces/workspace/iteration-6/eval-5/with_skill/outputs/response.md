# What Spaces do NOT isolate

Spaces isolate **persisted data only**: each space gets its own Duende Storage pool for configuration and operational data (clients, resources, grants, sessions, issuer). Same process, code and database infrastructure. They do **not** isolate:

- **Signing credentials**
- **ASP.NET Core Data Protection**
- **External caches** (Redis)
- Telemetry, rate limits, custom services, email delivery
- **User databases** not using `IStorageFactory`

## Your plan, item by item

1. **Shared signing keys**: tokens from every space are signed by the same key, reducing cryptographic separation; a token's tenancy is then distinguished only by `iss`/`aud` validation, and a key compromise affects every space. If your trust model requires it, scope signing credentials per space.
2. **Shared Data Protection keys**: cookies and protected payloads are interchangeable across spaces. Consider per-space application discriminators/keys, or accept it knowingly.
3. **Shared Redis cache**: entries can bleed between spaces unless keys include the space ID. Get the space from `ISpaceContextAccessor.GetSpaceId()` and prefix keys (or use separate databases/instances).
4. **One shared user database**: not space-aware, so users are visible to all spaces and nothing stops a user from authenticating in a space they don't belong to. Spaces only partition user data if it goes through the shared `IStorageFactory`; **Duende User Management** does this by default (profiles, authenticators, roles and groups per space). A shared global directory needs a deliberately separate architecture (there's no switch to opt out only for User Management). If you keep your own DB, add tenant IDs and enforce them in login and profile services.

```csharp
public class TenantKeyBuilder(ISpaceContextAccessor spaces)
{
    public string Key(string name) => $"space:{spaces.GetSpaceId()}:{name}";
}
```

**Verdict**: sharing all four gives data separation for config/grants only. Fine for mutually trusting units; for external customers, review and partition each item explicitly.
