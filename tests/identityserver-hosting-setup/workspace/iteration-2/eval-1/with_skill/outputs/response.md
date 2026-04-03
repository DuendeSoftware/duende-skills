# Minimal Duende IdentityServer with In-Memory Stores

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new[]
    {
        new ApiScope("api1", "My API")
    })
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

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.MapDefaultControllerRoute();

app.Run();
```

## Key Points

- `builder.Services.AddIdentityServer()` registers all IdentityServer services in DI. It also calls `AddAuthentication` internally.
- `AddInMemoryApiScopes` registers the `api1` scope.
- `AddInMemoryClients` registers the `m2m.client` client with `GrantTypes.ClientCredentials` grant type and the secret `"secret"`.
- **Middleware pipeline ordering is critical:**
  1. `UseStaticFiles()` — before IdentityServer
  2. `UseRouting()` — before IdentityServer
  3. `UseIdentityServer()` — includes `UseAuthentication()` internally
  4. `UseAuthorization()` — required after IdentityServer, must not be omitted (required by the Duende UI template)
