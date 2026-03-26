# Configuring IdentityServerOptions, License, and Data Protection

## Program.cs

```csharp
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Configure IdentityServer options
builder.Services.AddIdentityServer(options =>
{
    // Set the issuer URI explicitly
    options.IssuerUri = "https://identity.mycompany.com";

    // Load the license key from configuration (not hardcoded)
    options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];

    // Emit scopes as space-delimited string in JWTs
    options.EmitScopesAsSpaceDelimitedStringInJwt = true;
})
.AddInMemoryIdentityResources(Config.IdentityResources)
.AddInMemoryApiScopes(Config.ApiScopes)
.AddInMemoryClients(Config.Clients);

// Configure Data Protection for multi-instance deployment
builder.Services.AddDataProtection()
    .PersistKeysToDbContext<DataProtectionDbContext>()
    .SetApplicationName("IdentityServer");

// Register the Data Protection DbContext
builder.Services.AddDbContext<DataProtectionDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();

// Data Protection DbContext for key storage
public class DataProtectionDbContext : DbContext, IDataProtectionKeyContext
{
    public DataProtectionDbContext(DbContextOptions<DataProtectionDbContext> options)
        : base(options) { }

    public DbSet<DataProtectionKey> DataProtectionKeys { get; set; } = null!;
}
```

## Configuration Details

### IssuerUri

`options.IssuerUri = "https://identity.mycompany.com"` sets the issuer identifier that appears in:
- The `issuer` field in the discovery document
- The `iss` claim in issued tokens

**Note**: In most cases, it's recommended to leave IssuerUri unset and let IdentityServer infer it from the incoming request URL. Set it explicitly only when IdentityServer is accessed on a different address than the expected issuer (e.g., internal Kubernetes address vs public URL).

### License Key

Loading via `builder.Configuration["IdentityServer:LicenseKey"]` keeps the key out of source code. Store it in:
- Environment variables
- Azure Key Vault / AWS Secrets Manager
- User secrets (development)

Never hardcode the license key in source-controlled files.

### EmitScopesAsSpaceDelimitedStringInJwt

When `true`, scopes in JWT access tokens are emitted as a single space-delimited string (e.g., `"scope": "api1 api2"`) instead of the default JSON array format.

### Data Protection

For multi-instance deployment:
- **`PersistKeysToDbContext<DataProtectionDbContext>()`** stores keys in a SQL database accessible by all instances
- **`SetApplicationName("IdentityServer")`** ensures all instances use the same key ring, preventing key isolation when instances have different filesystem paths
