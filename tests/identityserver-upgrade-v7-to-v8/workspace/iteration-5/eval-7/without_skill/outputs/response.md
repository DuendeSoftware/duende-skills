# Upgrade checklist: IdentityServer v7.4 → v8.0

I'm giving you a solid general major-version upgrade checklist. I don't have Duende's full v8 breaking-change list memorized, so treat the API-specific items as prompts to verify against the official 8.0 upgrade guide and let the compiler guide you.

## 1. Read the official v8 upgrade/release notes first
Skim Duende's "upgrade to v8.0" doc and changelog so you know the breaking changes before touching code.

## 2. Update the Target Framework
Major IdentityServer versions usually raise the minimum runtime. Check the v8 requirement and bump your TFM to the required (latest) .NET version:
```xml
<TargetFramework>net8.0</TargetFramework>  <!-- set to whatever v8 requires -->
```

## 3. Update all Duende NuGet packages to 8.x
```xml
<PackageReference Include="Duende.IdentityServer" Version="8.0.0" />
<PackageReference Include="Duende.IdentityServer.EntityFramework" Version="8.0.0" />
```
Update every `Duende.*` package together to avoid version mismatches; check NuGet for the latest patch.

## 4. Run EF Core database migrations
If the v8 entity model changed, your database schema must be updated or you'll get runtime "missing table/column" errors:
```bash
dotnet ef migrations add UpgradeToV8 -c PersistedGrantDbContext
dotnet ef database update -c PersistedGrantDbContext
```
Repeat for `ConfigurationDbContext` if you use it.

## 5. Update your custom stores to the new interface contracts
Rebuild and fix every signature mismatch the compiler reports on your custom `IClientStore` / other stores. Major versions commonly tighten return types (e.g. `IEnumerable<T>` → `IReadOnlyCollection<T>`) and may add parameters — match the interface member-for-member.

## 6. Migrate your custom `IClock` implementation
Modern .NET (and libraries tracking it) have moved to `System.TimeProvider`. Replace your custom `IClock` with an injected `TimeProvider`, using `GetUtcNow()` instead of a `UtcNow` property. Confirm this is the abstraction v8 expects.

## 7. Replace any deprecated caching/abstractions
If you use IdentityServer's internal caching or other abstractions that changed, migrate them to the v8 equivalents (for caching, `HybridCache` is the current .NET direction). Verify names in the docs.

## 8. Address other breaking API changes
Search the codebase for any types/methods the changelog lists as renamed or removed, and update call sites accordingly.

## 9. Fix nullable reference type warnings
If v8 tightened nullability, resolve the new compiler warnings.

## 10. Build, run, and test end to end
Do a clean rebuild, run all tests, and manually smoke-test your auth flows (login, token issuance, refresh) before deploying. Upgrade in a branch and test in a non-production environment first.

Because custom stores, EF, and clock abstractions are exactly the areas that change across major versions, lean on the official v8 upgrade guide for the precise API details — I've flagged the spots where I'm inferring rather than certain.
