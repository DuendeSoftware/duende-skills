# Client Credentials Token Request with IdentityModel

Here's how to implement a client credentials token request using IdentityModel, resolving endpoints from the discovery document:

```csharp
using IdentityModel.Client;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthorization();

var app = builder.Build();

app.MapGet("/call-api", async () =>
{
    using var httpClient = new HttpClient();

    // Step 1: Fetch the discovery document from the authority
    var disco = await httpClient.GetDiscoveryDocumentAsync("https://identity.example.com");

    if (disco.IsError)
    {
        return Results.Problem($"Discovery document error: {disco.Error}");
    }

    // Step 2: Request a client credentials token using the discovered token endpoint
    var tokenResponse = await httpClient.RequestClientCredentialsTokenAsync(
        new ClientCredentialsTokenRequest
        {
            Address = disco.TokenEndpoint,  // Use the discovered endpoint, not hardcoded
            ClientId = "backend-service",
            ClientSecret = "service-secret",
            Scope = "catalog.read"
        });

    if (tokenResponse.IsError)
    {
        return Results.Problem($"Token request error: {tokenResponse.Error}");
    }

    // Step 3: Use the access token to call the API
    using var apiClient = new HttpClient();
    apiClient.SetBearerToken(tokenResponse.AccessToken!);

    var apiResponse = await apiClient.GetStringAsync("https://api.example.com/catalog");
    return Results.Ok(apiResponse);
});

app.MapGet("/", () => "Hello World!");

app.Run();
```

## How It Works

1. **Discovery Document**: `GetDiscoveryDocumentAsync` fetches the OpenID Connect discovery document from `https://identity.example.com/.well-known/openid-configuration`. This JSON document advertises all endpoint URLs (token, authorize, introspection, etc.).

2. **Error Checking**: Always check `disco.IsError` before using the response — the authority may be unreachable or return an invalid document.

3. **Token Request**: `RequestClientCredentialsTokenAsync` sends a `POST` to the token endpoint with `grant_type=client_credentials`, the client credentials, and the requested scope.

4. **Dynamic Endpoint**: `disco.TokenEndpoint` is used as the `Address` rather than hardcoding a URL like `https://identity.example.com/connect/token`. This ensures the application adapts if the URL structure changes.
