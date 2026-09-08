# Upgrading from IdentityServer4 v4.1.2 to Duende IdentityServer

Your current `.csproj` targets `netcoreapp3.1` and references `IdentityServer4.EntityFramework 4.1.2` with EF Core 3.1. Here is what needs to change.

## 1. Target framework

`netcoreapp3.1` is out of support and Duende IdentityServer requires a modern LTS runtime. Move to a current LTS target framework:

```xml
<!-- Old -->
<TargetFramework>netcoreapp3.1</TargetFramework>

<!-- New -->
<TargetFramework>net8.0</TargetFramework>
```

Duende IdentityServer v7 runs on **.NET 8**. (The latest Duende IdentityServer v8 requires `net10.0`; pick the framework that matches the Duende major version you are targeting.) Because you are jumping several major versions, follow Microsoft's ASP.NET Core migration guides for each major version step.

## 2. NuGet package replacement

Replace the IdentityServer4 packages with their Duende equivalents. The package names map one-to-one:

```xml
<!-- Old (IdentityServer4) -->
<PackageReference Include="IdentityServer4.EntityFramework" Version="4.1.2" />

<!-- New (Duende) -->
<PackageReference Include="Duende.IdentityServer.EntityFramework" Version="7.0.0" />
```

General mapping:

| IdentityServer4 package | Duende package |
|-------------------------|----------------|
| `IdentityServer4` | `Duende.IdentityServer` |
| `IdentityServer4.EntityFramework` | `Duende.IdentityServer.EntityFramework` |
| `IdentityServer4.AspNetIdentity` | `Duende.IdentityServer.AspNetIdentity` |
| `IdentityModel` | `Duende.IdentityModel` |

If any code (or a transitive reference) uses the `IdentityModel` package for OIDC/OAuth constants and client helpers, replace it with **`Duende.IdentityModel`** and update the `using IdentityModel;` statements to `using Duende.IdentityModel;`.

## 3. Update Microsoft.EntityFrameworkCore packages

Your EF Core 3.1 packages must move to a version that matches the new target framework. For `net8.0`:

```xml
<PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="8.0.0" />
<PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="8.0.0">
  <PrivateAssets>all</PrivateAssets>
  <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
</PackageReference>
```

(Use the `10.0.x` line if you target `net10.0` for Duende v8.)

## 4. License key (important for production)

Duende IdentityServer **requires a valid license key for production use**. Without one it runs in community/trial mode and logs a warning on startup — fine for local development, but you must configure a license before going live. Store it in a secret manager / environment variable, not in source-controlled `appsettings.json`, and set it via `options.LicenseKey` in `AddIdentityServer`.

## Resulting `.csproj`

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

After the package/framework changes you will also need to update namespaces (`IdentityServer4.*` → `Duende.IdentityServer.*`) and create EF Core migrations for the new Duende schema, but the packaging and target-framework changes above are the first step.
