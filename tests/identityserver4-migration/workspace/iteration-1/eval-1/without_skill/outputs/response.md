# Upgrading IdentityServer4 to Duende IdentityServer

## Package Changes

Replace your IdentityServer4 packages with the Duende equivalents:

```xml
<!-- Remove -->
<PackageReference Include="IdentityServer4.EntityFramework" Version="4.1.2" />

<!-- Add -->
<PackageReference Include="Duende.IdentityServer.EntityFramework" Version="7.0.0" />
```

## Target Framework

Update from `netcoreapp3.1` to a modern .NET version:

```xml
<TargetFramework>net8.0</TargetFramework>
```

## EF Core Packages

Update your EF Core packages to match the target framework:

```xml
<PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="8.0.0" />
<PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="8.0.0" />
```

## Other Changes

- Update all `using IdentityServer4.*` namespaces to `using Duende.IdentityServer.*`
- The API surface is largely the same, so most of your configuration code will work with just namespace changes
