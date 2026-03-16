# Setting Up a Minimal Duende IdentityServer

Here's how to set up a minimal IdentityServer with in-memory configuration:

```csharp
// Program.cs
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

// Add IdentityServer services
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

// Configure middleware pipeline
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();
app.UseIdentityServer();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Explanation

- `AddIdentityServer()` registers IdentityServer services.
- `AddInMemoryApiScopes` defines the API scope `api1`.
- `AddInMemoryClients` defines the M2M client with client credentials grant.
- The middleware pipeline sets up routing, authentication, authorization, and IdentityServer endpoints.

The client uses the `client_credentials` grant type, which is appropriate for machine-to-machine communication where there is no interactive user.
