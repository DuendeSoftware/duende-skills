# Validating Reference Tokens

Reference tokens are opaque strings that need to be validated by calling the introspection endpoint.

```csharp
using IdentityModel.Client;

var httpClient = new HttpClient();

// Get discovery document
var disco = await httpClient.GetDiscoveryDocumentAsync("https://identity.example.com");
if (disco.IsError) throw new Exception(disco.Error);

// Introspect the token
var response = await httpClient.IntrospectTokenAsync(
    new TokenIntrospectionRequest
    {
        Address = disco.IntrospectionEndpoint,
        ClientId = "catalog-api",
        ClientSecret = "api-secret",
        Token = referenceToken
    });

if (response.IsError)
    throw new Exception(response.Error);

if (!response.IsActive)
{
    // Token is invalid or expired
    Console.WriteLine("Token is not active");
    return;
}

// Token is valid
var claims = response.Claims;
```

Reference tokens are validated server-side via introspection. Unlike JWTs which are self-contained, reference tokens require a call to the token server. The advantage is that they can be revoked immediately.
