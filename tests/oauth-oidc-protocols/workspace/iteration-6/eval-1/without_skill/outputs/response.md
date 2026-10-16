# Client credentials with IdentityModel and discovery

```csharp
using IdentityModel.Client;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHttpClient();
builder.Services.AddAuthorization();

var app = builder.Build();

app.MapGet("/", () => "Hello World!");

app.MapGet("/catalog", async (IHttpClientFactory factory, IConfiguration config) =>
{
    var authority = config["IdentityServer:Authority"]!;
    var client = factory.CreateClient();

    // Discover endpoints – no hardcoded token URL
    var disco = await client.GetDiscoveryDocumentAsync(authority);
    if (disco.IsError)
        return Results.Problem($"Discovery failed: {disco.Error}");

    var tokenResponse = await client.RequestClientCredentialsTokenAsync(new ClientCredentialsTokenRequest
    {
        Address = disco.TokenEndpoint,
        ClientId = "backend-service",
        ClientSecret = "service-secret",
        Scope = "catalog.read"
    });

    if (tokenResponse.IsError)
        return Results.Problem($"Token request failed: {tokenResponse.Error}");

    client.SetBearerToken(tokenResponse.AccessToken!);
    var api = await client.GetStringAsync("https://api.example.com/catalog");
    return Results.Text(api);
});

app.Run();
```

Notes:
- The authority comes from `appsettings.json` (`https://identity.example.com`); `GetDiscoveryDocumentAsync` loads `/.well-known/openid-configuration` and exposes `TokenEndpoint`.
- Always check `IsError` on both responses.
- Move the secret to user-secrets / environment variables / a vault rather than source code.
- In production, cache the token until it expires (or use `Duende.AccessTokenManagement`) instead of requesting one per call.
