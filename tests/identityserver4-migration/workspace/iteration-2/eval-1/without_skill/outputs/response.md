# Upgrading from IdentityServer4 to Duende IdentityServer v7

## NuGet Package Changes

Replace the IdentityServer4 packages with Duende equivalents:

```xml
<!-- Remove -->
<PackageReference Include="IdentityServer4.EntityFramework" Version="4.1.2" />

<!-- Add -->
<PackageReference Include="Duende.IdentityServer.EntityFramework" Version="7.0.0" />
```

## Target Framework

You'll need to update from `netcoreapp3.1` to a newer framework. Duende IdentityServer v7 requires at least .NET 6 or newer:

```xml
<TargetFramework>net8.0</TargetFramework>
```

## EF Core Packages

Update Entity Framework Core packages to match:

```xml
<PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="8.0.0" />
<PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="8.0.0" />
```

## Summary

The main changes are:
1. Replace `IdentityServer4.EntityFramework` with `Duende.IdentityServer.EntityFramework`
2. Update the target framework to `net8.0`
3. Update EF Core packages to version 8.0

After these package changes, you'll need to update namespaces in your code from `IdentityServer4.*` to `Duende.IdentityServer.*`.
