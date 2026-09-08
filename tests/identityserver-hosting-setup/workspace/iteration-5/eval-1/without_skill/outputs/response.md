# Minimal Duende IdentityServer with In-Memory Stores

Below is a minimal working setup with an in-memory API scope and a client-credentials (machine-to-machine) client.

## Config.cs

```csharp
using Duende.IdentityServer.Models;

public static class Config
{
    public static IEnumerable<ApiScope> ApiScopes =>
        new[]
        {
            new ApiScope("api1", "My API")
        };

    public static IEnumerable<Client> Clients =>
        new[]
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

## Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();

app.Run();
```

## Notes on the pipeline

- `UseRouting()` comes before `UseIdentityServer()`.
- `UseIdentityServer()` adds the OpenID Connect / OAuth endpoints (like `/connect/token` and the discovery document at `/.well-known/openid-configuration`). It internally registers the authentication middleware, so you generally don't need a separate `UseAuthentication()` call.
- `UseAuthorization()` follows.

## Testing

Request a token:

```
POST /connect/token
grant_type=client_credentials
client_id=m2m.client
client_secret=secret
scope=api1
```

The secret is stored as a SHA-256 hash (`"secret".Sha256()`), so the client sends the raw `secret` value and IdentityServer hashes and compares it.
