# Migration Checklist: IdentityServer4 to Duende IdentityServer

## Step 1: Update Target Framework
Update from `netcoreapp3.1` to `net8.0` or later:
```xml
<TargetFramework>net8.0</TargetFramework>
```

## Step 2: Replace NuGet Packages
- `IdentityServer4` → `Duende.IdentityServer`
- `IdentityServer4.EntityFramework` → `Duende.IdentityServer.EntityFramework`
- `IdentityServer4.AspNetIdentity` → `Duende.IdentityServer.AspNetIdentity`
- Update EF Core packages to 8.0

## Step 3: Update Namespaces
Replace all `IdentityServer4` namespaces with `Duende.IdentityServer`.

## Step 4: Update Hosting Model
Convert `Startup.cs` to minimal hosting with `WebApplication.CreateBuilder`.

## Step 5: Configure License Key
Add your Duende license key via configuration:
```csharp
options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
```

## Step 6: Database Migrations
Create and apply EF Core migrations for both ConfigurationDbContext and PersistedGrantDbContext.

## Step 7: Update UI
Update your login/logout/consent pages for Duende.

## Step 8: Test
- Verify discovery document
- Test token issuance
- Test all client flows
