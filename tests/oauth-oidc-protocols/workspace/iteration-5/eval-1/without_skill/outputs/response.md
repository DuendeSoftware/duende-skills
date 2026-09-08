# Client Credentials Token Request

You can use the IdentityModel library to request a token using the client credentials grant. To avoid hardcoding the token endpoint, fetch the discovery document first and read the token endpoint from it.

## Example

```csharp
using IdentityModel.Client;

var httpClient = new HttpClient();

// Fetch discovery document from the authority
var disco = await httpClient.GetDiscoveryDocumentAsync("https://identity.example.com");
if (disco.IsError)
{
    Console.WriteLine(disco.Error);
    return;
}

// Request a token using client credentials
var tokenResponse = await httpClient.RequestClientCredentialsTokenAsync(new ClientCredentialsTokenRequest
{
    Address = disco.TokenEndpoint,
    ClientId = "backend-service",
    ClientSecret = "service-secret",
    Scope = "catalog.read"
});

if (tokenResponse.IsError)
{
    Console.WriteLine(tokenResponse.Error);
    return;
}

Console.WriteLine(tokenResponse.AccessToken);
```

## How it works

1. `GetDiscoveryDocumentAsync` retrieves the metadata document from `https://identity.example.com/.well-known/openid-configuration`. This gives you the token endpoint and other endpoints without hardcoding them.
2. We check `disco.IsError` to make sure the discovery document was retrieved successfully.
3. `RequestClientCredentialsTokenAsync` sends a POST to `disco.TokenEndpoint` with `grant_type=client_credentials`, the client ID, secret, and requested scope.
4. If successful, `tokenResponse.AccessToken` contains the bearer token you can attach to API calls with `httpClient.SetBearerToken(token)`.

## Tips

- Reuse the token until it is close to expiry instead of requesting a new one on every call.
- Keep the client secret out of source control (use environment variables or a secrets manager).
- Consider using a singleton/pooled `HttpClient` rather than creating a new one each time to avoid socket exhaustion.
