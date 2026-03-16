# Configuring IdentityServerOptions, License Key, and Data Protection

Here's the updated `Program.cs` with all requested configurations:

```csharp
using Microsoft.AspNetCore.DataProtection;

var builder = WebApplication.CreateBuilder(args);

// Configure IdentityServer with options
builder.Services.AddIdentityServer(options =>
{
    // Set the issuer URI explicitly
    options.IssuerUri = "https://identity.mycompany.com";

    // Load the license key from configuration (never hardcode)
    options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];

    // Emit scopes as a space-delimited string in JWTs (per RFC 9068)
    options.EmitScopesAsSpaceDelimitedStringInJwt = true;
})
.AddInMemoryApiScopes(Config.ApiScopes)
.AddInMemoryClients(Config.Clients);

// Configure Data Protection for multi-instance deployment
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<DataProtectionKeyContext>()
    .SetApplicationName("IdentityServer");

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapDefaultControllerRoute();

app.Run();
```

## Configuration Explained

### IssuerUri
Setting `options.IssuerUri = "https://identity.mycompany.com"` forces all tokens and the discovery document to use this exact value. By default, IdentityServer infers the issuer from the incoming request URL, but you may need to set it explicitly for your use case.

### License Key from Configuration
The license key is loaded from `builder.Configuration["IdentityServer:LicenseKey"]` rather than being hardcoded. Store the actual key in a secret manager, environment variable, or key vault — never in source-controlled `appsettings.json`.

### EmitScopesAsSpaceDelimitedStringInJwt
When set to `true`, the `scope` claim in JWTs is emitted as a single space-delimited string (e.g., `"api1 profile"`) instead of a JSON array. This follows RFC 9068 for JWT access tokens.

### Data Protection
For multi-instance deployments, data protection keys must be shared across all instances:
- **`PersistKeysToDbContext`** stores keys in a database (Entity Framework)
- **`SetApplicationName("IdentityServer")`** prevents key isolation across instances — without this, each deployment name creates its own isolated key ring
