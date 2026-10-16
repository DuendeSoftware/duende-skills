## Target framework

The framework must be upgraded together with the IdentityServer migration. You asked about v7, which requires **.NET 8 (`net8.0`)**, with EF Core 8. The current release, Duende IdentityServer **v8, requires `net10.0`** with EF Core 10. Pick whichever target you're going to; `netcoreapp3.1` is not an option in either case. Follow the Microsoft ASP.NET Core migration guides for each major jump.

| Duende version | .NET | EF Core |
|---|---|---|
| v7.x | net8.0 | 8.0 |
| v8.x | net10.0 | 10.0 |

## Package changes (v7 target)

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Duende.IdentityServer.EntityFramework" Version="7.0.0" />
    <PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="8.0.0">
      <PrivateAssets>all</PrivateAssets>
      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    </PackageReference>
    <PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="8.0.0" />
  </ItemGroup>
</Project>
```

For v8, use `net10.0`, `Duende.IdentityServer.EntityFramework` 8.0.0 and EF Core 10.0.0.

Mapping:
- `IdentityServer4` → `Duende.IdentityServer`
- `IdentityServer4.EntityFramework` → `Duende.IdentityServer.EntityFramework`
- `IdentityServer4.AspNetIdentity` → `Duende.IdentityServer.AspNetIdentity` (if used)
- `IdentityModel` → `Duende.IdentityModel` (if referenced)
- `Microsoft.EntityFrameworkCore.*` 3.1.15 → versions matching the new framework

## Follow-ups

- Replace `IdentityServer4.*` namespaces with `Duende.IdentityServer.*` (and `IdentityModel` with `Duende.IdentityModel`).
- Create and apply EF migrations for `PersistedGrantDbContext` and `ConfigurationDbContext`; the schema gains new tables (`Keys`, `ServerSideSessions`, `PushedAuthorizationRequests`, `IdentityProviders`) and columns.
- Configure `options.LicenseKey` (required for production).
- Remove `AddDeveloperSigningCredential()` and handle signing keys deliberately.
- Set an explicit Data Protection application name and persistent key store, and preserve the issuer URI.
- Consider converting to minimal hosting (`WebApplication.CreateBuilder`).
