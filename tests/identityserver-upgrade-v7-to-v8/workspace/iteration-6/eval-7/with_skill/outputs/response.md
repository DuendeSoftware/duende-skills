# Upgrade checklist: IdentityServer v7.4 → v8.0

Tailored to your project (custom `IClientStore`, `IClock`, `ICache<Client>`, EF operational store).

## 1. Framework and packages
- [ ] `net8.0` → **`net10.0`**.
- [ ] Update all `Duende.*` packages to the latest stable 8.x (`Duende.IdentityServer`, `Duende.IdentityServer.EntityFramework`). Check NuGet and don't hard-code a version. Update `Microsoft.EntityFrameworkCore.SqlServer` to match .NET 10.

## 2. EF migrations (required even without SAML)
```bash
dotnet ef migrations add Update_DuendeIdentityServer_v8_0 -c ConfigurationDbContext -o Migrations/ConfigurationDb
dotnet ef database update -c ConfigurationDbContext
dotnet ef migrations add Update_DuendeIdentityServer_v8_0_Saml -c PersistedGrantDbContext -o Migrations/PersistedGrantDb
dotnet ef database update -c PersistedGrantDbContext
```
Config store gains 7 SAML tables. Operational store gains 3.

## 3. `IClock` → `TimeProvider`
```csharp
public class CustomClock : TimeProvider
{
    public override DateTimeOffset GetUtcNow() => DateTimeOffset.UtcNow;
}
builder.Services.AddSingleton<TimeProvider, CustomClock>(); // or TimeProvider.System
```
`GetUtcNow()` replaces the `UtcNow` property.

## 4. `ICache<T>` → keyed `HybridCache`
Inject `[FromKeyedServices("ConfigurationStoreCache")] HybridCache` and use `GetOrCreateAsync`. Remove `CustomClientCache`. `CachingOptions.CacheLockTimeout` is obsolete.

## 5. Custom stores
- [ ] Add `CancellationToken ct` as the last parameter on **all** async store and service methods (`IClientStore`, `IResourceStore`, `IPersistedGrantStore`, `IDeviceFlowStore`, `ICorsPolicyService`, `IProfileService`). `ICancellationTokenProvider` is removed.
- [ ] `IClientStore`: add `IAsyncEnumerable<Client> GetAllClientsAsync(CancellationToken ct)`.
- [ ] Nine interfaces change `IEnumerable<T>` → `IReadOnlyCollection<T>`. Materialize with `ToListAsync(ct)`.
- [ ] `IUserSession`: add `AddSamlSessionAsync`, `GetSamlSessionListAsync`, `RemoveSamlSessionAsync` (no-ops are fine).
- [ ] `PersistedGrantFilter.ClientIds`/`Types` are non-nullable. Use `.Count > 0`.
- [ ] EF `IdentityProviderStore` gets a new `IIdentityProviderFactory` constructor parameter.

## 6. Other API changes
- [ ] `IRefreshTokenService`: use `RefreshTokenCreationRequest` / `RefreshTokenUpdateRequest` plus `ct`.
- [ ] Remove `IAuthorizationParametersMessageStore` and use PAR.
- [ ] `DPoPProofValidatonContext/Result` → `DPoPProofValidationContext/Result`.
- [ ] `AuthorizationError` → `InteractionError`. `DenyAuthorizationAsync` → `DenyAuthenticationAsync`.
- [ ] `IProfileService`: `context.Client` → `context.Application?.Identifier` (`IConnectedApplication?`). Handle SAML callers.
- [ ] `ITokenValidator.ValidateAccessTokenAsync(token, expectedScope: null, ct)`.
- [ ] `options.Preview.*` is removed. Use `options.Discovery.EnableDiscoveryDocumentCache`, `options.Discovery.DiscoveryDocumentCacheDuration`, and `options.StrictClientAssertionAudienceValidation` (default is now `false`).

## 7. Licensing
- [ ] `IdentityServerLicense.Current` → `LicenseInformation.Current` (`Duende.IdentityServer.Licensing`). `LicenseEdition` → `EntitledSkus`.
- [ ] A v7-format key still works on v8 core. SAML and User Management in production need a v8-format key. A v8 key fails on v7/BFF with `IDX10503`.
- [ ] Server-Side Sessions, Automatic Key Management and SAML **throw at startup** when a license is present but lacks the entitlement. DPoP, Resource Isolation, CIBA, Dynamic Identity Providers and User Management only log warnings. Run lower environments with the production key.

## 8. Behavior notes
- POST endpoint redirects use HTTP 303.
- Device flow consent: `RememberConsent` is always `false`.
- Secret validation failures log at Debug instead of Error, so update your alerting.
- The license key is read from `Duende:IdentityServer:LicenseKey` or `Duende:LicenseKey`.
- NRT is enabled, so fix nullable warnings.

## 9. Verify
Build, run integration tests, and check the login, token, refresh and logout flows.
