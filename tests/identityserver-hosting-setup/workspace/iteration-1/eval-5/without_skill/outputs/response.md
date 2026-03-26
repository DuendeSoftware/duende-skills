# IdentityServer Configuration

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://identity.mycompany.com";
    options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
    options.EmitScopesAsSpaceDelimitedStringInJwt = true;
});

builder.Services.AddDataProtection()
    .PersistKeysToDbContext<MyKeysContext>();

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

This configures the issuer URI, loads the license from configuration, sets space-delimited scopes, and persists Data Protection keys to a database.
