# Migrating IdentityServer4 v4.1.2 NuGet Packages to Duende IdentityServer v7

Looking at your `IdentityServerMigrationSample.csproj`, here are the changes you need:

## 1. Update the Target Framework

Change from `netcoreapp3.1` to a current LTS version:

```xml
<!-- Old -->
<TargetFramework>netcoreapp3.1</TargetFramework>

<!-- New (pick net8.0 or net10.0) -->
<TargetFramework>net8.0</TargetFramework>
```

## 2. Replace NuGet Packages

Replace `IdentityServer4.EntityFramework` with `Duende.IdentityServer.EntityFramework`:

```xml
<!-- Old -->
<PackageReference Include="IdentityServer4.EntityFramework" Version="4.1.2" />

<!-- New -->
<PackageReference Include="Duende.IdentityServer.EntityFramework" Version="7.4.7" />
```

If you use `IdentityModel` anywhere (e.g. for `JwtClaimTypes`, `OidcConstants`), replace it with `Duende.IdentityModel`:

```xml
<!-- Old -->
<PackageReference Include="IdentityModel" Version="5.2.0" />

<!-- New -->
<PackageReference Include="Duende.IdentityModel" Version="8.0.0" />
```

## 3. Update Entity Framework Core Packages

Update `Microsoft.EntityFrameworkCore.SqlServer` and `Microsoft.EntityFrameworkCore.Design` to a version matching your new target framework:

```xml
<!-- For net8.0 -->
<PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="8.0.0" />
<PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="8.0.0">
  <PrivateAssets>all</PrivateAssets>
  <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
</PackageReference>
```

## 4. Resulting .csproj

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Duende.IdentityServer.EntityFramework" Version="7.4.7" />
    <PackageReference Include="Duende.IdentityModel" Version="8.0.0" />
    <PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="8.0.0">
      <PrivateAssets>all</PrivateAssets>
      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    </PackageReference>
    <PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="8.0.0" />
  </ItemGroup>

</Project>
```

## 5. Licensing Note

**Duende IdentityServer requires a license key for production use.** Without one, it runs in community/trial mode and logs a warning on startup. You'll configure the license key via `IdentityServerOptions.LicenseKey` after updating your code. See [Duende IdentityServer Pricing](https://duendesoftware.com/products/identityserver) for edition details.
