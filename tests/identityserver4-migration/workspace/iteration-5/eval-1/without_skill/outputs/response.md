# Migrating from IdentityServer4 to Duende IdentityServer v7

Duende IdentityServer is the commercial successor to IdentityServer4, and the migration is mostly a matter of swapping packages, bumping the target framework, and renaming namespaces. Here is what applies to your project.

## Target framework

`netcoreapp3.1` reached end of life, and Duende IdentityServer v7 is built for **.NET 8**. Update the target framework:

```xml
<TargetFramework>net8.0</TargetFramework>
```

Since you're crossing multiple major versions, expect to follow the ASP.NET Core migration guidance for each hop (3.1 → 6 → 8).

## NuGet packages

Swap the IdentityServer4 packages for the Duende equivalents — the names line up directly:

```xml
<!-- Remove -->
<PackageReference Include="IdentityServer4.EntityFramework" Version="4.1.2" />

<!-- Add -->
<PackageReference Include="Duende.IdentityServer.EntityFramework" Version="7.0.0" />
```

If elsewhere in the solution you reference the base `IdentityServer4` package, replace it with `Duende.IdentityServer`, and `IdentityServer4.AspNetIdentity` becomes `Duende.IdentityServer.AspNetIdentity`.

## EF Core packages

Bump the Entity Framework Core packages to the 8.0 line so they match .NET 8:

```xml
<PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="8.0.0" />
<PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="8.0.0">
  <PrivateAssets>all</PrivateAssets>
  <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
</PackageReference>
```

## Licensing

One important thing that catches people off guard: unlike IdentityServer4, **Duende IdentityServer is not free for production use**. It requires a license key (there are free thresholds for small companies and open-source projects, but you must register). Without a valid license it will still run but logs licensing warnings. Budget for this before you deploy.

## Updated project file

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Duende.IdentityServer.EntityFramework" Version="7.0.0" />
    <PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="8.0.0" />
    <PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="8.0.0">
      <PrivateAssets>all</PrivateAssets>
      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    </PackageReference>
  </ItemGroup>
</Project>
```

After this you'll still need to update `using IdentityServer4.*` statements to `using Duende.IdentityServer.*` and add EF Core migrations for the new schema, but the package and framework changes are the starting point.
