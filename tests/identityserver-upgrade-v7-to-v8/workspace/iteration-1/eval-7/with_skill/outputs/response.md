# Complete IdentityServer v7.4 → v8.0 Upgrade Checklist

Here's a comprehensive, ordered checklist for your upgrade:

## Phase 1: Project Setup

### 1. Update Target Framework to .NET 10
```xml
<TargetFramework>net10.0</TargetFramework>
```

### 2. Update All Duende NuGet Packages
```xml
<PackageReference Include="Duende.IdentityServer" Version="8.0.0" />
<PackageReference Include="Duende.IdentityServer.EntityFramework" Version="8.0.0" />
```

### 3. Run EF Database Migration
```bash
dotnet ef migrations add Update_DuendeIdentityServer_v8_0 -c ConfigurationDbContext
dotnet ef database update
```
Required even without SAML — adds 5 SAML-related tables.

## Phase 2: Replace Deprecated APIs

### 4. Replace IClock with TimeProvider
```csharp
// Remove: IClock _clock; ... _clock.UtcNow
// Replace: TimeProvider _timeProvider; ... _timeProvider.GetUtcNow()
```

### 5. Replace ICache<T> with Keyed HybridCache
```csharp
// Inject: [FromKeyedServices("ConfigurationStoreCache")] HybridCache cache
// Use: _cache.GetOrCreateAsync(key, factory, options, cancellationToken: ct)
```
Note: `CachingOptions.CacheLockTimeout` is obsolete.

### 6. Remove IAuthorizationParametersMessageStore
Replace with PAR (Pushed Authorization Requests). Configure `RequirePushedAuthorization = true` on clients.

## Phase 3: Interface Changes

### 7. Add CancellationToken to All Async Store/Service Methods
```csharp
// All async methods in IClientStore, IResourceStore, IPersistedGrantStore,
// IDeviceFlowStore, ICorsPolicyService, IProfileService, etc.
Task<Client?> FindClientByIdAsync(string clientId, CancellationToken ct)
```
Remove `ICancellationTokenProvider` references — it's gone.

### 8. Add GetAllClientsAsync to Custom IClientStore
```csharp
public Task<IReadOnlyCollection<Client>> GetAllClientsAsync(CancellationToken ct)
```

### 9. Fix Return Types: IEnumerable<T> → IReadOnlyCollection<T>
Use `.ToList()` or `.ToArray()` on results to satisfy the interface.

### 10. Update IRefreshTokenService
```csharp
// Old: CreateRefreshTokenAsync(subject, accessToken, client)
// New: CreateRefreshTokenAsync(RefreshTokenCreationRequest request, CancellationToken ct)
// New: UpdateRefreshTokenAsync(RefreshTokenUpdateRequest request, CancellationToken ct)
```

## Phase 4: Fix Misc Breaking Changes

### 11. Fix DPoP Type Name Typos
```csharp
// DPoPProofValidatonContext → DPoPProofValidationContext
// DPoPProofValidatonResult → DPoPProofValidationResult
```

### 12. Update Licensing Code
```csharp
// IdentityServerLicense.Current → LicenseInformation.Current
// summary.LicenseEdition → summary.EntitledSkus
```

### 13. Update EF IdentityProviderStore Constructor
Add `IIdentityProviderFactory` parameter if you have a custom implementation.

### 14. Fix Nullable Reference Type Warnings
All v8 assemblies have NRT enabled. Address nullable warnings.

## Phase 5: Verify

### 15. Build and Test
```bash
dotnet build
dotnet test
```

### 16. Verify Runtime Behavior
- Check redirect status codes (now 303 for POST endpoints)
- Review log levels for secret validation failures
- Test custom stores with the new CancellationToken propagation
