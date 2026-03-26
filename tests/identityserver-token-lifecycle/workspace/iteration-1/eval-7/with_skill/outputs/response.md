# Creating an Internal Token Endpoint with IIdentityServerTools

`IIdentityServerTools` lets you issue tokens from within your IdentityServer host without going through the protocol endpoints. This is useful when your extensibility code or internal services need to call other APIs.

## Updated Program.cs

```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthorization();

var idsvrBuilder = builder.Services.AddIdentityServer()
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
        // ... other clients ...
    })
    .AddInMemoryApiScopes(new List<ApiScope>
    {
        new ApiScope("api1", "API 1")
    })
    .AddInMemoryApiResources(new List<ApiResource>
    {
        new ApiResource("api1_resource") { Scopes = { "api1" } }
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
        lifetime: 600,  // 10 minutes
        audiences: new[] { "backend.api" });

    return Results.Ok(new { access_token = token });
}).RequireAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.Run();
```

## How IIdentityServerTools.IssueClientJwtAsync Works

This method creates a JWT access token as if a client credentials request was made:

- **`clientId`**: The `client_id` claim in the token — identifies the logical caller
- **`lifetime`**: Token validity in seconds (600 = 10 minutes)
- **`audiences`**: The `aud` claim(s) — which APIs this token is intended for

The resulting JWT is signed with IdentityServer's current signing key and can be validated by any API that trusts this IdentityServer instance.

### Security Note

The endpoint has `.RequireAuthorization()` to ensure only authenticated callers can mint internal tokens. Without this, anyone could request tokens by hitting this endpoint.

### When to Use This

- Internal service-to-service calls from within the IdentityServer host
- Background jobs that need to call protected APIs
- Custom endpoints that need to delegate API calls
- Extensibility code (grant validators, profile services) that need downstream API access

For external services, use the standard token endpoint with client credentials flow instead.
