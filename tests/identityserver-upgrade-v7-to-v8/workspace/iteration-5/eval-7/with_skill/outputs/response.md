# Complete v7.4 → v8.0 Upgrade Checklist

Work through these in order. Given your setup (custom stores, EF Core, a custom `IClock`), the items most relevant to you are called out, but this is the full list.

## 1. Update the Target Framework (do this first)
v8.0 requires **.NET 10**. Update the TFM before anything else:
```xml
<TargetFramework>net10.0</TargetFramework>
```

## 2. Update all Duende NuGet packages to the latest stable 8.x
Check [NuGet](https://www.nuget.org/packages/Duende.IdentityServer) for the current 8.x version (don't hardcode — at time of writing it's `8.0.1`):
```xml
<PackageReference Include="Duende.IdentityServer" Version="8.0.1" />
<PackageReference Include="Duende.IdentityServer.EntityFramework" Version="8.0.1" />
```

## 3. Run EF Core database migrations
Required **even if you don't use SAML** — v8 adds SAML tables and the schema must match. Migrate both contexts:
```bash
dotnet ef migrations add Update_DuendeIdentityServer_v8_0 \
    -c ConfigurationDbContext -o Migrations/ConfigurationDb
dotnet ef database update -c ConfigurationDbContext

dotnet ef migrations add Update_DuendeIdentityServer_v8_0_Saml \
    -c PersistedGrantDbContext -o Migrations/PersistedGrantDb
dotnet ef database update -c PersistedGrantDbContext
```

## 4. Replace `IClock` with `TimeProvider`
Delete your `CustomClock : IClock` and its `AddSingleton<IClock, ...>()` registration. Inject `TimeProvider` and use `GetUtcNow()` (method) instead of `UtcNow` (property).

## 5. Replace `ICache<T>` with keyed `HybridCache`
Inject `[FromKeyedServices("ConfigurationStoreCache")] HybridCache`, use `GetOrCreateAsync` (not `GetOrAddAsync`) with `HybridCacheEntryOptions`. `CachingOptions.CacheLockTimeout` is now obsolete.

## 6. Add `CancellationToken` to all async store/service methods
Every store/service interface method now takes `CancellationToken ct` as the last parameter (`IClientStore`, `IResourceStore`, `IPersistedGrantStore`, `IProfileService`, etc.). Also remove any `ICancellationTokenProvider` usage — it's gone.

## 7. Add `GetAllClientsAsync` to your custom `IClientStore`
New required member: `IAsyncEnumerable<Client> GetAllClientsAsync(CancellationToken ct)`.

## 8. Fix return-type changes: `IEnumerable<T>` → `IReadOnlyCollection<T>`
Nine interfaces changed. Update signatures and materialize with `.ToList()` / `.ToArray()`.

## 9. Update `IRefreshTokenService` implementations
`CreateRefreshTokenAsync` / `UpdateRefreshTokenAsync` now take request objects (`RefreshTokenCreationRequest` / `RefreshTokenUpdateRequest`) plus a `CancellationToken`.

## 10. Remove `IAuthorizationParametersMessageStore`
Removed in v8 — switch clients to **PAR** (`require_pushed_authorization_requests`).

## 11. Fix DPoP type-name typos
`DPoPProofValidatonContext` → `DPoPProofValidationContext`, `DPoPProofValidatonResult` → `DPoPProofValidationResult`.

## 12. Update licensing code and license key
`IdentityServerLicense.Current` → `LicenseInformation.Current`; single edition → `EntitledSkus` collection. Note the v8 key is a new signed-JWT (with `kid`) format; keep a v7-format key for BFF/older runtimes, and be aware Server-Side Sessions / Automatic Key Management / SAML now **throw at startup** if licensed-but-unentitled.

## 13. Apply the smaller renames/relocations
- `AuthorizationError` → `InteractionError`
- `DenyAuthorizationAsync` → `DenyAuthenticationAsync`
- `ProfileDataRequestContext.Client` → `.Application`
- `ITokenValidator.ValidateAccessTokenAsync` gains an `expectedScope` parameter
- `PreviewFeatureOptions` removed — move settings to `options.Discovery.*` / `options.StrictClientAssertionAudienceValidation` (default now `false`)

## 14. Fix nullable reference type (NRT) warnings
All assemblies now enable NRT — resolve the new nullable warnings.

## 15. Build, run, and test
Confirm a clean build, then smoke-test auth flows end to end.

---

**Most relevant to your project:** #1 (TFM), #3 (EF migration for your operational store), #4 (your `CustomClock`), #6 + #7 (your `CustomClientStore`), and #5 (your `CustomClientCache`).
