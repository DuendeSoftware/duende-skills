# IdentityServer v7.4 → v8.0 Upgrade Checklist

Here's a general checklist based on typical major version upgrade patterns for IdentityServer:

## 1. Update Target Framework

Update to the required .NET version (check release notes — likely .NET 9):
```xml
<TargetFramework>net9.0</TargetFramework>
```

## 2. Update NuGet Packages

```xml
<PackageReference Include="Duende.IdentityServer" Version="8.0.0" />
<PackageReference Include="Duende.IdentityServer.EntityFramework" Version="8.0.0" />
```

## 3. Run EF Migrations

Generate and apply any schema changes:
```bash
dotnet ef migrations add UpgradeToV8 -c ConfigurationDbContext
dotnet ef database update
```

## 4. Update Custom Store Implementations

Major version upgrades often change interface signatures. Check for:
- New method parameters (likely CancellationToken additions)
- New interface members
- Changed return types

## 5. Update IClock Usage

If `IClock` has changed, migrate to the new time abstraction (possibly `TimeProvider`).

## 6. Review Deprecated APIs

Check for any APIs marked as obsolete in v7 that may have been removed in v8.

## 7. Build and Fix Compilation Errors

```bash
dotnet build
```

Address each error based on the compiler messages and release notes.

## 8. Test

Run your test suite and verify behavior hasn't changed unexpectedly.

## Resources

- Check the official Duende IdentityServer v8 migration guide
- Review the changelog for breaking changes
- Test thoroughly in a non-production environment first
