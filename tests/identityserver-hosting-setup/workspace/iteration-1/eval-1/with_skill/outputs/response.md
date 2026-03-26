# Setting Up Minimal Duende IdentityServer with In-Memory Stores

Here's a complete `Program.cs` with a machine-to-machine client using `client_credentials` grant:

```csharp
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

// Register IdentityServer services in DI
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

// Middleware pipeline — order is critical
app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();    // Includes UseAuthentication() internally
app.UseAuthorization();     // Required — must not be omitted

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Pipeline Ordering

The middleware pipeline ordering is critical for IdentityServer to function correctly:

| Order | Middleware | Notes |
|-------|-----------|-------|
| 1 | `UseStaticFiles()` | Before IdentityServer |
| 2 | `UseRouting()` | **Must** be before IdentityServer |
| 3 | `UseIdentityServer()` | Includes `UseAuthentication()` internally — do not add both |
| 4 | `UseAuthorization()` | **Required** after IdentityServer — must not be omitted |

### Key Points

- **`app.UseRouting()`** must come before `app.UseIdentityServer()`. Without routing, IdentityServer's endpoints won't be matched.
- **`app.UseIdentityServer()`** already calls `UseAuthentication()` internally, so you should **not** add a separate `UseAuthentication()` call.
- **`app.UseAuthorization()`** must come after `UseIdentityServer()` and must **not** be omitted — it is required by the Duende UI template.

## What This Configures

- **API Scope**: `api1` — defines the scope that the client can request
- **Client**: `m2m.client` using `client_credentials` grant type with shared secret `"secret"` (hashed with SHA-256)
- The client can request access tokens for the `api1` scope by authenticating with its client ID and secret
