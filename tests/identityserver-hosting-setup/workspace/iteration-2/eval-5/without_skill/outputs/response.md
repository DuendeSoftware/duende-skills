# Configure IdentityServer Options

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer(options =>
{
    options.IssuerUri = "https://identity.mycompany.com";
    options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];
    options.EmitScopesAsSpaceDelimitedStringInJwt = true;
});

builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/var/dp-keys"));

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

This configures the issuer URI, loads the license from config, and enables space-delimited scopes.
