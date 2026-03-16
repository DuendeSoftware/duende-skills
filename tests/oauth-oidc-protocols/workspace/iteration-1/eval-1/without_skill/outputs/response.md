# Client Credentials Token Request with IdentityModel

Here's how to fetch a token using IdentityModel with the discovery document:

```csharp
using IdentityModel.Client;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthorization();

var app = builder.Build();

app.MapGet("/call-api", async () =>
{
    using var httpClient = new HttpClient();

    // Fetch the discovery document
    var disco = await httpClient.GetDiscoveryDocumentAsync("https://identity.example.com");

    if (disco.IsError)
    {
        return Results.Problem($"Error fetching discovery document: {disco.Error}");
    }

    // Request a client credentials token
    var tokenResponse = await httpClient.RequestClientCredentialsTokenAsync(
        new ClientCredentialsTokenRequest
        {
            Address = disco.TokenEndpoint,
            ClientId = "backend-service",
            ClientSecret = "service-secret",
            Scope = "catalog.read"
        });

    if (tokenResponse.IsError)
    {
        return Results.Problem($"Token error: {tokenResponse.Error}");
    }

    // Use the token
    var apiClient = new HttpClient();
    apiClient.SetBearerToken(tokenResponse.AccessToken!);

    var response = await apiClient.GetAsync("https://api.example.com/catalog/items");
    var content = await response.Content.ReadAsStringAsync();

    return Results.Ok(content);
});

app.Run();
```

This code uses the IdentityModel library to:
1. Fetch the OpenID Connect discovery document
2. Use the discovered token endpoint to request a client credentials token
3. Attach the token to API calls
