# Setting Up a Minimal Duende IdentityServer with In-Memory Stores

Here's the updated `Program.cs` with a minimal IdentityServer setup including an API scope `api1` and a machine-to-machine client `m2m.client` using `client_credentials` grant:

```csharp
// Program.cs
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

// Configure IdentityServer services in DI
builder.Services.AddIdentityServer()
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("api1", "My API")
    })
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "m2m.client",
            ClientSecrets = { new Secret("secret".Sha256()) },
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            AllowedScopes = { "api1" }
        }
    });

var app = builder.Build();

// Middleware pipeline - order is critical
app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();    // Includes UseAuthentication() internally
app.UseAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Key Points

1. **`AddIdentityServer()`** registers all IdentityServer services in the DI container. It also calls `AddAuthentication` internally.

2. **`AddInMemoryApiScopes`** registers the `api1` scope that the client can request.

3. **`AddInMemoryClients`** registers the `m2m.client` with:
   - `ClientCredentials` grant type (machine-to-machine)
   - A hashed secret `"secret"`
   - Access to the `api1` scope

4. **Middleware ordering** is critical:
   - `UseStaticFiles()` — before IdentityServer
   - `UseRouting()` — must come before `UseIdentityServer()`
   - `UseIdentityServer()` — includes `UseAuthentication()` internally, so don't add that separately
   - `UseAuthorization()` — must come after `UseIdentityServer()`, required by the Duende UI template

Do **not** add `UseAuthentication()` separately — `UseIdentityServer()` already calls it internally.
