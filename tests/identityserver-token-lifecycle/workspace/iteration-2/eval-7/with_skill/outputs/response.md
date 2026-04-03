# Internal Token Endpoint Using IIdentityServerTools

Here's how to create an authorized endpoint that issues internal JWT tokens for calling a backend service.

## Updated Program.cs

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication();
builder.Services.AddAuthorization();

builder.Services.AddIdentityServer()
    .AddInMemoryClients(new List<Client>
    {
        new Client
        {
            ClientId = "web_app",
            ClientName = "Web Application",
            AllowedGrantTypes = GrantTypes.Code,
            ClientSecrets = { new Secret("secret".Sha256()) },
            RedirectUris = { "https://localhost:5002/signin-oidc" },
            PostLogoutRedirectUris = { "https://localhost:5002/signout-callback-oidc" },
            AllowedScopes = { "openid", "profile", "api1" },
            AccessTokenLifetime = 3600
        },
        new Client
        {
            ClientId = "m2m_client",
            ClientName = "Machine to Machine Client",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("m2m_secret".Sha256()) },
            AllowedScopes = { "api1" }
        },
        new Client
        {
            ClientId = "mobile_app",
            ClientName = "Mobile Application",
            AllowedGrantTypes = GrantTypes.Code,
            RequireClientSecret = false,
            RedirectUris = { "myapp://callback" },
            PostLogoutRedirectUris = { "myapp://signout" },
            AllowedScopes = { "openid", "profile", "api1" },
            RequirePkce = true
        }
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("api1", "API 1")
    })
    .AddInMemoryApiResources(new List<ApiResource>
    {
        new ApiResource("api1_resource")
        {
            Scopes = { "api1" }
        }
    })
    .AddInMemoryIdentityResources(new List<IdentityResource>
    {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile()
    })
    .AddTestUsers(new List<Duende.IdentityServer.Test.TestUser>
    {
        new Duende.IdentityServer.Test.TestUser
        {
            SubjectId = "1",
            Username = "alice",
            Password = "password"
        }
    });

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

// Internal token endpoint
app.MapGet("/internal-token", async (IIdentityServerTools tools) =>
{
    var token = await tools.IssueClientJwtAsync(
        clientId: "internal_service",
        lifetime: 600,
        audiences: new[] { "backend.api" });

    return Results.Ok(new { token });
}).RequireAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## Key Points

1. **`/internal-token` endpoint** — A minimal API endpoint mapped to the `/internal-token` path using `app.MapGet`.

2. **`IIdentityServerTools` injection** — The `IIdentityServerTools` interface is injected directly into the endpoint handler. This is IdentityServer's built-in utility for issuing tokens from extensibility code without going through the protocol endpoints.

3. **`IssueClientJwtAsync`** — Issues a client-level JWT with:
   - `clientId: "internal_service"` — The client ID embedded in the token
   - `lifetime: 600` — Token lifetime of 10 minutes (600 seconds)
   - `audiences: new[] { "backend.api" }` — The target audience for the token

4. **`.RequireAuthorization()`** — Ensures only authenticated/authorized callers can invoke the endpoint. This prevents unauthorized token generation.
