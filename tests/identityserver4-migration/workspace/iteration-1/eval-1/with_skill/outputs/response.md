# Migrating IdentityServer4 v4.1.2 to Duende IdentityServer v7: NuGet Packages and Target Framework

## Target Framework Update

Your project currently targets `netcoreapp3.1`, which is end-of-life. Duende IdentityServer v7 requires at least **`net8.0`** (LTS) or **`net10.0`** (LTS). Update your `.csproj`:

```xml
<PropertyGroup>
  <TargetFramework>net8.0</TargetFramework>
</PropertyGroup>
```

## NuGet Package Replacements

Replace the IdentityServer4 packages with their Duende equivalents:

| Old Package | New Package | Version |
|-------------|-------------|---------|
| `IdentityServer4.EntityFramework` (4.1.2) | `Duende.IdentityServer.EntityFramework` | 7.4.7 |
| `IdentityModel` (if used) | `Duende.IdentityModel` | 8.0.0 |

Your updated `.csproj` should look like:

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Duende.IdentityServer.EntityFramework" Version="7.4.7" />
    <PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="8.0.0">
      <PrivateAssets>all</PrivateAssets>
      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    </PackageReference>
    <PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="8.0.0" />
  </ItemGroup>

</Project>
```

## Key Changes Explained

1. **`IdentityServer4.EntityFramework` → `Duende.IdentityServer.EntityFramework`**: This is the main package replacement. The `Duende.IdentityServer.EntityFramework` package transitively includes `Duende.IdentityServer`, so you don't need a separate `IdentityServer4` base package reference.

2. **`Microsoft.EntityFrameworkCore.SqlServer` 3.1.15 → 8.0.0**: EF Core packages must match the target framework version. For `net8.0`, use EF Core 8.0.x packages.

3. **`Microsoft.EntityFrameworkCore.Design` 3.1.15 → 8.0.0**: Same version alignment requirement.

4. **`IdentityModel` → `Duende.IdentityModel`**: If your project uses `IdentityModel` (the protocol client library) anywhere, replace it with `Duende.IdentityModel`. The old `IdentityModel` package is no longer maintained alongside Duende.

## Licensing Note

**Duende IdentityServer requires a license key for production use.** Without a license key, IdentityServer runs in community/trial mode and logs a warning on startup. Configure the license key via `options.LicenseKey` in your `AddIdentityServer()` call, loading it from configuration or a secret manager — never from source-controlled files.

## Next Steps

After updating packages and the target framework:
- Update all `IdentityServer4.*` namespaces to `Duende.IdentityServer.*`
- Remove `AddDeveloperSigningCredential()` and use Duende's automatic key management
- Create and apply EF Core database migrations for the new schema
- Configure the license key
