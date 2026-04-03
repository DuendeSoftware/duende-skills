# Client Credentials Token Request

Here's how to get a token using client credentials with the IdentityModel library:

```csharp
using IdentityModel.Client;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddAuthorization();
var app = builder.Build();

app.MapGet("/call-api", async () =>
{
    using var httpClient = new HttpClient();

    // Get the discovery document
    var disco = await httpClient.GetDiscoveryDocumentAsync("https://identity.example.com");
    
    if (disco.IsError)
    {
        return Results.Problem($"Discovery error: {disco.Error}");
    }

    // Request a token
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

    // Call the API with the token
    using var apiClient = new HttpClient();
    apiClient.SetBearerToken(tokenResponse.AccessToken!);
    var result = await apiClient.GetStringAsync("https://api.example.com/catalog");
    
    return Results.Ok(result);
});

app.MapGet("/", () => "Hello World!");
app.Run();
```

## Steps

1. Use `GetDiscoveryDocumentAsync` to find the token endpoint from the OpenID Connect discovery document
2. Call `RequestClientCredentialsTokenAsync` with your client credentials and desired scope
3. Check for errors and use the access token to call your API
