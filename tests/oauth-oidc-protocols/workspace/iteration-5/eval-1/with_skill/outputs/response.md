# Client Credentials Token Request with IdentityModel

For machine-to-machine calls you want the **client credentials** grant. The key rule: never hardcode the token endpoint — resolve it from the discovery document (`/.well-known/openid-configuration`) so your code adapts to URL changes and load-balancer configuration.

Here's the full flow using IdentityModel.

## Program.cs

```csharp
using IdentityModel.Client;

var builder = WebApplication.CreateBuilder(args);

var app = builder.Build();

app.MapGet("/call-catalog", async (IHttpClientFactory httpClientFactory) =>
{
    var authority = builder.Configuration["IdentityServer:Authority"]
                    ?? "https://identity.example.com";

    using var client = httpClientFactory.CreateClient();

    // 1. Fetch the discovery document from the authority — do NOT hardcode endpoints
    var disco = await client.GetDiscoveryDocumentAsync(authority);
    if (disco.IsError)
    {
        // Discovery unreachable or invalid — fail fast
        throw new Exception($"Discovery error: {disco.Error}");
    }

    // 2. Request a token via the discovered token endpoint
    var tokenResponse = await client.RequestClientCredentialsTokenAsync(
        new ClientCredentialsTokenRequest
        {
            Address = disco.TokenEndpoint,      // discovered, not hardcoded
            ClientId = "backend-service",
            ClientSecret = "service-secret",
            Scope = "catalog.read"
        });

    if (tokenResponse.IsError)
    {
        throw new Exception($"Token error: {tokenResponse.Error}");
    }

    // 3. Use the access token to call the API
    using var apiClient = httpClientFactory.CreateClient();
    apiClient.SetBearerToken(tokenResponse.AccessToken!);

    var response = await apiClient.GetAsync("https://api.example.com/catalog");
    return await response.Content.ReadAsStringAsync();
});

app.Run();
```

Register the `HttpClient` factory in your services:

```csharp
builder.Services.AddHttpClient();
```

## What each step does

1. **`GetDiscoveryDocumentAsync(authority)`** — pulls `/.well-known/openid-configuration` from `https://identity.example.com` and gives you a strongly-typed `disco` object with all endpoint URLs.
2. **`disco.IsError` check** — the discovery response can fail if the authority is unreachable, returns invalid JSON, or fails HTTPS/issuer validation. Always check before using the endpoints.
3. **`RequestClientCredentialsTokenAsync`** — posts `grant_type=client_credentials` with your `ClientId`, `ClientSecret`, and `Scope` to `disco.TokenEndpoint`.

## Why client credentials here

Client credentials is the correct grant for background services and server-to-server calls — there is **no user identity** involved, so the resulting access token contains only client claims (`client_id`, `scope`), not user claims. The `backend-service` client authenticates purely with its own secret.

## Production notes

- Store `service-secret` in configuration/secrets management, not source.
- Don't fetch a fresh token on every request. Cache it and reuse until near expiry, or use `Duende.AccessTokenManagement`'s `AddClientCredentialsTokenManagement()` for automatic caching and refresh (see the `token-management` skill).
- The `catalog.read` scope must be registered as an allowed scope on the `backend-service` client in IdentityServer.
