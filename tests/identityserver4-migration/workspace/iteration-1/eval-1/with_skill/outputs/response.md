# Migrating NuGet Packages from IdentityServer4 to Duende IdentityServer v7

## Step 1: Update Target Framework

```xml
<!-- Old -->
<TargetFramework>netcoreapp3.1</TargetFramework>

<!-- New (pick a current LTS version) -->
<TargetFramework>net8.0</TargetFramework>
<!-- or -->
<TargetFramework>net10.0</TargetFramework>
```

## Step 2: Replace NuGet Packages

```xml
<!-- Old (IdentityServer4) -->
<PackageReference Include="IdentityServer4.EntityFramework" Version="4.1.2" />
<PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="3.1.15" />
<PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="3.1.15" />

<!-- New (Duende) -->
<PackageReference Include="Duende.IdentityServer.EntityFramework" Version="7.4.7" />
<PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="8.0.0" />
<PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="8.0.0" />
```

If you use `IdentityModel` anywhere in your project, replace it with `Duende.IdentityModel`:

```xml
<!-- Old -->
<PackageReference Include="IdentityModel" Version="5.2.0" />

<!-- New -->
<PackageReference Include="Duende.IdentityModel" Version="8.0.0" />
```

## Updated .csproj

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
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

## Important: License Key

Duende IdentityServer requires a license key for production use. Without one, it runs in community/trial mode and logs a warning on startup. Configure the license key via `options.LicenseKey` in `AddIdentityServer`:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
});
```

Store the license key in a secret manager or environment variable — never in source-controlled `appsettings.json`.
