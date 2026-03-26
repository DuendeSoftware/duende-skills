# Client Credentials Token Request Using Discovery

Here's how to fetch a token using the discovery document with IdentityModel:

```csharp
using IdentityModel.Client;

var httpClient = new HttpClient();

// Step 1: Fetch the discovery document to resolve endpoints
var disco = await httpClient.GetDiscoveryDocumentAsync("https://identity.example.com");

if (disco.IsError)
{
    Console.WriteLine($"Discovery error: {disco.Error}");
    return;
}

// Step 2: Request a client credentials token using the discovered token endpoint
var tokenResponse = await httpClient.RequestClientCredentialsTokenAsync(
    new ClientCredentialsTokenRequest
    {
        Address = disco.TokenEndpoint,  // Use discovered endpoint, not hardcoded URL
        ClientId = "backend-service",
        ClientSecret = "service-secret",
        Scope = "catalog.read"
    });

if (tokenResponse.IsError)
{
    Console.WriteLine($"Token error: {tokenResponse.Error}");
    return;
}

// Step 3: Use the access token to call the API
var accessToken = tokenResponse.AccessToken;
Console.WriteLine($"Access token: {accessToken}");

// Set the token on an HttpClient to call the API
var apiClient = new HttpClient();
apiClient.SetBearerToken(accessToken);
var response = await apiClient.GetAsync("https://api.example.com/catalog");
```

## How It Works

1. **`GetDiscoveryDocumentAsync`** fetches the OpenID Connect discovery document from `https://identity.example.com/.well-known/openid-configuration`. This JSON document advertises all endpoint URLs, supported grant types, and signing key information.

2. **Error checking** (`disco.IsError`) is essential — the authority might be unreachable, return invalid JSON, or have an untrusted HTTPS certificate.

3. **`RequestClientCredentialsTokenAsync`** sends a `POST` to the token endpoint with `grant_type=client_credentials`, the client credentials, and the requested scope.

4. **`disco.TokenEndpoint`** is used as the `Address` instead of hardcoding `https://identity.example.com/connect/token`. This is a best practice — if the IdentityServer URL or path changes, or if it's behind a reverse proxy, the discovery document will always provide the correct endpoint.

## Key Points

- **Never hardcode the token endpoint URL.** Always resolve it from the discovery document.
- **Always check `IsError`** on both the discovery response and the token response.
- The client credentials flow produces an access token with no user identity — it contains only client claims and the requested scope.
