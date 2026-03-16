# Replacing Developer Signing Credential with Automatic Key Management

## Remove Developer Signing Credential

`AddDeveloperSigningCredential()` generates a persistent key file suitable only for development. Replace it with production automatic key management.

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;
using Microsoft.IdentityModel.Tokens;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc
    .WriteTo.Console()
    .ReadFrom.Configuration(ctx.Configuration));

// Configure Data Protection for load-balanced deployment
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/var/identity/dp-keys"))
    .SetApplicationName("identity-server");

// IdentityServer with automatic key management
builder.Services.AddIdentityServer(options =>
{
    // Key rotation every 90 days
    options.KeyManagement.RotationInterval = TimeSpan.FromDays(90);

    // Announce 14 days before activation so JWKS caches refresh
    options.KeyManagement.PropagationTime = TimeSpan.FromDays(14);

    // Keep retired keys for 14 days to validate recently-issued tokens
    options.KeyManagement.RetentionDuration = TimeSpan.FromDays(14);

    // Delete keys when retention ends
    options.KeyManagement.DeleteRetiredKeys = true;

    // Encrypt keys at rest via ASP.NET Core Data Protection
    options.KeyManagement.DataProtectKeys = true;

    // ES256 first (primary), RS256 as fallback for legacy clients
    options.KeyManagement.SigningAlgorithms = new[]
    {
        new SigningAlgorithmOptions(SecurityAlgorithms.EcdsaSha256),
        new SigningAlgorithmOptions(SecurityAlgorithms.RsaSha256)
        {
            UseX509Certificate = true
        }
    };
})
// NO .AddDeveloperSigningCredential() — automatic key management handles this
.AddInMemoryIdentityResources(new List<IdentityResource>
{
    new IdentityResources.OpenId(),
    new IdentityResources.Profile(),
    new IdentityResources.Email()
})
.AddInMemoryApiScopes(new List<ApiScope>
{
    new ApiScope("catalog.read"),
    new ApiScope("catalog.write"),
    new ApiScope("orders.manage"),
    new ApiScope("internal-api")
})
.AddInMemoryClients(new List<Client>
{
    // ... clients ...
});

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapRazorPages();

app.Run();
```

## Summary

| Setting | Before | After |
|---------|--------|-------|
| Signing | `AddDeveloperSigningCredential()` | Automatic key management |
| Algorithms | RS256 only (implicit) | ES256 primary, RS256 fallback |
| Rotation | None | 90 days |
| Propagation | N/A | 14 days |
| Retention | N/A | 14 days |
| Data Protection | Not configured | `PersistKeysToFileSystem("/var/identity/dp-keys")` + `SetApplicationName` |
| Key encryption | None | `DataProtectKeys = true` |
