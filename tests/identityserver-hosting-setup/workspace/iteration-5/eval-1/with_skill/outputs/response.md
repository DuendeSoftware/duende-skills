# Minimal Duende IdentityServer with In-Memory Stores

Here is a complete minimal setup. IdentityServer requires two steps: registering services in DI (`AddIdentityServer`) and adding the middleware to the pipeline (`UseIdentityServer`). Pipeline ordering is critical.

## Config.cs

Define the API scope and the machine-to-machine client:

```csharp
using Duende.IdentityServer.Models;

public static class Config
{
    public static IEnumerable<ApiScope> ApiScopes =>
        new List<ApiScope>
        {
            new ApiScope("api1", "My API")
        };

    public static IEnumerable<Client> Clients =>
        new List<Client>
        {
            new Client
            {
                ClientId = "m2m.client",
                ClientName = "Machine to Machine Client",

                AllowedGrantTypes = GrantTypes.ClientCredentials,

                ClientSecrets =
                {
                    new Secret("secret".Sha256())
                },

                AllowedScopes = { "api1" }
            }
        };
}
```

## Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

// Step 1: Register IdentityServer services in DI.
// AddIdentityServer also calls AddAuthentication internally.
builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryClients(Config.Clients);

var app = builder.Build();

// Step 2: Configure the request pipeline. Ordering is critical.
app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();   // includes UseAuthentication() internally
app.UseAuthorization();

app.MapDefaultControllerRoute();

app.Run();
```

## Pipeline ordering rules

| Order | Middleware              | Notes                                     |
| ----- | ----------------------- | ----------------------------------------- |
| 1     | `UseStaticFiles()`      | Before IdentityServer                     |
| 2     | `UseRouting()`          | Before IdentityServer                     |
| 3     | `UseIdentityServer()`   | Includes `UseAuthentication()` internally |
| 4     | `UseAuthorization()`    | Required after IdentityServer             |

Notes:

- **`ClientCredentials`** grant is the correct choice for a machine-to-machine (m2m) client with no interactive user.
- The secret is hashed with `.Sha256()` — IdentityServer stores/compares the hash, the raw value `secret` is what the client sends.
- `UseRouting()` must come **before** `UseIdentityServer()`, and `UseAuthorization()` must come **after** it (and must not be omitted — the Duende UI template requires it).
- Do **not** add a separate `UseAuthentication()` call — `UseIdentityServer()` already includes it.

You can verify the setup by requesting the discovery document at `/.well-known/openid-configuration` and requesting a token from the `/connect/token` endpoint using `client_id=m2m.client`, `client_secret=secret`, `grant_type=client_credentials`, `scope=api1`.
