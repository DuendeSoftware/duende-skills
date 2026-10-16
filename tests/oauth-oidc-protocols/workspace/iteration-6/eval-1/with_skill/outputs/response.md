# Client credentials via discovery (IdentityModel)

Endpoints are resolved from `/.well-known/openid-configuration`; the token URL is never hardcoded.

```csharp
using IdentityModel.Client;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddHttpClient();
builder.Services.AddAuthorization();
var app = builder.Build();

app.MapGet("/", () => "Hello World!");

app.MapGet("/catalog", async (IHttpClientFactory factory, IConfiguration config) =>
{
    var authority = config["IdentityServer:Authority"]!; // https://identity.example.com
    var http = factory.CreateClient();

    // 1. Discovery
    var disco = await http.GetDiscoveryDocumentAsync(authority);
    if (disco.IsError) return Results.Problem($"Discovery failed: {disco.Error}");

    // 2. client_credentials grant against disco.TokenEndpoint
    var token = await http.RequestClientCredentialsTokenAsync(new ClientCredentialsTokenRequest
    {
        Address = disco.TokenEndpoint,
        ClientId = "backend-service",
        ClientSecret = "service-secret",
        Scope = "catalog.read"
    });
    if (token.IsError)
        return Results.Problem($"{token.Error}: {token.ErrorDescription}");

    // 3. Call the API
    http.SetBearerToken(token.AccessToken!);
    return Results.Text(await http.GetStringAsync("https://api.example.com/catalog"));
});

app.Run();
```

Points:
- Client credentials is machine-to-machine: no user, so the token only carries client claims (`client_id`, `scope`).
- Check `IsError` on both discovery and token responses.
- Treat the access token as opaque. Just forward it; only the API validates it.
- The secret should come from user-secrets/env/vault. On the server it must be registered hashed: `new Secret("service-secret".Sha256())`, with `AllowedGrantTypes = GrantTypes.ClientCredentials` and `AllowedScopes = { "catalog.read" }`.
- Cache the token until expiry; for production use `Duende.AccessTokenManagement` (`AddClientCredentialsTokenManagement`) which handles caching and renewal automatically.
