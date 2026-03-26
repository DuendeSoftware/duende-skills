# Minimal IdentityServer Setup

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

app.UseIdentityServer();
app.UseAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

This sets up IdentityServer with one API scope and one M2M client.
