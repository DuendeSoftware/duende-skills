# Client Credentials Token Request with IdentityModel

Here's how to fetch a token using IdentityModel by first resolving endpoints from the discovery document, then making the client credentials request:

```csharp
using IdentityModel.Client;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthorization();

var app = builder.Build();

app.MapGet("/call-api", async () =>
{
    // Step 1: Fetch the discovery document from the authority
    using var httpClient = new HttpClient();
    var disco = await httpClient.GetDiscoveryDocumentAsync("https://identity.example.com");

    if (disco.IsError)
    {
        // Handle unreachable or invalid discovery document
        return Results.Problem($"Discovery document error: {disco.Error}");
    }

    // Step 2: Use the discovered token endpoint to request a client credentials token
    var tokenResponse = await httpClient.RequestClientCredentialsTokenAsync(
        new ClientCredentialsTokenRequest
        {
            Address = disco.TokenEndpoint, // resolved from discovery, not hardcoded
            ClientId = "backend-service",
            ClientSecret = "service-secret",
            Scope = "catalog.read"
        });

    if (tokenResponse.IsError)
    {
        return Results.Problem($"Token request error: {tokenResponse.Error}");
    }

    // Step 3: Use the access token to call the API
    var apiClient = new HttpClient();
    apiClient.SetBearerToken(tokenResponse.AccessToken!);

    var response = await apiClient.GetAsync("https://api.example.com/catalog/items");
    var content = await response.Content.ReadAsStringAsync();

    return Results.Ok(content);
});

app.Run();
```

## Key Points

1. **Discovery Document** — Always resolve endpoints from `/.well-known/openid-configuration` via `GetDiscoveryDocumentAsync()` rather than hardcoding the token endpoint URL. This ensures your application adapts to URL changes and load balancer configurations.

2. **Error Handling** — Always check `disco.IsError` before using the discovery response. The document may be unreachable or return invalid JSON.

3. **Client Credentials Flow** — `RequestClientCredentialsTokenAsync` sends a `grant_type=client_credentials` POST to the token endpoint with the specified `ClientId`, `ClientSecret`, and `Scope`.

4. **Token Endpoint from Discovery** — The `Address` property is set to `disco.TokenEndpoint`, which is the URL resolved from the discovery document — never a hardcoded value.
