# Minimal IdentityServer with in-memory stores

**Program.cs**
```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new[] { new ApiScope("api1") })
    .AddInMemoryClients(new[]
    {
        new Client
        {
            ClientId = "m2m.client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedScopes = { "api1" }
        }
    });

var app = builder.Build();

app.UseRouting();
app.UseIdentityServer();   // includes authentication middleware
app.UseAuthorization();

app.MapGet("/", () => "Hello World!");

app.Run();
```

Notes:
- Order: `UseRouting` → `UseIdentityServer` → `UseAuthorization`. `UseIdentityServer` already adds authentication, so a separate `UseAuthentication` isn't needed.
- Secrets are stored hashed (`.Sha256()`).
- Request a token: `POST /connect/token` with `grant_type=client_credentials&scope=api1` and client id/secret.
- Use a real license key in production via `options.LicenseKey`.
