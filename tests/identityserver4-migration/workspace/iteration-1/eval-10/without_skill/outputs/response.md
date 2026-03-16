# Migration Checklist: IdentityServer4 v4.x to Duende IdentityServer v7

Here's a step-by-step checklist for your migration:

## 1. Update Target Framework

- [ ] Update from `netcoreapp3.1` to `net8.0` or later
- [ ] Update all related Microsoft packages to match the new framework version

## 2. Replace NuGet Packages

- [ ] Replace `IdentityServer4` with `Duende.IdentityServer`
- [ ] Replace `IdentityServer4.EntityFramework` with `Duende.IdentityServer.EntityFramework`
- [ ] Replace `IdentityServer4.AspNetIdentity` with `Duende.IdentityServer.AspNetIdentity`
- [ ] Update `Microsoft.EntityFrameworkCore.*` packages to the matching version

## 3. Update Namespaces

- [ ] Search and replace all `using IdentityServer4` with `using Duende.IdentityServer` across your codebase
- [ ] Update any fully-qualified type references

## 4. Update Code Patterns

- [ ] Convert `Startup.cs`/`Program.cs` to minimal hosting pattern if desired
- [ ] Remove `AddDeveloperSigningCredential()` and configure proper signing keys
- [ ] Update any breaking API calls

## 5. Database Migrations

- [ ] Create new EF Core migrations for `ConfigurationDbContext` and `PersistedGrantDbContext`
- [ ] Review the generated migrations for data safety
- [ ] Apply migrations to your database
- [ ] Back up your database before applying

## 6. ASP.NET Identity Integration

- [ ] Verify your ASP.NET Identity configuration works with the updated packages
- [ ] Test user registration, login, and password management

## 7. Reverse Proxy Configuration

- [ ] Ensure forwarded headers are properly configured
- [ ] Verify HTTPS termination settings

## 8. Testing and Verification

- [ ] Test all OAuth/OIDC flows end-to-end
- [ ] Verify token issuance works correctly
- [ ] Check that existing clients can still authenticate
- [ ] Test all external authentication providers
- [ ] Review application logs for any warnings or errors
