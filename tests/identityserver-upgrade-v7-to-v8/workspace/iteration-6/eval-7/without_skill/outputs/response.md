# Upgrade checklist: IdentityServer 7.4 → 8.0

I can't confirm every v8 detail from memory, so use this alongside Duende's official upgrade guide.

## 1. Preparation
- Back up the databases and commit your work.
- Read the v8 release notes and breaking changes.
- Upgrade to the latest 7.4.x first.

## 2. Packages and framework
- `Duende.IdentityServer` and `Duende.IdentityServer.EntityFramework` → 8.0.x.
- Update the target framework if v8 requires a newer .NET, and update `Microsoft.EntityFrameworkCore.*` to match.
- Update any other Duende packages (BFF, AspNetCore.Authentication.JwtBearer) to compatible versions.

## 3. Licensing
- Check whether v8 changes license key requirements or enforcement, and confirm your key is valid.

## 4. Custom stores
- Recompile `IClientStore`, `IResourceStore` and any others. Expect signature changes, such as `CancellationToken` parameters and `IReadOnlyCollection<T>` return types.
- Materialize query results with `.ToList()`.

## 5. `IClock`
- Likely replaced with `TimeProvider`. Replace `CustomClock : IClock` with a `TimeProvider` subclass, register it as a singleton, and update the call sites.

## 6. `ICache<T>`
- Review the cache abstraction. Make caches singletons and use whichever replacement v8 introduces.

## 7. EF Core
- Generate migrations for `ConfigurationDbContext` and `PersistedGrantDbContext`. Review the SQL, then apply it first in staging and then in production.

## 8. Removed or changed APIs
- Fix anything marked obsolete in 7.x. Check `IProfileService` and any other interface you implement.

## 9. Test
- Build with warnings as errors, run integration tests, and check the login, token, refresh, and logout flows.
- Check the discovery document and logs on a staging deployment before production.
