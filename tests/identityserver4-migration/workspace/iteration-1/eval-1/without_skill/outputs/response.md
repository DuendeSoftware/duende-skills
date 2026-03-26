# Upgrading from IdentityServer4 to Duende IdentityServer

## Package Changes

You'll need to replace your IdentityServer4 NuGet packages with the Duende equivalents:

| Old Package | New Package |
|-------------|-------------|
| `IdentityServer4` | `Duende.IdentityServer` |
| `IdentityServer4.EntityFramework` | `Duende.IdentityServer.EntityFramework` |

## Target Framework

Since `netcoreapp3.1` is no longer supported, you should upgrade to at least `net6.0` or preferably `net8.0`:

```xml
<TargetFramework>net8.0</TargetFramework>
```

## Updated .csproj

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

## Additional Steps

After updating packages, you'll also need to:
- Update namespaces from `IdentityServer4` to `Duende.IdentityServer`
- Review and update your configuration code
- Run database migrations for the new schema
