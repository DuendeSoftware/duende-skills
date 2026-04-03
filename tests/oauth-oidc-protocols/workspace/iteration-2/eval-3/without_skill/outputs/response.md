# Validating Reference Tokens via Introspection

## What are Reference Tokens?

Reference tokens are opaque strings that don't contain any claims themselves. Unlike JWTs which are self-contained, a reference token is just an identifier that must be validated by calling back to the token server.

## How to Validate with Introspection

```csharp
using IdentityModel.Client;

var httpClient = new HttpClient();

// Get the discovery document
var disco = await httpClient.GetDiscoveryDocumentAsync("https://identity.example.com");

if (disco.IsError)
{
    Console.WriteLine($"Discovery error: {disco.Error}");
    return;
}

// Call the introspection endpoint
var response = await httpClient.IntrospectTokenAsync(new TokenIntrospectionRequest
{
    Address = disco.IntrospectionEndpoint,
    ClientId = "catalog-api",
    ClientSecret = "api-secret",
    Token = referenceToken
});

if (response.IsError)
{
    Console.WriteLine($"Error: {response.Error}");
    return;
}

// Check if the token is valid
if (response.IsActive)
{
    Console.WriteLine("Token is valid!");
    // Read claims from the response
    foreach (var claim in response.Claims)
    {
        Console.WriteLine($"{claim.Type}: {claim.Value}");
    }
}
else
{
    Console.WriteLine("Token is not active (expired or invalid)");
}
```

## Key Points

- Reference tokens are opaque identifiers, not self-contained JWTs, so they need server-side validation
- The introspection endpoint validates the token and returns its claims
- The API authenticates to the introspection endpoint using its own credentials
- Check the `IsActive` property to determine if the token is valid
- One benefit of reference tokens is that they can be revoked immediately, since each API call checks back with the server
