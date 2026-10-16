## Package changes

Replace IdentityServer4 packages with Duende equivalents and move to a supported framework.

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

- `IdentityServer4.EntityFramework` → `Duende.IdentityServer.EntityFramework` (it pulls in `Duende.IdentityServer`).
- Duende IdentityServer v7 requires .NET 8 or later (net8.0 is the sensible choice; netcoreapp3.1 is out of support and not supported).
- EF Core packages must move to 8.x to match the framework (3.1.x won't work).
- Also update `IdentityModel` → `Duende.IdentityModel` (v7) if you reference it.
- Namespaces change from `IdentityServer4.*` to `Duende.IdentityServer.*`.
- Afterwards add EF migrations for schema changes, and configure a license key (a license is required for production).
