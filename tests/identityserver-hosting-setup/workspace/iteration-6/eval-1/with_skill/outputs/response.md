# Minimal IdentityServer with in-memory stores

**Config.cs**
```csharp
using Duende.IdentityServer.Models;

public static class Config
{
    public static IEnumerable<ApiScope> ApiScopes => new[] { new ApiScope("api1") };

    public static IEnumerable<Client> Clients => new[]
    {
        new Client
        {
            ClientId = "m2m.client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedScopes = { "api1" }
        }
    };
}
```

**Program.cs**
```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();   // includes UseAuthentication() internally
app.UseAuthorization();    // required after IdentityServer

app.MapGet("/", () => "Hello World!");

app.Run();
```

## Pipeline order
1. `UseStaticFiles()`
2. `UseRouting()` – must come **before** IdentityServer
3. `UseIdentityServer()` – already calls `UseAuthentication()`, so don't add it separately
4. `UseAuthorization()` – don't omit it
5. Endpoints (`MapGet`, etc.)

`AddIdentityServer` also registers authentication itself. Secrets are hashed with `.Sha256()`. Request tokens at `/connect/token` (`grant_type=client_credentials`, `scope=api1`). In-memory stores suit dev/static config; use EF stores for production. Configure a license key via configuration (`options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"]`) and keep it out of source control.
