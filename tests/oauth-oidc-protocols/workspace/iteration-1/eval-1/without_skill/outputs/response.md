# Client Credentials Token Request

Here's how to fetch a token using IdentityModel:

```csharp
using IdentityModel.Client;

var httpClient = new HttpClient();

// Fetch discovery document
var disco = await httpClient.GetDiscoveryDocumentAsync("https://identity.example.com");
if (disco.IsError)
{
    throw new Exception(disco.Error);
}

// Request token
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
    throw new Exception(tokenResponse.Error);
}

Console.WriteLine(tokenResponse.AccessToken);
```

This uses the discovery document to find the token endpoint, then makes a client credentials request with your client ID, secret, and desired scope.
